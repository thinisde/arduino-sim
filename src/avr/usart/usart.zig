const std = @import("std");
const mcu_spec = @import("../../mcu/spec.zig");

fn bit(bit_index: u3) u8 {
    return @as(u8, 1) << bit_index;
}

pub const Usart = struct {
    const RxBufferSize = 2;
    const RxInputBufferSize = 128;
    const TxOutputBufferSize = 128;

    pub const mpcm_bit: u3 = 0;
    pub const u2x_bit: u3 = 1;
    pub const upe_bit: u3 = 2;
    pub const dor_bit: u3 = 3;
    pub const fe_bit: u3 = 4;
    pub const rxb8_bit: u3 = 1;
    pub const txb8_bit: u3 = 0;
    pub const ucsz2_bit: u3 = 2;
    pub const usbs_bit: u3 = 3;
    pub const ucsrc_reset: u8 = 0b0000_0110;

    pub const Parity = enum {
        none,
        even,
        odd,
    };

    const FrameConfig = struct {
        data_bits: u4,
        parity: Parity,
        stop_bits: u2,
        bit_cycles: u64,
        frame_cycles: u64,
    };

    const RxFrame = struct {
        data: u16 = 0,
        frame_error: bool = false,
        data_overrun: bool = false,
        parity_error: bool = false,
    };

    const TxFrame = struct {
        data: u16,
        byte: u8,
        frame_cycles: u64,
    };

    spec: mcu_spec.UsartSpec,
    clock_hz: u64,

    ucsra_shadow: u8 = 0,
    ucsrb_shadow: u8 = 0,
    ucsrc_shadow: u8 = ucsrc_reset,
    ubrrl_shadow: u8 = 0,
    ubrrh_shadow: u8 = 0,

    rx_buf: [RxBufferSize]RxFrame = [_]RxFrame{.{}} ** RxBufferSize,
    rx_head: usize = 0,
    rx_tail: usize = 0,
    rx_len: usize = 0,

    rx_input_buf: [RxInputBufferSize]RxFrame = [_]RxFrame{.{}} ** RxInputBufferSize,
    rx_input_head: usize = 0,
    rx_input_tail: usize = 0,
    rx_input_len: usize = 0,
    rx_shift: ?RxFrame = null,
    rx_shift_complete_cycle: u64 = 0,
    rx_overrun_pending: bool = false,

    tx_udr: ?TxFrame = null,
    tx_shift: ?TxFrame = null,
    tx_shift_complete_cycle: u64 = 0,
    txc_pending: bool = false,

    tx_buf: [TxOutputBufferSize]u8 = [_]u8{0} ** TxOutputBufferSize,
    tx_len: usize = 0,
    tx_head: usize = 0,
    tx_tail: usize = 0,

    pub fn init(spec: mcu_spec.UsartSpec, clock_hz: u64) Usart {
        return .{
            .spec = spec,
            .clock_hz = clock_hz,
            .ucsra_shadow = bit(spec.udre_bit),
        };
    }

    pub fn handles(self: *const Usart, addr: u16) bool {
        return addr == self.spec.udr or
            addr == self.spec.ucsra or
            addr == self.spec.ucsrb or
            addr == self.spec.ucsrc or
            addr == self.spec.ubrrl or
            addr == self.spec.ubrrh;
    }

    pub fn read(self: *Usart, addr: u16, backing_value: u8, cycles: u64) u8 {
        self.tick(cycles);

        if (addr == self.spec.ucsra) {
            var value = backing_value & ~dynamicUcsrAMask(self.spec);

            if (self.dataRegisterEmpty(cycles)) {
                value |= bit(self.spec.udre_bit);
            }

            if (self.transmitComplete(cycles)) {
                value |= bit(self.spec.txc_bit);
            }

            if (self.rx_len > 0) {
                value |= bit(self.spec.rxc_bit);

                const frame = self.rx_buf[self.rx_head];
                if (frame.frame_error) value |= bit(fe_bit);
                if (frame.data_overrun) value |= bit(dor_bit);
                if (frame.parity_error) value |= bit(upe_bit);
            }

            return value;
        }

        if (addr == self.spec.ucsrb) {
            var value = backing_value & ~bit(rxb8_bit);
            if (self.rx_len > 0 and (self.rx_buf[self.rx_head].data & 0x100) != 0) {
                value |= bit(rxb8_bit);
            }
            return value;
        }

        if (addr == self.spec.udr) {
            return self.readData();
        }

        return backing_value;
    }

    pub fn write(self: *Usart, addr: u16, value: u8, cycles: u64) bool {
        self.tick(cycles);

        if (addr == self.spec.udr) {
            self.writeData(value, cycles);
            return true;
        }

        if (addr == self.spec.ucsra) {
            self.ucsra_shadow = value;
            if ((value & bit(self.spec.txc_bit)) != 0) {
                self.txc_pending = false;
            }
            return false;
        }

        if (addr == self.spec.ucsrb) {
            const was_rx_enabled = self.rxEnabled();
            self.ucsrb_shadow = value;
            if (was_rx_enabled and !self.rxEnabled()) {
                self.flushRx();
            }
            return false;
        }

        if (addr == self.spec.ucsrc) {
            self.ucsrc_shadow = value;
            return false;
        }

        if (addr == self.spec.ubrrl) {
            self.ubrrl_shadow = value;
            return false;
        }

        if (addr == self.spec.ubrrh) {
            self.ubrrh_shadow = value;
            return false;
        }

        return false;
    }

    pub fn injectRxByte(self: *Usart, value: u8, cycles: u64) void {
        self.injectRxFrame(value, false, false, false, cycles);
    }

    pub fn injectRxFrame(
        self: *Usart,
        value: u8,
        ninth_bit: bool,
        frame_error: bool,
        parity_error: bool,
        cycles: u64,
    ) void {
        self.tick(cycles);

        if (!self.rxEnabled()) {
            return;
        }

        if (self.rx_input_len == RxInputBufferSize) {
            self.rx_overrun_pending = true;
            return;
        }

        const config = self.frameConfig();
        const data = (@as(u16, value) | (if (ninth_bit) @as(u16, 0x100) else 0)) & dataMask(config.data_bits);

        self.rx_input_buf[self.rx_input_tail] = .{
            .data = data,
            .frame_error = frame_error,
            .parity_error = parity_error,
        };
        self.rx_input_tail = (self.rx_input_tail + 1) % RxInputBufferSize;
        self.rx_input_len += 1;

        self.startRxShift(cycles);
    }

    pub fn tick(self: *Usart, cycles: u64) void {
        self.advanceTx(cycles);
        self.advanceRx(cycles);
    }

    pub fn receiveComplete(self: *Usart, cycles: u64) bool {
        self.tick(cycles);
        return self.rx_len > 0;
    }

    pub fn receiveCompleteInterruptEnabled(self: *const Usart, ucsrb_value: u8) bool {
        return (ucsrb_value & bit(self.spec.rxcie_bit)) != 0;
    }

    pub fn receiveCompleteInterruptPending(self: *Usart, ucsrb_value: u8, cycles: u64) bool {
        return self.rxEnabled() and self.receiveComplete(cycles) and self.receiveCompleteInterruptEnabled(ucsrb_value);
    }

    pub fn dataRegisterEmptyInterruptEnabled(self: *const Usart, ucsrb_value: u8) bool {
        return (ucsrb_value & bit(self.spec.udrie_bit)) != 0;
    }

    pub fn dataRegisterEmpty(self: *Usart, cycles: u64) bool {
        self.tick(cycles);
        return self.tx_udr == null;
    }

    pub fn dataRegisterEmptyInterruptPending(self: *Usart, ucsrb_value: u8, cycles: u64) bool {
        return self.txEnabled() and self.dataRegisterEmptyInterruptEnabled(ucsrb_value) and self.dataRegisterEmpty(cycles);
    }

    pub fn transmitComplete(self: *Usart, cycles: u64) bool {
        self.tick(cycles);
        return self.txc_pending;
    }

    pub fn transmitCompleteInterruptPending(self: *Usart, ucsrb_value: u8, cycles: u64) bool {
        self.tick(cycles);
        return self.txEnabled() and (ucsrb_value & bit(self.spec.txcie_bit)) != 0 and self.txc_pending;
    }

    pub fn acceptTransmitCompleteInterrupt(self: *Usart) void {
        self.txc_pending = false;
    }

    fn readData(self: *Usart) u8 {
        if (self.rx_len == 0) {
            return 0;
        }

        const value = @as(u8, @intCast(self.rx_buf[self.rx_head].data & 0x00ff));
        self.rx_head = (self.rx_head + 1) % RxBufferSize;
        self.rx_len -= 1;

        return value;
    }

    fn writeData(self: *Usart, value: u8, cycles: u64) void {
        if (!self.txEnabled()) {
            return;
        }

        if (self.tx_udr != null) {
            return;
        }

        const config = self.frameConfig();
        const ninth_bit = if ((self.ucsrb_shadow & bit(txb8_bit)) != 0) @as(u16, 0x100) else 0;
        const data = (@as(u16, value) | ninth_bit) & dataMask(config.data_bits);

        self.tx_udr = .{
            .data = data,
            .byte = @as(u8, @intCast(data & 0x00ff)),
            .frame_cycles = config.frame_cycles,
        };
        self.txc_pending = false;
        self.startTxShift(cycles);
    }

    fn pushTxByte(self: *Usart, value: u8) void {
        if (self.tx_len == TxOutputBufferSize) {
            return;
        }

        self.tx_buf[self.tx_tail] = value;
        self.tx_tail = (self.tx_tail + 1) % TxOutputBufferSize;
        self.tx_len += 1;
    }

    pub fn takeTxByte(self: *Usart, cycles: u64) ?u8 {
        self.tick(cycles);

        if (self.tx_len == 0) {
            return null;
        }

        const value = self.tx_buf[self.tx_head];
        self.tx_head = (self.tx_head + 1) % TxOutputBufferSize;
        self.tx_len -= 1;

        return value;
    }

    fn advanceTx(self: *Usart, cycles: u64) void {
        while (self.tx_shift) |frame| {
            if (cycles < self.tx_shift_complete_cycle) {
                break;
            }

            const completed_at = self.tx_shift_complete_cycle;
            self.pushTxByte(frame.byte);
            self.tx_shift = null;

            if (self.tx_udr == null) {
                self.txc_pending = true;
                break;
            }

            self.startTxShift(completed_at);
        }

        self.startTxShift(cycles);
    }

    fn startTxShift(self: *Usart, cycles: u64) void {
        if (self.tx_shift != null or self.tx_udr == null or !self.txEnabled()) {
            return;
        }

        const frame = self.tx_udr.?;
        self.tx_udr = null;
        self.tx_shift = frame;
        self.tx_shift_complete_cycle = cycles + frame.frame_cycles;
    }

    fn advanceRx(self: *Usart, cycles: u64) void {
        self.startRxShift(cycles);

        while (self.rx_shift) |frame| {
            if (cycles < self.rx_shift_complete_cycle) {
                break;
            }

            const completed_at = self.rx_shift_complete_cycle;
            self.rx_shift = null;
            self.pushRxFrame(frame);
            self.startRxShift(completed_at);
        }
    }

    fn startRxShift(self: *Usart, cycles: u64) void {
        if (self.rx_shift != null or self.rx_input_len == 0 or !self.rxEnabled()) {
            return;
        }

        const frame = self.rx_input_buf[self.rx_input_head];
        self.rx_input_head = (self.rx_input_head + 1) % RxInputBufferSize;
        self.rx_input_len -= 1;

        self.rx_shift = frame;
        self.rx_shift_complete_cycle = cycles + self.frameConfig().frame_cycles;
    }

    fn pushRxFrame(self: *Usart, frame: RxFrame) void {
        if (self.rx_len == RxBufferSize) {
            const newest = if (self.rx_tail == 0) RxBufferSize - 1 else self.rx_tail - 1;
            self.rx_buf[newest].data_overrun = true;
            return;
        }

        var stored = frame;
        stored.data_overrun = stored.data_overrun or self.rx_overrun_pending;
        self.rx_overrun_pending = false;

        self.rx_buf[self.rx_tail] = stored;
        self.rx_tail = (self.rx_tail + 1) % RxBufferSize;
        self.rx_len += 1;
    }

    fn flushRx(self: *Usart) void {
        self.rx_head = 0;
        self.rx_tail = 0;
        self.rx_len = 0;
        self.rx_input_head = 0;
        self.rx_input_tail = 0;
        self.rx_input_len = 0;
        self.rx_shift = null;
        self.rx_overrun_pending = false;
    }

    pub fn rxEnabled(self: *const Usart) bool {
        return (self.ucsrb_shadow & bit(self.spec.rxen_bit)) != 0;
    }

    pub fn txEnabled(self: *const Usart) bool {
        return (self.ucsrb_shadow & bit(self.spec.txen_bit)) != 0;
    }

    pub fn frameConfig(self: *const Usart) FrameConfig {
        const ucsz = ((self.ucsrc_shadow >> 1) & 0b11) | (((self.ucsrb_shadow >> ucsz2_bit) & 0b1) << 2);
        const data_bits: u4 = switch (ucsz) {
            0b000 => 5,
            0b001 => 6,
            0b010 => 7,
            0b111 => 9,
            else => 8,
        };

        const parity: Parity = switch ((self.ucsrc_shadow >> 4) & 0b11) {
            0b10 => .even,
            0b11 => .odd,
            else => .none,
        };

        const stop_bits: u2 = if ((self.ucsrc_shadow & bit(usbs_bit)) != 0) 2 else 1;
        const parity_bits: u8 = if (parity == .none) 0 else 1;
        const total_bits = 1 + @as(u8, data_bits) + parity_bits + @as(u8, stop_bits);
        const bit_cycles = self.bitCycles();

        return .{
            .data_bits = data_bits,
            .parity = parity,
            .stop_bits = stop_bits,
            .bit_cycles = bit_cycles,
            .frame_cycles = bit_cycles * total_bits,
        };
    }

    pub fn bitCycles(self: *const Usart) u64 {
        const divider: u64 = if ((self.ucsra_shadow & bit(u2x_bit)) != 0) 8 else 16;
        const cycles = divider * (@as(u64, self.ubrrValue()) + 1);
        return if (cycles == 0) 1 else cycles;
    }

    pub fn ubrrValue(self: *const Usart) u16 {
        return (@as(u16, self.ubrrh_shadow & 0x0f) << 8) | self.ubrrl_shadow;
    }

    pub fn dataMask(data_bits: u4) u16 {
        return (@as(u16, 1) << data_bits) - 1;
    }

    pub fn dynamicUcsrAMask(spec: mcu_spec.UsartSpec) u8 {
        return bit(spec.rxc_bit) |
            bit(spec.txc_bit) |
            bit(spec.udre_bit) |
            bit(fe_bit) |
            bit(dor_bit) |
            bit(upe_bit);
    }
};

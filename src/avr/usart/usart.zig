const std = @import("std");
const mcu_spec = @import("../../mcu/spec.zig");

fn bit(bit_index: u3) u8 {
    return @as(u8, 1) << bit_index;
}

pub const Usart = struct {
    const RxBufferSize = 128;

    spec: mcu_spec.UsartSpec,

    rx_buf: [RxBufferSize]u8 = [_]u8{0} ** RxBufferSize,
    rx_head: usize = 0,
    rx_tail: usize = 0,
    rx_len: usize = 0,

    pub fn init(spec: mcu_spec.UsartSpec) Usart {
        return .{ .spec = spec };
    }

    pub fn handles(self: *const Usart, addr: u16) bool {
        return addr == self.spec.udr or
            addr == self.spec.ucsra or
            addr == self.spec.ucsrb or
            addr == self.spec.ucsrc or
            addr == self.spec.ubrrl or
            addr == self.spec.ubrrh;
    }

    pub fn read(self: *Usart, addr: u16, backing_value: u8) u8 {
        if (addr == self.spec.ucsra) {
            var value = backing_value;

            // Simplified TX model: transmitter is always ready.
            value |= bit(self.spec.udre_bit);
            value |= bit(self.spec.txc_bit);

            // RXC is dynamic: set while a received byte is waiting.
            if (self.rx_len > 0) {
                value |= bit(self.spec.rxc_bit);
            } else {
                value &= ~bit(self.spec.rxc_bit);
            }

            return value;
        }

        if (addr == self.spec.udr) {
            return self.readData();
        }

        return backing_value;
    }

    pub fn write(self: *Usart, addr: u16, value: u8, cycles: u64, clock_hz: u64) bool {
        if (addr == self.spec.udr) {
            self.writeData(value, cycles, clock_hz);
            return true;
        }

        // For UCSRnA/UCSRnB/UCSRnC/UBRRnL/UBRRnH, let DataMemory keep the value.
        return false;
    }

    pub fn injectRxByte(self: *Usart, value: u8) void {
        if (self.rx_len == RxBufferSize) {
            // First model: drop on overflow.
            // Later: model DORn in UCSRnA.
            return;
        }

        self.rx_buf[self.rx_tail] = value;
        self.rx_tail = (self.rx_tail + 1) % RxBufferSize;
        self.rx_len += 1;
    }

    pub fn receiveComplete(self: *const Usart) bool {
        return self.rx_len > 0;
    }

    pub fn receiveCompleteInterruptEnabled(self: *const Usart, ucsrb_value: u8) bool {
        return (ucsrb_value & bit(self.spec.rxcie_bit)) != 0;
    }

    pub fn receiveCompleteInterruptPending(self: *const Usart, ucsrb_value: u8) bool {
        return self.receiveComplete() and self.receiveCompleteInterruptEnabled(ucsrb_value);
    }

    pub fn dataRegisterEmptyInterruptEnabled(self: *const Usart, ucsrb_value: u8) bool {
        return (ucsrb_value & bit(self.spec.udrie_bit)) != 0;
    }

    pub fn dataRegisterEmpty(self: *const Usart) bool {
        _ = self;
        return true;
    }

    fn readData(self: *Usart) u8 {
        if (self.rx_len == 0) {
            return 0;
        }

        const value = self.rx_buf[self.rx_head];
        self.rx_head = (self.rx_head + 1) % RxBufferSize;
        self.rx_len -= 1;

        return value;
    }

    fn writeData(self: *Usart, value: u8, cycles: u64, clock_hz: u64) void {
        _ = self;
        _ = cycles;
        _ = clock_hz;

        if (value == '\r') return;

        if (value == '\n') {
            std.debug.print("\n", .{});
            return;
        }

        std.debug.print("{c}", .{value});
    }
};

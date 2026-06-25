const std = @import("std");
const memory = @import("../memory/memory.zig");
const constants = @import("../constants/constants.zig");
const timer = @import("../timer/timer.zig");
const decode = @import("decode.zig");
const board_spec = @import("../../board/spec.zig");
const mcu_spec = @import("../../mcu/spec.zig");
const gpio_mod = @import("../gpio/gpio.zig");
const usart_mod = @import("../usart/usart.zig");

const MaxUsarts = mcu_spec.MaxUsarts;

pub const Cpu = struct {
    flash: *const memory.Flash,

    mcu: *const mcu_spec.McuSpec,
    board: *const board_spec.BoardSpec,

    r: [32]u8 = [_]u8{0} ** 32,
    data: memory.DataMemory,

    timer0: timer.Timer0,
    usarts: [MaxUsarts]?usart_mod.Usart = [_]?usart_mod.Usart{null} ** MaxUsarts,
    gpio: ?*gpio_mod.Gpio = null,

    pc: u32 = 0,
    sp: u16,
    sreg: u8 = 0,
    cycles: u64 = 0,
    trace: bool = false,
    quiet: bool = false,

    pub fn init(allocator: std.mem.Allocator, board: *const board_spec.BoardSpec, flash: *const memory.Flash) !Cpu {
        var data = try memory.DataMemory.init(allocator, board.mcu);
        errdefer data.deinit(allocator);

        if (board.mcu.usarts.len > MaxUsarts) {
            return error.TooManyUsarts;
        }

        var cpu = Cpu{
            .mcu = board.mcu,
            .board = board,
            .timer0 = timer.Timer0.init(board.mcu),
            .data = data,
            .sp = board.mcu.sram.end,
            .flash = flash,
        };

        for (board.mcu.usarts, 0..) |usart_spec, i| {
            cpu.usarts[i] = usart_mod.Usart.init(usart_spec);
        }

        try cpu.syncStackPointerRegisters();

        return cpu;
    }

    pub fn deinit(self: *Cpu, allocator: std.mem.Allocator) void {
        self.data.deinit(allocator);
    }

    fn peripheralBus(_: *Cpu) memory.PeripheralBus {
        return .{
            .usart0 = null,
        };
    }

    fn findUsartByAddress(self: *Cpu, address: u16) ?*usart_mod.Usart {
        for (&self.usarts) |*maybe_usart| {
            if (maybe_usart.*) |*usart| {
                if (usart.handles(address)) {
                    return usart;
                }
            }
        }

        return null;
    }

    pub fn injectUsartRxByte(self: *Cpu, index: usize, value: u8) void {
        if (index >= self.usarts.len) return;

        if (self.usarts[index]) |*usart| {
            usart.injectRxByte(value);
        }
    }

    pub fn injectDefaultSerialRxByte(self: *Cpu, value: u8) void {
        self.injectUsartRxByte(self.board.default_serial_usart, value);
    }

    pub fn step(self: *Cpu) !void {
        const cycles_before = self.cycles;

        const opcode = try self.fetch16(self.pc);

        if (decode.decode(opcode)) |handler| {
            try handler(self, opcode);
        } else {
            return error.UnimplementedOpcode;
        }

        try self.afterInstruction(cycles_before);
    }

    pub fn fetch16(self: *Cpu, word_address: u32) !u16 {
        return try self.flash.readWord(@as(usize, @intCast(word_address)));
    }

    pub fn tracePrint(self: *const Cpu, comptime format: []const u8, args: anytype) void {
        if (self.trace and !self.quiet) {
            std.debug.print(format, args);
        }
    }

    fn pinPrint(self: *const Cpu, comptime format: []const u8, args: anytype) void {
        if (!self.quiet) {
            std.debug.print(format, args);
        }
    }

    pub fn writeIo(self: *Cpu, address: usize, value: u8) !void {
        if (address >= self.mcu.io.size) {
            return error.IoAddressOutOfRange;
        }

        const io_address: u16 = @intCast(address);
        const data_address = self.data.ioToDataAddress(io_address);

        if (address == self.mcu.io.spl) {
            try self.writeStackPointerLow(value);
            return;
        }

        if (address == self.mcu.io.sph) {
            try self.writeStackPointerHigh(value);
            return;
        }

        if (address == self.mcu.io.sreg) {
            self.sreg = value;
            try self.data.writeRawByte(data_address, value);
            return;
        }

        if (self.timer0.writeIo(address, value)) {
            return;
        }

        const old = try self.data.readRawByte(data_address);
        try self.data.writeRawByte(data_address, value);

        if (self.gpio) |gpio| {
            gpio.handleIoWrite(address, old, value);
        }
    }

    pub fn readIo(self: *Cpu, address: usize) !u8 {
        if (address >= self.mcu.io.size) {
            return error.IoAddressOutOfRange;
        }

        if (address == self.mcu.io.spl) {
            return self.stackPointerLow();
        }

        if (address == self.mcu.io.sph) {
            return self.stackPointerHigh();
        }

        if (address == self.mcu.io.sreg) {
            return self.sreg;
        }

        if (self.timer0.readIo(address)) |value| {
            return value;
        }

        const io_address: u16 = @intCast(address);
        const data_address = self.data.ioToDataAddress(io_address);

        return self.data.readRawByte(data_address);
    }

    pub fn readData(self: *Cpu, address: u16) !u8 {
        if (address < self.r.len) {
            return self.r[address];
        }

        const io_base: u16 = @intCast(self.r.len);
        const io_size: u16 = @intCast(self.mcu.io.size);

        if (address >= io_base and address < io_base + io_size) {
            return try self.readIo(@intCast(address - io_base));
        }

        if (address == self.mcu.data.sreg) {
            return self.sreg;
        }

        if (self.timer0.readData(address)) |value| {
            return value;
        }

        if (self.findUsartByAddress(address)) |usart| {
            const raw = try self.data.readRawByte(address);
            return usart.read(address, raw);
        }

        var bus = self.peripheralBus();
        return self.data.readByte(address, &bus);
    }

    pub fn writeData(self: *Cpu, address: u16, value: u8) !void {
        if (address < self.r.len) {
            self.r[address] = value;
            return;
        }

        const io_base: u16 = @intCast(self.r.len);
        const io_size: u16 = @intCast(self.mcu.io.size);

        if (address >= io_base and address < io_base + io_size) {
            try self.writeIo(@intCast(address - io_base), value);
            return;
        }

        if (address == self.mcu.data.sreg) {
            self.sreg = value;
            try self.data.writeRawByte(address, value);
            return;
        }

        if (self.timer0.writeData(address, value)) {
            return;
        }

        if (self.findUsartByAddress(address)) |usart| {
            try self.data.writeRawByte(address, value);
            _ = usart.write(address, value, self.cycles, self.board.clock_hz);
            return;
        }

        var bus = self.peripheralBus();
        try self.data.writeByte(
            address,
            value,
            self.cycles,
            self.board.clock_hz,
            &bus,
        );
    }

    pub fn pushByte(self: *Cpu, value: u8) !void {
        if (self.sp >= self.data.bytes.len) {
            return error.StackPointerOutOfRange;
        }

        try self.data.writeRawByte(self.sp, value);

        if (self.sp == 0) {
            return error.StackPointerOutOfRange;
        }

        self.sp -= 1;
        try self.syncStackPointerRegisters();
    }

    pub fn popByte(self: *Cpu) !u8 {
        if (self.sp == self.mcu.sram.end) {
            return error.StackPointerOutOfRange;
        }

        self.sp += 1;
        try self.syncStackPointerRegisters();

        if (self.sp >= self.data.bytes.len) {
            return error.StackPointerOutOfRange;
        }

        return self.data.readRawByte(self.sp);
    }

    pub fn pushReturnAddress(self: *Cpu, address: u32) !void {
        try self.pushByte(@as(u8, @intCast((address >> 8) & 0xff)));
        try self.pushByte(@as(u8, @intCast(address & 0xff)));
    }

    pub fn popReturnAddress(self: *Cpu) !u32 {
        const low = try self.popByte();
        const high = try self.popByte();

        return @as(u32, low) | (@as(u32, high) << 8);
    }

    pub fn setLogicFlags(self: *Cpu, result: u8) void {
        self.setFlag(constants.Sreg.z, result == 0);
        self.setFlag(constants.Sreg.n, (result & 0x80) != 0);
        self.setFlag(constants.Sreg.v, false);
        self.setFlag(constants.Sreg.s, self.getFlag(constants.Sreg.n));
    }

    pub fn setAddFlags(self: *Cpu, left: u8, right: u8, result: u8) void {
        const half_carry = ((left & right) | (right & ~result) | (~result & left)) & 0x08;
        const overflow = ((left & right & ~result) | (~left & ~right & result)) & 0x80;
        const carry = ((left & right) | (right & ~result) | (~result & left)) & 0x80;

        self.setFlag(constants.Sreg.h, half_carry != 0);
        self.setFlag(constants.Sreg.z, result == 0);
        self.setFlag(constants.Sreg.n, (result & 0x80) != 0);
        self.setFlag(constants.Sreg.v, overflow != 0);
        self.setFlag(constants.Sreg.s, self.getFlag(constants.Sreg.n) != self.getFlag(constants.Sreg.v));
        self.setFlag(constants.Sreg.c, carry != 0);
    }

    pub fn setSubtractFlags(
        self: *Cpu,
        left: u8,
        right: u8,
        preserve_zero: bool,
    ) void {
        const result = left -% right;
        self.setSubtractResultFlags(left, right, result, preserve_zero);
    }

    pub fn setSubtractResultFlags(
        self: *Cpu,
        left: u8,
        right: u8,
        result: u8,
        preserve_zero: bool,
    ) void {
        const half_carry =
            ((~left & right) | (right & result) | (result & ~left)) & 0x08;

        const overflow =
            ((left & ~right & ~result) | (~left & right & result)) & 0x80;

        const carry =
            ((~left & right) | (right & result) | (result & ~left)) & 0x80;

        self.setFlag(constants.Sreg.h, half_carry != 0);
        self.setFlag(
            constants.Sreg.z,
            if (preserve_zero)
                self.getFlag(constants.Sreg.z) and result == 0
            else
                result == 0,
        );
        self.setFlag(constants.Sreg.n, (result & 0x80) != 0);
        self.setFlag(constants.Sreg.v, overflow != 0);
        self.setFlag(constants.Sreg.s, self.getFlag(constants.Sreg.n) != self.getFlag(constants.Sreg.v));
        self.setFlag(constants.Sreg.c, carry != 0);
    }

    pub fn setAdiwFlags(self: *Cpu, left: u16, result: u16) void {
        const r15 = (result & 0x8000) != 0;
        const left15 = (left & 0x8000) != 0;

        self.setFlag(constants.Sreg.z, result == 0);
        self.setFlag(constants.Sreg.n, r15);
        self.setFlag(constants.Sreg.v, !left15 and r15);
        self.setFlag(constants.Sreg.s, self.getFlag(constants.Sreg.n) != self.getFlag(constants.Sreg.v));
        self.setFlag(constants.Sreg.c, !r15 and left15);
    }

    pub fn setSbiwFlags(self: *Cpu, left: u16, result: u16) void {
        const r15 = (result & 0x8000) != 0;
        const left15 = (left & 0x8000) != 0;

        self.setFlag(constants.Sreg.z, result == 0);
        self.setFlag(constants.Sreg.n, r15);
        self.setFlag(constants.Sreg.v, left15 and !r15);
        self.setFlag(constants.Sreg.s, self.getFlag(constants.Sreg.n) != self.getFlag(constants.Sreg.v));
        self.setFlag(constants.Sreg.c, r15 and !left15);
    }

    pub fn skipIf(self: *Cpu, should_skip: bool, comptime name: []const u8) !void {
        if (!should_skip) {
            self.tracePrint("{s} ; not skipped\n", .{name});
            self.pc += 1;
            self.cycles += constants.Cycles.skip_not_taken;
            return;
        }

        const next_opcode = try self.fetch16(self.pc + 1);
        const skipped_words: u32 = if (Cpu.isTwoWordInstruction(next_opcode)) 2 else 1;

        self.tracePrint("{s} ; skipped {} word(s)\n", .{ name, skipped_words });

        self.pc += 1 + skipped_words;
        self.cycles += if (skipped_words == 2) constants.Cycles.skip_two_word else constants.Cycles.skip_one_word;
    }

    pub fn isTwoWordInstruction(opcode: u16) bool {
        return decode.isTwoWordInstruction(opcode);
    }

    pub fn readRegisterWord(self: *const Cpu, register_index: usize) u16 {
        return @as(u16, self.r[register_index]) | (@as(u16, self.r[register_index + 1]) << 8);
    }

    pub fn writeRegisterWord(self: *Cpu, register_index: usize, value: u16) void {
        self.r[register_index] = @as(u8, @intCast(value & 0x00ff));
        self.r[register_index + 1] = @as(u8, @intCast(value >> 8));
    }

    pub fn getFlag(self: *const Cpu, flag: u3) bool {
        return (self.sreg & decode.bitMask(flag)) != 0;
    }

    pub fn setFlag(self: *Cpu, flag: u3, value: bool) void {
        if (value) {
            self.sreg |= decode.bitMask(flag);
        } else {
            self.sreg &= ~decode.bitMask(flag);
        }
    }

    fn afterInstruction(self: *Cpu, cycles_before: u64) !void {
        const elapsed = self.cycles - cycles_before;

        if (elapsed == 0) {
            std.debug.print("[cpu] zero elapsed cycles at pc=0x{x:0>4}\n", .{self.pc});
            return error.InstructionDidNotAdvanceCycles;
        }

        self.timer0.tick(elapsed);

        try self.serviceInterrupts();
    }

    fn serviceInterrupts(self: *Cpu) !void {
        if (!self.getFlag(constants.Sreg.i)) {
            return;
        }

        if (self.timer0.overflowInterruptPending()) {
            self.timer0.acceptOverflowInterrupt();
            try self.fireInterrupt(self.mcu.vectors.timer0_ovf_word_addr);
            return;
        }

        for (&self.usarts) |*maybe_usart| {
            if (maybe_usart.*) |*usart| {
                const ucsrb = self.data.readRawByte(usart.spec.ucsrb) catch 0;

                // RX first: USART_RX vector has higher priority than UDRE.
                if (usart.receiveCompleteInterruptPending(ucsrb)) {
                    try self.fireInterrupt(usart.spec.rx_vector_word_addr);
                    return;
                }

                if (usart.dataRegisterEmptyInterruptEnabled(ucsrb) and usart.dataRegisterEmpty()) {
                    try self.fireInterrupt(usart.spec.udre_vector_word_addr);
                    return;
                }
            }
        }
    }

    fn fireInterrupt(self: *Cpu, vector_word: u16) !void {
        const return_pc = self.pc;

        self.sreg &= ~(@as(u8, 1) << constants.Sreg.i);

        try self.pushReturnAddress(return_pc);

        self.pc = vector_word;
        self.cycles += constants.Cycles.interrupt_entry;
        self.timer0.tick(constants.Cycles.interrupt_entry);
    }

    fn stackPointerLow(self: *const Cpu) u8 {
        return @as(u8, @intCast(self.sp & 0x00ff));
    }

    fn stackPointerHigh(self: *const Cpu) u8 {
        return @as(u8, @intCast((self.sp >> 8) & 0x00ff));
    }

    fn writeStackPointerLow(self: *Cpu, value: u8) !void {
        self.sp = (self.sp & 0xff00) | @as(u16, value);
        try self.syncStackPointerRegisters();
    }

    fn writeStackPointerHigh(self: *Cpu, value: u8) !void {
        self.sp = (@as(u16, value) << 8) | (self.sp & 0x00ff);
        try self.syncStackPointerRegisters();
    }

    fn syncStackPointerRegisters(self: *Cpu) !void {
        try self.data.writeRawByte(self.mcu.data.spl, self.stackPointerLow());
        try self.data.writeRawByte(self.mcu.data.sph, self.stackPointerHigh());
    }
};

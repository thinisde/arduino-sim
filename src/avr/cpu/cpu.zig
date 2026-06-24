const std = @import("std");
const memory = @import("../memory/memory.zig");
const constants = @import("../constants/constants.zig");
const timer = @import("../timer/timer.zig");
const decode = @import("decode.zig");
const board_spec = @import("../../board/spec.zig");
const mcu_spec = @import("../../mcu/spec.zig");
const gpio_mod = @import("../gpio/gpio.zig");

pub const Cpu = struct {
    flash: *const memory.Flash,

    mcu: *const mcu_spec.McuSpec,
    board: *const board_spec.BoardSpec,

    r: [32]u8 = [_]u8{0} ** 32,
    io: []u8,
    sram: []u8,
    timer0: timer.Timer0,
    gpio: ?*gpio_mod.Gpio = null,
    pc: u32 = 0,

    sp: u16,
    sreg: u8 = 0,
    cycles: u64 = 0,
    trace: bool = false,
    quiet: bool = false,

    pub fn init(allocator: std.mem.Allocator, board: *const board_spec.BoardSpec, flash: *const memory.Flash) !Cpu {
        const io = try allocator.alloc(u8, board.mcu.io.size);
        errdefer allocator.free(io);
        @memset(io, 0);

        const sram = try allocator.alloc(u8, board.mcu.data.size);
        errdefer allocator.free(sram);
        @memset(sram, 0);

        return Cpu{
            .mcu = board.mcu,
            .board = board,
            .timer0 = timer.Timer0.init(board.mcu),

            .io = io,
            .sram = sram,
            .sp = board.mcu.sram.end,

            .flash = flash,
        };
    }

    pub fn deinit(self: *Cpu, allocator: std.mem.Allocator) void {
        allocator.free(self.io);
        allocator.free(self.sram);

        self.io = &[_]u8{};
        self.sram = &[_]u8{};
    }

    pub fn step(self: *Cpu) !void {
        const cycles_before = self.cycles;

        const opcode = try self.fetch16(self.pc);

        self.tracePrint("PC=0x{x:0>4} opcode=0x{x:0>4} ", .{
            self.pc,
            opcode,
        });

        if (decode.decode(opcode)) |handler| {
            try handler(self, opcode);
        } else {
            const byte_pc = self.pc * 2;

            std.debug.print(
                "[cpu] unknown opcode: pc_word=0x{x:0>4} pc_byte=0x{x:0>4} opcode=0x{x:0>4}\n",
                .{
                    self.pc,
                    byte_pc,
                    opcode,
                },
            );

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
        if (address >= self.io.len) {
            return error.IoAddressOutOfRange;
        }

        if (address == self.mcu.io.sreg) {
            self.sreg = value;
            self.io[address] = value;
            return;
        }

        if (self.timer0.writeIo(address, value)) {
            return;
        }

        const old = self.io[address];
        self.io[address] = value;

        if (self.gpio) |gpio| {
            gpio.handleIoWrite(address, old, value);
        }
    }

    pub fn readIo(self: *Cpu, address: usize) !u8 {
        if (address >= self.io.len) {
            return error.IoAddressOutOfRange;
        }

        if (address == self.mcu.io.sreg) {
            return self.sreg;
        }

        if (self.timer0.readIo(address)) |value| {
            return value;
        }

        return self.io[address];
    }

    pub fn readData(self: *Cpu, address: u16) !u8 {
        if (address < self.r.len) {
            return self.r[address];
        }

        const io_base = self.r.len;
        if (address >= io_base and address < io_base + self.io.len) {
            return try self.readIo(address - io_base);
        }

        if (self.timer0.readData(address)) |value| {
            return value;
        }

        if (address >= self.sram.len) {
            return error.DataAddressOutOfRange;
        }

        return self.sram[address];
    }

    pub fn writeData(self: *Cpu, address: u16, value: u8) !void {
        if (address < self.r.len) {
            self.r[address] = value;
            return;
        }

        const io_base = self.r.len;
        if (address >= io_base and address < io_base + self.io.len) {
            try self.writeIo(address - io_base, value);
            return;
        }

        if (self.timer0.writeData(address, value)) {
            return;
        }

        if (address >= self.sram.len) {
            return error.DataAddressOutOfRange;
        }

        self.sram[address] = value;
    }

    pub fn pushByte(self: *Cpu, value: u8) !void {
        if (self.sp >= self.sram.len) {
            return error.StackPointerOutOfRange;
        }

        self.sram[self.sp] = value;

        if (self.sp == 0) {
            return error.StackPointerOutOfRange;
        }

        self.sp -= 1;
    }

    pub fn popByte(self: *Cpu) !u8 {
        if (self.sp == self.mcu.sram.end) {
            return error.StackPointerOutOfRange;
        }

        self.sp += 1;

        if (self.sp >= self.sram.len) {
            return error.StackPointerOutOfRange;
        }

        return self.sram[self.sp];
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

    pub fn setSubtractFlags(self: *Cpu, left: u8, right: u8, preserve_zero: bool) void {
        const result = left -% right;
        const half_carry = ((~left & right) | (right & result) | (result & ~left)) & 0x08;
        const overflow = ((left & ~right & ~result) | (~left & right & result)) & 0x80;
        const carry = ((~left & right) | (right & result) | (result & ~left)) & 0x80;

        self.setFlag(constants.Sreg.h, half_carry != 0);
        self.setFlag(constants.Sreg.z, if (preserve_zero) self.getFlag(constants.Sreg.z) and result == 0 else result == 0);
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

        self.timer0.tick(@intCast(elapsed));

        try self.serviceInterrupts();
    }

    fn serviceInterrupts(self: *Cpu) !void {
        const global_interrupts_enabled =
            (self.sreg & (@as(u8, 1) << constants.Sreg.i)) != 0;

        if (!global_interrupts_enabled) return;

        if (self.timer0.overflowInterruptPending()) {
            self.timer0.acceptOverflowInterrupt();
            try self.fireInterrupt(self.mcu.vectors.timer0_ovf_word_addr);
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
};

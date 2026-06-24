const std = @import("std");
const memory = @import("memory.zig");
const constants = @import("constants.zig");

pub const Cpu = struct {
    flash: *const memory.Flash,

    r: [32]u8 = [_]u8{0} ** 32,

    // AVR program counter as a WORD address.
    pc: u32 = 0,

    sp: u16 = constants.Sram.end,
    sreg: u8 = 0,
    cycles: u64 = 0,

    pub fn init(flash: *const memory.Flash) Cpu {
        return Cpu{
            .flash = flash,
        };
    }

    pub fn step(self: *Cpu) !void {
        const opcode = try self.fetch16(self.pc);

        std.debug.print("PC=0x{x:0>4} opcode=0x{x:0>4} ", .{
            self.pc,
            opcode,
        });

        if (opcode == constants.Opcode.nop) {
            try self.execNop();
        } else if ((opcode & constants.Opcode.jmp_mask) == constants.Opcode.jmp_pattern) {
            try self.execJmp(opcode);
        } else if ((opcode & constants.Opcode.rjmp_mask) == constants.Opcode.rjmp_pattern) {
            try self.execRjmp(opcode);
        } else if ((opcode & constants.Opcode.ldi_mask) == constants.Opcode.ldi_pattern) {
            try self.execLdi(opcode);
        } else {
            std.debug.print("UNKNOWN\n", .{});
            return error.UnimplementedOpcode;
        }
    }

    fn fetch16(self: *Cpu, word_address: u32) !u16 {
        return try self.flash.readWord(@as(usize, @intCast(word_address)));
    }

    fn execNop(self: *Cpu) !void {
        std.debug.print("NOP\n", .{});

        self.pc += 1;
        self.cycles += constants.Cycles.nop;
    }

    fn execJmp(self: *Cpu, opcode: u16) !void {
        const next_word = try self.fetch16(self.pc + 1);

        const high_bits =
            (@as(u32, opcode & constants.Jmp.high_bits_mask) << constants.Jmp.high_bits_shift) |
            (@as(u32, opcode & constants.Jmp.low_high_bit_mask) << constants.Jmp.low_high_bit_shift);

        const target = high_bits | @as(u32, next_word);

        std.debug.print("JMP 0x{x:0>4}\n", .{target});

        self.pc = target;
        self.cycles += constants.Cycles.jmp;
    }

    fn execRjmp(self: *Cpu, opcode: u16) !void {
        const raw: i32 = @as(
            i32,
            @intCast(opcode & constants.Rjmp.offset_mask),
        );

        const offset: i32 = if ((opcode & constants.Rjmp.sign_bit) != 0)
            raw - constants.Rjmp.sign_extend_subtract
        else
            raw;

        const next_pc: i32 = @as(i32, @intCast(self.pc)) + 1 + offset;

        if (next_pc < 0) {
            return error.ProgramCounterOutOfRange;
        }

        std.debug.print("RJMP {d} -> 0x{x:0>4}\n", .{
            offset,
            @as(u32, @intCast(next_pc)),
        });

        self.pc = @as(u32, @intCast(next_pc));
        self.cycles += constants.Cycles.rjmp;
    }

    fn execLdi(self: *Cpu, opcode: u16) !void {
        const register_index = constants.Ldi.register_base + @as(usize, @intCast(
            (opcode & constants.Ldi.register_mask) >> constants.Ldi.register_shift,
        ));

        const imm_low = opcode & constants.Ldi.imm_low_mask;

        const imm_high = (opcode & constants.Ldi.imm_high_mask) >> constants.Ldi.imm_high_shift;

        const value: u8 = @as(u8, @intCast(imm_high | imm_low));

        self.r[register_index] = value;

        std.debug.print("LDI r{} 0x{x:0>2}\n", .{ register_index, value });

        self.pc += 1;
        self.cycles += constants.Ldi.cycles;
    }
};

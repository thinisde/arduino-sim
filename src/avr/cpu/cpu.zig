const std = @import("std");
const memory = @import("../memory/memory.zig");
const constants = @import("../constants/constants.zig");
const timer = @import("../timer/timer.zig");

pub const Cpu = struct {
    const PointerMode = enum {
        none,
        postincrement,
        predecrement,
    };

    flash: *const memory.Flash,

    r: [32]u8 = [_]u8{0} ** 32,
    io: [constants.Io.size]u8 = [_]u8{0} ** constants.Io.size,
    sram: [constants.Sram.size]u8 = [_]u8{0} ** constants.Sram.size,
    timer0: timer.Timer0 = .{},
    pc: u32 = 0,

    sp: u16 = constants.Sram.end,
    sreg: u8 = 0,
    cycles: u64 = 0,
    trace: bool = false,
    quiet: bool = false,

    pub fn init(flash: *const memory.Flash) Cpu {
        return Cpu{
            .flash = flash,
        };
    }

    pub fn step(self: *Cpu) !void {
        const cycles_before = self.cycles;

        const opcode = try self.fetch16(self.pc);

        self.tracePrint("PC=0x{x:0>4} opcode=0x{x:0>4} ", .{
            self.pc,
            opcode,
        });

        if (opcode == constants.Opcode.nop) {
            try self.execNop();
        } else if (opcode == constants.Opcode.ret) {
            try self.execRet();
        } else if (opcode == constants.Opcode.reti) {
            try self.execReti();
        } else if (opcode == constants.Opcode.cli) {
            try self.execSetInterruptFlag(false, "CLI");
        } else if (opcode == constants.Opcode.sei) {
            try self.execSetInterruptFlag(true, "SEI");
        } else if (opcode == constants.Opcode.lpm) {
            try self.execLpmImplicit();
        } else if ((opcode & constants.Opcode.ld_x_mask) == constants.Opcode.ld_x_pattern) {
            try self.execLdPointer(opcode, 26, .none, "LD X");
        } else if ((opcode & constants.Opcode.ld_x_postincrement_mask) == constants.Opcode.ld_x_postincrement_pattern) {
            try self.execLdPointer(opcode, 26, .postincrement, "LD X+");
        } else if ((opcode & constants.Opcode.ld_x_predecrement_mask) == constants.Opcode.ld_x_predecrement_pattern) {
            try self.execLdPointer(opcode, 26, .predecrement, "LD -X");
        } else if ((opcode & constants.Opcode.st_x_mask) == constants.Opcode.st_x_pattern) {
            try self.execStPointer(opcode, 26, .none, "ST X");
        } else if ((opcode & constants.Opcode.st_x_postincrement_mask) == constants.Opcode.st_x_postincrement_pattern) {
            try self.execStPointer(opcode, 26, .postincrement, "ST X+");
        } else if ((opcode & constants.Opcode.st_x_predecrement_mask) == constants.Opcode.st_x_predecrement_pattern) {
            try self.execStPointer(opcode, 26, .predecrement, "ST -X");
        } else if ((opcode & constants.Opcode.call_mask) == constants.Opcode.call_pattern) {
            try self.execCall(opcode);
        } else if ((opcode & constants.Opcode.jmp_mask) == constants.Opcode.jmp_pattern) {
            try self.execJmp(opcode);
        } else if ((opcode & constants.Opcode.rcall_mask) == constants.Opcode.rcall_pattern) {
            try self.execRcall(opcode);
        } else if ((opcode & constants.Opcode.rjmp_mask) == constants.Opcode.rjmp_pattern) {
            try self.execRjmp(opcode);
        } else if ((opcode & constants.Opcode.brne_mask) == constants.Opcode.brne_pattern) {
            try self.execBranch(opcode, !self.getFlag(constants.Sreg.z), "BRNE");
        } else if ((opcode & constants.Opcode.breq_mask) == constants.Opcode.breq_pattern) {
            try self.execBranch(opcode, self.getFlag(constants.Sreg.z), "BREQ");
        } else if ((opcode & constants.Opcode.brcc_mask) == constants.Opcode.brcc_pattern) {
            try self.execBranch(opcode, !self.getFlag(constants.Sreg.c), "BRCC");
        } else if ((opcode & constants.Opcode.brcs_mask) == constants.Opcode.brcs_pattern) {
            try self.execBranch(opcode, self.getFlag(constants.Sreg.c), "BRCS");
        } else if ((opcode & constants.Opcode.ldi_mask) == constants.Opcode.ldi_pattern) {
            try self.execLdi(opcode);
        } else if ((opcode & constants.Opcode.subi_mask) == constants.Opcode.subi_pattern) {
            try self.execSubi(opcode);
        } else if ((opcode & constants.Opcode.sbci_mask) == constants.Opcode.sbci_pattern) {
            try self.execSbci(opcode);
        } else if ((opcode & constants.Opcode.cpi_mask) == constants.Opcode.cpi_pattern) {
            try self.execCpi(opcode);
        } else if ((opcode & constants.Opcode.ori_mask) == constants.Opcode.ori_pattern) {
            try self.execOri(opcode);
        } else if ((opcode & constants.Opcode.andi_mask) == constants.Opcode.andi_pattern) {
            try self.execAndi(opcode);
        } else if ((opcode & constants.Opcode.adiw_mask) == constants.Opcode.adiw_pattern) {
            try self.execAdiw(opcode);
        } else if ((opcode & constants.Opcode.sbiw_mask) == constants.Opcode.sbiw_pattern) {
            try self.execSbiw(opcode);
        } else if ((opcode & constants.Opcode.in_mask) == constants.Opcode.in_pattern) {
            try self.execIn(opcode);
        } else if ((opcode & constants.Opcode.out_mask) == constants.Opcode.out_pattern) {
            try self.execOut(opcode);
        } else if ((opcode & constants.Opcode.sbi_mask) == constants.Opcode.sbi_pattern) {
            try self.execSbi(opcode);
        } else if ((opcode & constants.Opcode.cbi_mask) == constants.Opcode.cbi_pattern) {
            try self.execCbi(opcode);
        } else if ((opcode & constants.Opcode.sbis_mask) == constants.Opcode.sbis_pattern) {
            try self.execSbis(opcode);
        } else if ((opcode & constants.Opcode.inc_mask) == constants.Opcode.inc_pattern) {
            try self.execInc(opcode);
        } else if ((opcode & constants.Opcode.dec_mask) == constants.Opcode.dec_pattern) {
            try self.execDec(opcode);
        } else if ((opcode & constants.Opcode.com_mask) == constants.Opcode.com_pattern) {
            try self.execCom(opcode);
        } else if ((opcode & constants.Opcode.push_mask) == constants.Opcode.push_pattern) {
            try self.execPush(opcode);
        } else if ((opcode & constants.Opcode.pop_mask) == constants.Opcode.pop_pattern) {
            try self.execPop(opcode);
        } else if ((opcode & constants.Opcode.lds_mask) == constants.Opcode.lds_pattern) {
            try self.execLds(opcode);
        } else if ((opcode & constants.Opcode.sts_mask) == constants.Opcode.sts_pattern) {
            try self.execSts(opcode);
        } else if ((opcode & constants.Opcode.lpm_z_mask) == constants.Opcode.lpm_z_pattern) {
            try self.execLpm(opcode);
        } else if ((opcode & constants.Opcode.ld_z_mask) == constants.Opcode.ld_z_pattern) {
            try self.execLdPointer(opcode, 30, .none, "LD Z");
        } else if ((opcode & constants.Opcode.ld_y_mask) == constants.Opcode.ld_y_pattern) {
            try self.execLdPointer(opcode, 28, .none, "LD Y");
        } else if ((opcode & constants.Opcode.st_z_mask) == constants.Opcode.st_z_pattern) {
            try self.execStPointer(opcode, 30, .none, "ST Z");
        } else if ((opcode & constants.Opcode.st_y_mask) == constants.Opcode.st_y_pattern) {
            try self.execStPointer(opcode, 28, .none, "ST Y");
        } else if ((opcode & constants.Opcode.movw_mask) == constants.Opcode.movw_pattern) {
            try self.execMovw(opcode);
        } else if ((opcode & constants.Opcode.add_mask) == constants.Opcode.add_pattern) {
            try self.execAdd(opcode);
        } else if ((opcode & constants.Opcode.adc_mask) == constants.Opcode.adc_pattern) {
            try self.execAdc(opcode);
        } else if ((opcode & constants.Opcode.sub_mask) == constants.Opcode.sub_pattern) {
            try self.execSub(opcode);
        } else if ((opcode & constants.Opcode.sbc_mask) == constants.Opcode.sbc_pattern) {
            try self.execSbc(opcode);
        } else if ((opcode & constants.Opcode.cpc_mask) == constants.Opcode.cpc_pattern) {
            try self.execCpc(opcode);
        } else if ((opcode & constants.Opcode.cpse_mask) == constants.Opcode.cpse_pattern) {
            try self.execCpse(opcode);
        } else if ((opcode & constants.Opcode.eor_mask) == constants.Opcode.eor_pattern) {
            try self.execEor(opcode);
        } else if ((opcode & constants.Opcode.mov_mask) == constants.Opcode.mov_pattern) {
            try self.execMov(opcode);
        } else if ((opcode & constants.Opcode.and_mask) == constants.Opcode.and_pattern) {
            try self.execAnd(opcode);
        } else if ((opcode & constants.Opcode.or_mask) == constants.Opcode.or_pattern) {
            try self.execOr(opcode);
        } else if ((opcode & constants.Opcode.cp_mask) == constants.Opcode.cp_pattern) {
            try self.execCp(opcode);
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

    fn fetch16(self: *Cpu, word_address: u32) !u16 {
        return try self.flash.readWord(@as(usize, @intCast(word_address)));
    }

    fn execNop(self: *Cpu) !void {
        self.tracePrint("NOP\n", .{});

        self.pc += 1;
        self.cycles += constants.Cycles.nop;
    }

    fn execJmp(self: *Cpu, opcode: u16) !void {
        const next_word = try self.fetch16(self.pc + 1);

        const high_bits =
            (@as(u32, opcode & constants.Jmp.high_bits_mask) << constants.Jmp.high_bits_shift) |
            (@as(u32, opcode & constants.Jmp.low_high_bit_mask) << constants.Jmp.low_high_bit_shift);

        const target = high_bits | @as(u32, next_word);

        self.tracePrint("JMP 0x{x:0>4}\n", .{target});

        self.pc = target;
        self.cycles += constants.Cycles.jmp;
    }

    fn execRjmp(self: *Cpu, opcode: u16) !void {
        const offset = decodeRelative12(opcode);

        const next_pc: i32 = @as(i32, @intCast(self.pc)) + 1 + offset;

        if (next_pc < 0) {
            return error.ProgramCounterOutOfRange;
        }

        self.tracePrint("RJMP {d} -> 0x{x:0>4}\n", .{
            offset,
            @as(u32, @intCast(next_pc)),
        });

        self.pc = @as(u32, @intCast(next_pc));
        self.cycles += constants.Cycles.rjmp;
    }

    fn execRcall(self: *Cpu, opcode: u16) !void {
        const offset = decodeRelative12(opcode);
        const return_address = self.pc + 1;
        const next_pc: i32 = @as(i32, @intCast(return_address)) + offset;

        if (next_pc < 0) {
            return error.ProgramCounterOutOfRange;
        }

        try self.pushReturnAddress(return_address);

        self.tracePrint("RCALL {d} -> 0x{x:0>4}\n", .{
            offset,
            @as(u32, @intCast(next_pc)),
        });

        self.pc = @as(u32, @intCast(next_pc));
        self.cycles += constants.Cycles.rcall;
    }

    fn execLdi(self: *Cpu, opcode: u16) !void {
        const register_index = decodeImmediateRegister(opcode);
        const value = decodeImmediate(opcode);

        self.r[register_index] = value;

        self.tracePrint("LDI r{} 0x{x:0>2}\n", .{ register_index, value });

        self.pc += 1;
        self.cycles += constants.Ldi.cycles;
    }

    fn execIn(self: *Cpu, opcode: u16) !void {
        const io_address = decodeIoAddress(opcode);
        const register_index = decodeIoRegister(opcode);
        const value = try self.readIo(io_address);

        self.r[register_index] = value;

        self.tracePrint("IN r{} io[0x{x:0>2}] ; value=0x{x:0>2}\n", .{ register_index, io_address, value });

        self.pc += 1;
        self.cycles += constants.Cycles.in;
    }

    fn execOut(self: *Cpu, opcode: u16) !void {
        const io_address = decodeIoAddress(opcode);
        const register_index = decodeIoRegister(opcode);

        const value = self.r[register_index];

        try self.writeIo(io_address, value);

        self.tracePrint("OUT io[0x{x:0>2}] r{} ; value=0x{x:0>2}\n", .{ io_address, register_index, value });

        self.pc += 1;
        self.cycles += constants.Cycles.out;
    }

    fn execSbi(self: *Cpu, opcode: u16) !void {
        const io_address = decodeBitIoAddress(opcode);
        const bit = decodeBitIoBit(opcode);
        const value = (try self.readIo(io_address)) | bitMask(bit);

        try self.writeIo(io_address, value);

        self.tracePrint("SBI io[0x{x:0>2}] {}\n", .{ io_address, bit });

        self.pc += 1;
        self.cycles += constants.Cycles.sbi;
    }

    fn execCbi(self: *Cpu, opcode: u16) !void {
        const io_address = decodeBitIoAddress(opcode);
        const bit = decodeBitIoBit(opcode);
        const value = (try self.readIo(io_address)) & ~bitMask(bit);

        try self.writeIo(io_address, value);

        self.tracePrint("CBI io[0x{x:0>2}] {}\n", .{ io_address, bit });

        self.pc += 1;
        self.cycles += constants.Cycles.cbi;
    }

    fn execSbis(self: *Cpu, opcode: u16) !void {
        const io_address = decodeBitIoAddress(opcode);
        const bit = decodeBitIoBit(opcode);
        const should_skip = ((try self.readIo(io_address)) & bitMask(bit)) != 0;

        try self.skipIf(should_skip, "SBIS");
    }

    fn execMov(self: *Cpu, opcode: u16) !void {
        const destination = decodeDestinationRegister(opcode);
        const source = decodeSourceRegister(opcode);

        self.r[destination] = self.r[source];

        self.tracePrint("MOV r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, self.r[destination] });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execMovw(self: *Cpu, opcode: u16) !void {
        const destination = decodeMovwDestination(opcode);
        const source = decodeMovwSource(opcode);

        self.r[destination] = self.r[source];
        self.r[destination + 1] = self.r[source + 1];

        self.tracePrint("MOVW r{}:r{} r{}:r{}\n", .{ destination + 1, destination, source + 1, source });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execAdd(self: *Cpu, opcode: u16) !void {
        const destination = decodeDestinationRegister(opcode);
        const source = decodeSourceRegister(opcode);
        const result = self.r[destination] +% self.r[source];

        self.setAddFlags(self.r[destination], self.r[source], result);
        self.r[destination] = result;

        self.tracePrint("ADD r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, result });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execAdc(self: *Cpu, opcode: u16) !void {
        const destination = decodeDestinationRegister(opcode);
        const source = decodeSourceRegister(opcode);
        const carry: u8 = if (self.getFlag(constants.Sreg.c)) 1 else 0;
        const right = self.r[source] +% carry;
        const result = self.r[destination] +% right;

        self.setAddFlags(self.r[destination], right, result);
        self.r[destination] = result;

        self.tracePrint("ADC r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, result });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execSub(self: *Cpu, opcode: u16) !void {
        const destination = decodeDestinationRegister(opcode);
        const source = decodeSourceRegister(opcode);
        const result = self.r[destination] -% self.r[source];

        self.setSubtractFlags(self.r[destination], self.r[source], false);
        self.r[destination] = result;

        self.tracePrint("SUB r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, result });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execSbc(self: *Cpu, opcode: u16) !void {
        const destination = decodeDestinationRegister(opcode);
        const source = decodeSourceRegister(opcode);
        const carry: u8 = if (self.getFlag(constants.Sreg.c)) 1 else 0;
        const right = self.r[source] +% carry;
        const result = self.r[destination] -% right;

        self.setSubtractFlags(self.r[destination], right, true);
        self.r[destination] = result;

        self.tracePrint("SBC r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, result });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execOri(self: *Cpu, opcode: u16) !void {
        const register_index = decodeImmediateRegister(opcode);
        const value = decodeImmediate(opcode);
        const result = self.r[register_index] | value;

        self.r[register_index] = result;
        self.setLogicFlags(result);

        self.tracePrint("ORI r{} 0x{x:0>2} ; value=0x{x:0>2}\n", .{ register_index, value, result });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execSubi(self: *Cpu, opcode: u16) !void {
        const register_index = decodeImmediateRegister(opcode);
        const value = decodeImmediate(opcode);
        const result = self.r[register_index] -% value;

        self.setSubtractFlags(self.r[register_index], value, false);
        self.r[register_index] = result;

        self.tracePrint("SUBI r{} 0x{x:0>2} ; value=0x{x:0>2}\n", .{ register_index, value, result });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execSbci(self: *Cpu, opcode: u16) !void {
        const register_index = decodeImmediateRegister(opcode);
        const value = decodeImmediate(opcode);
        const carry: u8 = if (self.getFlag(constants.Sreg.c)) 1 else 0;
        const right = value +% carry;
        const result = self.r[register_index] -% right;

        self.setSubtractFlags(self.r[register_index], right, true);
        self.r[register_index] = result;

        self.tracePrint("SBCI r{} 0x{x:0>2} ; value=0x{x:0>2}\n", .{ register_index, value, result });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execAdiw(self: *Cpu, opcode: u16) !void {
        const register_index = decodeWordImmediateRegister(opcode);
        const value = decodeWordImmediate(opcode);
        const left = self.readRegisterWord(register_index);
        const result = left +% value;

        self.writeRegisterWord(register_index, result);
        self.setAdiwFlags(left, result);

        self.tracePrint("ADIW r{}:r{} {} ; value=0x{x:0>4}\n", .{ register_index + 1, register_index, value, result });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execSbiw(self: *Cpu, opcode: u16) !void {
        const register_index = decodeWordImmediateRegister(opcode);
        const value = decodeWordImmediate(opcode);
        const left = self.readRegisterWord(register_index);
        const result = left -% value;

        self.writeRegisterWord(register_index, result);
        self.setSbiwFlags(left, result);

        self.tracePrint("SBIW r{}:r{} {} ; value=0x{x:0>4}\n", .{ register_index + 1, register_index, value, result });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execAndi(self: *Cpu, opcode: u16) !void {
        const register_index = decodeImmediateRegister(opcode);
        const value = decodeImmediate(opcode);
        const result = self.r[register_index] & value;

        self.r[register_index] = result;
        self.setLogicFlags(result);

        self.tracePrint("ANDI r{} 0x{x:0>2} ; value=0x{x:0>2}\n", .{ register_index, value, result });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execAnd(self: *Cpu, opcode: u16) !void {
        const destination = decodeDestinationRegister(opcode);
        const source = decodeSourceRegister(opcode);
        const result = self.r[destination] & self.r[source];

        self.r[destination] = result;
        self.setLogicFlags(result);

        self.tracePrint("AND r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, result });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execOr(self: *Cpu, opcode: u16) !void {
        const destination = decodeDestinationRegister(opcode);
        const source = decodeSourceRegister(opcode);
        const result = self.r[destination] | self.r[source];

        self.r[destination] = result;
        self.setLogicFlags(result);

        self.tracePrint("OR r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, result });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execEor(self: *Cpu, opcode: u16) !void {
        const destination = decodeDestinationRegister(opcode);
        const source = decodeSourceRegister(opcode);
        const result = self.r[destination] ^ self.r[source];

        self.r[destination] = result;
        self.setLogicFlags(result);

        if (destination == source) {
            self.tracePrint("CLR r{}\n", .{destination});
        } else {
            self.tracePrint("EOR r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, result });
        }

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execInc(self: *Cpu, opcode: u16) !void {
        const register_index = decodeSingleRegister(opcode);
        const result = self.r[register_index] +% 1;

        self.r[register_index] = result;
        self.setFlag(constants.Sreg.z, result == 0);
        self.setFlag(constants.Sreg.n, (result & 0x80) != 0);
        self.setFlag(constants.Sreg.v, result == 0x80);
        self.setFlag(constants.Sreg.s, self.getFlag(constants.Sreg.n) != self.getFlag(constants.Sreg.v));

        self.tracePrint("INC r{} ; value=0x{x:0>2}\n", .{ register_index, result });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execDec(self: *Cpu, opcode: u16) !void {
        const register_index = decodeSingleRegister(opcode);
        const result = self.r[register_index] -% 1;

        self.r[register_index] = result;
        self.setFlag(constants.Sreg.z, result == 0);
        self.setFlag(constants.Sreg.n, (result & 0x80) != 0);
        self.setFlag(constants.Sreg.v, result == 0x7f);
        self.setFlag(constants.Sreg.s, self.getFlag(constants.Sreg.n) != self.getFlag(constants.Sreg.v));

        self.tracePrint("DEC r{} ; value=0x{x:0>2}\n", .{ register_index, result });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execCom(self: *Cpu, opcode: u16) !void {
        const register_index = decodeSingleRegister(opcode);
        const result = ~self.r[register_index];

        self.r[register_index] = result;
        self.setFlag(constants.Sreg.z, result == 0);
        self.setFlag(constants.Sreg.n, (result & 0x80) != 0);
        self.setFlag(constants.Sreg.v, false);
        self.setFlag(constants.Sreg.s, self.getFlag(constants.Sreg.n));
        self.setFlag(constants.Sreg.c, true);

        self.tracePrint("COM r{} ; value=0x{x:0>2}\n", .{ register_index, result });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execCpi(self: *Cpu, opcode: u16) !void {
        const register_index = decodeImmediateRegister(opcode);
        const value = decodeImmediate(opcode);

        self.setSubtractFlags(self.r[register_index], value, false);

        self.tracePrint("CPI r{} 0x{x:0>2}\n", .{ register_index, value });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execCp(self: *Cpu, opcode: u16) !void {
        const destination = decodeDestinationRegister(opcode);
        const source = decodeSourceRegister(opcode);

        self.setSubtractFlags(self.r[destination], self.r[source], false);

        self.tracePrint("CP r{} r{}\n", .{ destination, source });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execCpc(self: *Cpu, opcode: u16) !void {
        const destination = decodeDestinationRegister(opcode);
        const source = decodeSourceRegister(opcode);
        const carry: u8 = if (self.getFlag(constants.Sreg.c)) 1 else 0;

        self.setSubtractFlags(self.r[destination], self.r[source] +% carry, true);

        self.tracePrint("CPC r{} r{}\n", .{ destination, source });

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execCpse(self: *Cpu, opcode: u16) !void {
        const destination = decodeDestinationRegister(opcode);
        const source = decodeSourceRegister(opcode);
        const should_skip = self.r[destination] == self.r[source];

        try self.skipIf(should_skip, "CPSE");
    }

    fn execBranch(self: *Cpu, opcode: u16, take_branch: bool, name: []const u8) !void {
        const offset = decodeRelative7(opcode);

        if (take_branch) {
            const next_pc: i32 = @as(i32, @intCast(self.pc)) + 1 + offset;

            if (next_pc < 0) {
                return error.ProgramCounterOutOfRange;
            }

            self.tracePrint("{s} {d} -> 0x{x:0>4}\n", .{ name, offset, @as(u32, @intCast(next_pc)) });

            self.pc = @as(u32, @intCast(next_pc));
            self.cycles += constants.Cycles.branch_taken;
        } else {
            self.tracePrint("{s} {d} ; not taken\n", .{ name, offset });

            self.pc += 1;
            self.cycles += constants.Cycles.branch_not_taken;
        }
    }

    fn execCall(self: *Cpu, opcode: u16) !void {
        const next_word = try self.fetch16(self.pc + 1);
        const target = decodeAbsolute22(opcode, next_word);
        const return_address = self.pc + 2;

        try self.pushReturnAddress(return_address);

        self.tracePrint("CALL 0x{x:0>4}\n", .{target});

        self.pc = target;
        self.cycles += constants.Cycles.call;
    }

    fn execRet(self: *Cpu) !void {
        const target = try self.popReturnAddress();

        self.tracePrint("RET -> 0x{x:0>4}\n", .{target});

        self.pc = target;
        self.cycles += constants.Cycles.ret;
    }

    fn execReti(self: *Cpu) !void {
        const target = try self.popReturnAddress();

        self.setFlag(constants.Sreg.i, true);
        self.tracePrint("RETI -> 0x{x:0>4}\n", .{target});

        self.pc = target;
        self.cycles += constants.Cycles.ret;
    }

    fn execSetInterruptFlag(self: *Cpu, enabled: bool, comptime name: []const u8) !void {
        self.setFlag(constants.Sreg.i, enabled);
        self.tracePrint("{s}\n", .{name});

        self.pc += 1;
        self.cycles += constants.Cycles.register;
    }

    fn execPush(self: *Cpu, opcode: u16) !void {
        const register_index = decodeSingleRegister(opcode);
        const value = self.r[register_index];

        try self.pushByte(value);

        self.tracePrint("PUSH r{} ; value=0x{x:0>2}\n", .{ register_index, value });

        self.pc += 1;
        self.cycles += constants.Cycles.push;
    }

    fn execPop(self: *Cpu, opcode: u16) !void {
        const register_index = decodeSingleRegister(opcode);
        const value = try self.popByte();

        self.r[register_index] = value;

        self.tracePrint("POP r{} ; value=0x{x:0>2}\n", .{ register_index, value });

        self.pc += 1;
        self.cycles += constants.Cycles.pop;
    }

    fn execLds(self: *Cpu, opcode: u16) !void {
        const register_index = decodeSingleRegister(opcode);
        const address = try self.fetch16(self.pc + 1);
        const value = try self.readData(address);

        self.r[register_index] = value;
        self.tracePrint("LDS r{} 0x{x:0>4} ; value=0x{x:0>2}\n", .{ register_index, address, value });

        self.pc += 2;
        self.cycles += constants.Cycles.lds;
    }

    fn execSts(self: *Cpu, opcode: u16) !void {
        const register_index = decodeSingleRegister(opcode);
        const address = try self.fetch16(self.pc + 1);
        const value = self.r[register_index];

        try self.writeData(address, value);
        self.tracePrint("STS 0x{x:0>4} r{} ; value=0x{x:0>2}\n", .{ address, register_index, value });

        self.pc += 2;
        self.cycles += constants.Cycles.sts;
    }

    fn execLdPointer(self: *Cpu, opcode: u16, pointer_register: usize, mode: PointerMode, comptime name: []const u8) !void {
        const register_index = decodeSingleRegister(opcode);
        var address = self.readRegisterWord(pointer_register);

        if (mode == .predecrement) {
            address -%= 1;
            self.writeRegisterWord(pointer_register, address);
        }

        const displacement = if (pointer_register == 26) 0 else decodeDisplacement(opcode);
        const value = try self.readData(address +% displacement);

        self.r[register_index] = value;

        if (mode == .postincrement) {
            self.writeRegisterWord(pointer_register, address +% 1);
        }

        self.tracePrint("{s} r{} ; value=0x{x:0>2}\n", .{ name, register_index, value });

        self.pc += 1;
        self.cycles += constants.Cycles.ld;
    }

    fn execStPointer(self: *Cpu, opcode: u16, pointer_register: usize, mode: PointerMode, comptime name: []const u8) !void {
        const register_index = decodeSingleRegister(opcode);
        var address = self.readRegisterWord(pointer_register);
        const value = self.r[register_index];

        if (mode == .predecrement) {
            address -%= 1;
            self.writeRegisterWord(pointer_register, address);
        }

        const displacement = if (pointer_register == 26) 0 else decodeDisplacement(opcode);
        try self.writeData(address +% displacement, value);

        if (mode == .postincrement) {
            self.writeRegisterWord(pointer_register, address +% 1);
        }

        self.tracePrint("{s} r{} ; value=0x{x:0>2}\n", .{ name, register_index, value });

        self.pc += 1;
        self.cycles += constants.Cycles.st;
    }

    fn execLpmImplicit(self: *Cpu) !void {
        const address = self.readRegisterWord(30);
        const value = try self.flash.readByte(address);

        self.r[0] = value;
        self.tracePrint("LPM ; value=0x{x:0>2}\n", .{value});

        self.pc += 1;
        self.cycles += constants.Cycles.lpm;
    }

    fn execLpm(self: *Cpu, opcode: u16) !void {
        const register_index = decodeSingleRegister(opcode);
        const address = self.readRegisterWord(30);
        const value = try self.flash.readByte(address);

        self.r[register_index] = value;

        if ((opcode & 0x0001) != 0) {
            self.writeRegisterWord(30, address +% 1);
        }

        self.tracePrint("LPM r{} Z ; value=0x{x:0>2}\n", .{ register_index, value });

        self.pc += 1;
        self.cycles += constants.Cycles.lpm;
    }

    pub fn writeIo(self: *Cpu, address: usize, value: u8) !void {
        if (address >= self.io.len) {
            return error.IoAddressOutOfRange;
        }

        if (address == constants.Io.sreg) {
            self.sreg = value;
            self.io[address] = value;
            return;
        }

        if (self.timer0.writeIo(address, value) != null) {
            return;
        }

        const old = self.io[address];
        self.io[address] = value;

        self.handlePinSideEffects(address, old, value);
    }

    fn tracePrint(self: *const Cpu, comptime format: []const u8, args: anytype) void {
        if (self.trace and !self.quiet) {
            std.debug.print(format, args);
        }
    }

    fn pinPrint(self: *const Cpu, comptime format: []const u8, args: anytype) void {
        if (!self.quiet) {
            std.debug.print(format, args);
        }
    }

    pub fn readIo(self: *Cpu, address: usize) !u8 {
        if (address >= self.io.len) {
            return error.IoAddressOutOfRange;
        }

        if (address == constants.Io.sreg) {
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

        if (self.timer0.writeData(address, value)) |_| {
            return;
        }

        if (address >= self.sram.len) {
            return error.DataAddressOutOfRange;
        }

        self.sram[address] = value;
    }

    fn pushByte(self: *Cpu, value: u8) !void {
        if (self.sp >= self.sram.len) {
            return error.StackPointerOutOfRange;
        }

        self.sram[self.sp] = value;

        if (self.sp == 0) {
            return error.StackPointerOutOfRange;
        }

        self.sp -= 1;
    }

    fn popByte(self: *Cpu) !u8 {
        if (self.sp == constants.Sram.end) {
            return error.StackPointerOutOfRange;
        }

        self.sp += 1;

        if (self.sp >= self.sram.len) {
            return error.StackPointerOutOfRange;
        }

        return self.sram[self.sp];
    }

    fn pushReturnAddress(self: *Cpu, address: u32) !void {
        try self.pushByte(@as(u8, @intCast((address >> 8) & 0xff)));
        try self.pushByte(@as(u8, @intCast(address & 0xff)));
    }

    fn popReturnAddress(self: *Cpu) !u32 {
        const low = try self.popByte();
        const high = try self.popByte();

        return @as(u32, low) | (@as(u32, high) << 8);
    }

    fn setLogicFlags(self: *Cpu, result: u8) void {
        self.setFlag(constants.Sreg.z, result == 0);
        self.setFlag(constants.Sreg.n, (result & 0x80) != 0);
        self.setFlag(constants.Sreg.v, false);
        self.setFlag(constants.Sreg.s, self.getFlag(constants.Sreg.n));
    }

    fn setAddFlags(self: *Cpu, left: u8, right: u8, result: u8) void {
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

    fn setSubtractFlags(self: *Cpu, left: u8, right: u8, preserve_zero: bool) void {
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

    fn setAdiwFlags(self: *Cpu, left: u16, result: u16) void {
        const r15 = (result & 0x8000) != 0;
        const left15 = (left & 0x8000) != 0;

        self.setFlag(constants.Sreg.z, result == 0);
        self.setFlag(constants.Sreg.n, r15);
        self.setFlag(constants.Sreg.v, !left15 and r15);
        self.setFlag(constants.Sreg.s, self.getFlag(constants.Sreg.n) != self.getFlag(constants.Sreg.v));
        self.setFlag(constants.Sreg.c, !r15 and left15);
    }

    fn setSbiwFlags(self: *Cpu, left: u16, result: u16) void {
        const r15 = (result & 0x8000) != 0;
        const left15 = (left & 0x8000) != 0;

        self.setFlag(constants.Sreg.z, result == 0);
        self.setFlag(constants.Sreg.n, r15);
        self.setFlag(constants.Sreg.v, left15 and !r15);
        self.setFlag(constants.Sreg.s, self.getFlag(constants.Sreg.n) != self.getFlag(constants.Sreg.v));
        self.setFlag(constants.Sreg.c, r15 and !left15);
    }

    fn skipIf(self: *Cpu, should_skip: bool, comptime name: []const u8) !void {
        if (!should_skip) {
            self.tracePrint("{s} ; not skipped\n", .{name});
            self.pc += 1;
            self.cycles += constants.Cycles.skip_not_taken;
            return;
        }

        const next_opcode = try self.fetch16(self.pc + 1);
        const skipped_words: u32 = if (isTwoWordInstruction(next_opcode)) 2 else 1;

        self.tracePrint("{s} ; skipped {} word(s)\n", .{ name, skipped_words });

        self.pc += 1 + skipped_words;
        self.cycles += if (skipped_words == 2) constants.Cycles.skip_two_word else constants.Cycles.skip_one_word;
    }

    pub fn isTwoWordInstruction(opcode: u16) bool {
        return ((opcode & constants.Opcode.call_mask) == constants.Opcode.call_pattern) or
            ((opcode & constants.Opcode.jmp_mask) == constants.Opcode.jmp_pattern) or
            ((opcode & constants.Opcode.lds_mask) == constants.Opcode.lds_pattern) or
            ((opcode & constants.Opcode.sts_mask) == constants.Opcode.sts_pattern);
    }

    pub fn readRegisterWord(self: *const Cpu, register_index: usize) u16 {
        return @as(u16, self.r[register_index]) | (@as(u16, self.r[register_index + 1]) << 8);
    }

    pub fn writeRegisterWord(self: *Cpu, register_index: usize, value: u16) void {
        self.r[register_index] = @as(u8, @intCast(value & 0x00ff));
        self.r[register_index + 1] = @as(u8, @intCast(value >> 8));
    }

    pub fn getFlag(self: *const Cpu, flag: u3) bool {
        return (self.sreg & bitMask(flag)) != 0;
    }

    pub fn setFlag(self: *Cpu, flag: u3, value: bool) void {
        if (value) {
            self.sreg |= bitMask(flag);
        } else {
            self.sreg &= ~bitMask(flag);
        }
    }

    fn bitMask(bit: u3) u8 {
        return @as(u8, 1) << bit;
    }

    fn decodeAbsolute22(opcode: u16, next_word: u16) u32 {
        const high_bits =
            (@as(u32, opcode & constants.Jmp.high_bits_mask) << constants.Jmp.high_bits_shift) |
            (@as(u32, opcode & constants.Jmp.low_high_bit_mask) << constants.Jmp.low_high_bit_shift);

        return high_bits | @as(u32, next_word);
    }

    fn decodeRelative12(opcode: u16) i32 {
        const raw: i32 = @as(i32, @intCast(opcode & constants.Rjmp.offset_mask));

        return if ((opcode & constants.Rjmp.sign_bit) != 0)
            raw - constants.Rjmp.sign_extend_subtract
        else
            raw;
    }

    fn decodeRelative7(opcode: u16) i32 {
        const raw: i32 = @as(i32, @intCast(
            (opcode & constants.Branch.offset_mask) >> constants.Branch.offset_shift,
        ));

        return if ((raw & constants.Branch.sign_bit) != 0)
            raw - constants.Branch.sign_extend_subtract
        else
            raw;
    }

    fn decodeImmediateRegister(opcode: u16) usize {
        return constants.Immediate.register_base + @as(usize, @intCast(
            (opcode & constants.Immediate.register_mask) >> constants.Immediate.register_shift,
        ));
    }

    fn decodeImmediate(opcode: u16) u8 {
        const imm_low = opcode & constants.Immediate.imm_low_mask;
        const imm_high = (opcode & constants.Immediate.imm_high_mask) >> constants.Immediate.imm_high_shift;

        return @as(u8, @intCast(imm_high | imm_low));
    }

    fn decodeIoAddress(opcode: u16) usize {
        return @as(usize, @intCast(opcode & constants.Out.io_low_mask)) | @as(usize, @intCast(
            (opcode & constants.Out.io_high_mask) >> constants.Out.io_high_shift,
        ));
    }

    fn decodeIoRegister(opcode: u16) usize {
        return @as(usize, @intCast(
            (opcode & constants.Out.register_mask) >> constants.Out.register_shift,
        ));
    }

    fn decodeBitIoAddress(opcode: u16) usize {
        return @as(usize, @intCast((opcode & constants.BitIo.io_mask) >> constants.BitIo.io_shift));
    }

    fn decodeBitIoBit(opcode: u16) u3 {
        return @as(u3, @intCast(opcode & constants.BitIo.bit_mask));
    }

    fn decodeDestinationRegister(opcode: u16) usize {
        return @as(usize, @intCast(
            (opcode & constants.RegisterPair.destination_mask) >> constants.RegisterPair.destination_shift,
        ));
    }

    fn decodeSourceRegister(opcode: u16) usize {
        return @as(usize, @intCast(opcode & constants.RegisterPair.source_low_mask)) | @as(usize, @intCast(
            (opcode & constants.RegisterPair.source_high_mask) >> constants.RegisterPair.source_high_shift,
        ));
    }

    fn decodeSingleRegister(opcode: u16) usize {
        return @as(usize, @intCast(
            (opcode & constants.SingleRegister.register_mask) >> constants.SingleRegister.register_shift,
        ));
    }

    fn decodeWordImmediateRegister(opcode: u16) usize {
        return constants.WordImmediate.register_base + @as(usize, @intCast(
            (opcode & constants.WordImmediate.register_mask) >> constants.WordImmediate.register_shift,
        ));
    }

    fn decodeWordImmediate(opcode: u16) u16 {
        const imm_low = opcode & constants.WordImmediate.imm_low_mask;
        const imm_high = (opcode & constants.WordImmediate.imm_high_mask) >> constants.WordImmediate.imm_high_shift;

        return @as(u16, @intCast(imm_high | imm_low));
    }

    fn decodeMovwDestination(opcode: u16) usize {
        return @as(usize, @intCast(
            (opcode & constants.RegisterPairMove.destination_mask) >> constants.RegisterPairMove.destination_shift,
        ));
    }

    fn decodeMovwSource(opcode: u16) usize {
        return @as(usize, @intCast(
            (opcode & constants.RegisterPairMove.source_mask) << constants.RegisterPairMove.source_shift,
        ));
    }

    fn decodeDisplacement(opcode: u16) u16 {
        const q0_2 = opcode & 0x0007;
        const q3_4 = (opcode & 0x0c00) >> 7;
        const q5 = (opcode & 0x2000) >> 8;

        return @as(u16, @intCast(q0_2 | q3_4 | q5));
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
            try self.fireInterrupt(constants.InterruptVector.timer0_ovf_word);
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

    fn handlePinSideEffects(
        self: *Cpu,
        address: usize,
        old: u8,
        new: u8,
    ) void {
        if (old == new) return;

        switch (address) {
            constants.Io.ddrb => {
                const old_output = (old & constants.Io.pb5_mask) != 0;
                const new_output = (new & constants.Io.pb5_mask) != 0;

                if (old_output != new_output) {
                    self.pinPrint("[pin] D13 mode = {s}\n", .{
                        if (new_output) "OUTPUT" else "INPUT",
                    });
                }
            },

            constants.Io.portb => {
                const ddrb = self.io[constants.Io.ddrb];
                const d13_is_output = (ddrb & constants.Io.pb5_mask) != 0;

                if (!d13_is_output) return;

                const old_high = (old & constants.Io.pb5_mask) != 0;
                const new_high = (new & constants.Io.pb5_mask) != 0;

                if (old_high != new_high) {
                    self.pinPrint("[pin] D13 = {s}\n", .{
                        if (new_high) "HIGH" else "LOW",
                    });
                }
            },

            else => {},
        }
    }
};

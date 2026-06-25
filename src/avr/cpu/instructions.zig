const Cpu = @import("cpu.zig").Cpu;
const constants = @import("../constants/constants.zig");
const decode = @import("decode.zig");

pub const PointerMode = enum {
    none,
    postincrement,
    predecrement,
};

pub fn execNop(cpu: *Cpu, _: u16) !void {
    cpu.tracePrint("NOP\n", .{});
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.nop;
}

pub fn execRet(cpu: *Cpu, _: u16) !void {
    const target = try cpu.popReturnAddress();
    cpu.tracePrint("RET -> 0x{x:0>4}\n", .{target});
    cpu.pc = target;
    cpu.cycles += constants.Cycles.ret;
}

pub fn execReti(cpu: *Cpu, _: u16) !void {
    const target = try cpu.popReturnAddress();
    cpu.setFlag(constants.Sreg.i, true);
    cpu.tracePrint("RETI -> 0x{x:0>4}\n", .{target});
    cpu.pc = target;
    cpu.cycles += constants.Cycles.ret;
}

pub fn execCli(cpu: *Cpu, _: u16) !void {
    try execSetInterruptFlag(cpu, false, "CLI");
}

pub fn execSei(cpu: *Cpu, _: u16) !void {
    try execSetInterruptFlag(cpu, true, "SEI");
}

pub fn execLpmImplicit(cpu: *Cpu, _: u16) !void {
    const address = cpu.readRegisterWord(30);
    const value = try cpu.flash.readByte(address);
    cpu.r[0] = value;
    cpu.tracePrint("LPM ; value=0x{x:0>2}\n", .{value});
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.lpm;
}

pub fn execBrne(cpu: *Cpu, opcode: u16) !void {
    try execBranch(cpu, opcode, !cpu.getFlag(constants.Sreg.z), "BRNE");
}

pub fn execBreq(cpu: *Cpu, opcode: u16) !void {
    try execBranch(cpu, opcode, cpu.getFlag(constants.Sreg.z), "BREQ");
}

pub fn execBrcc(cpu: *Cpu, opcode: u16) !void {
    try execBranch(cpu, opcode, !cpu.getFlag(constants.Sreg.c), "BRCC");
}

pub fn execBrcs(cpu: *Cpu, opcode: u16) !void {
    try execBranch(cpu, opcode, cpu.getFlag(constants.Sreg.c), "BRCS");
}

pub fn execLdX(cpu: *Cpu, opcode: u16) !void {
    try execLdPointer(cpu, opcode, 26, .none, "LD X");
}

pub fn execLdXPlus(cpu: *Cpu, opcode: u16) !void {
    try execLdPointer(cpu, opcode, 26, .postincrement, "LD X+");
}

pub fn execLdMinusX(cpu: *Cpu, opcode: u16) !void {
    try execLdPointer(cpu, opcode, 26, .predecrement, "LD -X");
}

pub fn execStX(cpu: *Cpu, opcode: u16) !void {
    try execStPointer(cpu, opcode, 26, .none, "ST X");
}

pub fn execStXPlus(cpu: *Cpu, opcode: u16) !void {
    try execStPointer(cpu, opcode, 26, .postincrement, "ST X+");
}

pub fn execStMinusX(cpu: *Cpu, opcode: u16) !void {
    try execStPointer(cpu, opcode, 26, .predecrement, "ST -X");
}

pub fn execLdZ(cpu: *Cpu, opcode: u16) !void {
    try execLdPointer(cpu, opcode, 30, .none, "LD Z");
}

pub fn execLdY(cpu: *Cpu, opcode: u16) !void {
    try execLdPointer(cpu, opcode, 28, .none, "LD Y");
}

pub fn execStZ(cpu: *Cpu, opcode: u16) !void {
    try execStPointer(cpu, opcode, 30, .none, "ST Z");
}

pub fn execStY(cpu: *Cpu, opcode: u16) !void {
    try execStPointer(cpu, opcode, 28, .none, "ST Y");
}

pub fn execJmp(cpu: *Cpu, opcode: u16) !void {
    const next_word = try cpu.fetch16(cpu.pc + 1);
    const high_bits =
        (@as(u32, opcode & constants.Jmp.high_bits_mask) << constants.Jmp.high_bits_shift) |
        (@as(u32, opcode & constants.Jmp.low_high_bit_mask) << constants.Jmp.low_high_bit_shift);
    const target = high_bits | @as(u32, next_word);
    cpu.tracePrint("JMP 0x{x:0>4}\n", .{target});
    cpu.pc = target;
    cpu.cycles += constants.Cycles.jmp;
}

pub fn execRjmp(cpu: *Cpu, opcode: u16) !void {
    const offset = decode.decodeRelative12(opcode);
    const next_pc: i32 = @as(i32, @intCast(cpu.pc)) + 1 + offset;
    if (next_pc < 0) {
        return error.ProgramCounterOutOfRange;
    }
    cpu.tracePrint("RJMP {d} -> 0x{x:0>4}\n", .{
        offset,
        @as(u32, @intCast(next_pc)),
    });
    cpu.pc = @as(u32, @intCast(next_pc));
    cpu.cycles += constants.Cycles.rjmp;
}

pub fn execRcall(cpu: *Cpu, opcode: u16) !void {
    const offset = decode.decodeRelative12(opcode);
    const return_address = cpu.pc + 1;
    const next_pc: i32 = @as(i32, @intCast(return_address)) + offset;
    if (next_pc < 0) {
        return error.ProgramCounterOutOfRange;
    }
    try cpu.pushReturnAddress(return_address);
    cpu.tracePrint("RCALL {d} -> 0x{x:0>4}\n", .{
        offset,
        @as(u32, @intCast(next_pc)),
    });
    cpu.pc = @as(u32, @intCast(next_pc));
    cpu.cycles += constants.Cycles.rcall;
}

pub fn execLdi(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeImmediateRegister(opcode);
    const value = decode.decodeImmediate(opcode);
    cpu.r[register_index] = value;
    cpu.tracePrint("LDI r{} 0x{x:0>2}\n", .{ register_index, value });
    cpu.pc += 1;
    cpu.cycles += constants.Ldi.cycles;
}

pub fn execIn(cpu: *Cpu, opcode: u16) !void {
    const io_address = decode.decodeIoAddress(opcode);
    const register_index = decode.decodeIoRegister(opcode);
    const value = try cpu.readIo(io_address);
    cpu.r[register_index] = value;
    cpu.tracePrint("IN r{} io[0x{x:0>2}] ; value=0x{x:0>2}\n", .{ register_index, io_address, value });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.in;
}

pub fn execOut(cpu: *Cpu, opcode: u16) !void {
    const io_address = decode.decodeIoAddress(opcode);
    const register_index = decode.decodeIoRegister(opcode);
    const value = cpu.r[register_index];
    try cpu.writeIo(io_address, value);
    cpu.tracePrint("OUT io[0x{x:0>2}] r{} ; value=0x{x:0>2}\n", .{ io_address, register_index, value });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.out;
}

pub fn execSbi(cpu: *Cpu, opcode: u16) !void {
    const io_address = decode.decodeBitIoAddress(opcode);
    const bit = decode.decodeBitIoBit(opcode);
    const value = (try cpu.readIo(io_address)) | decode.bitMask(bit);
    try cpu.writeIo(io_address, value);
    cpu.tracePrint("SBI io[0x{x:0>2}] {}\n", .{ io_address, bit });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.sbi;
}

pub fn execCbi(cpu: *Cpu, opcode: u16) !void {
    const io_address = decode.decodeBitIoAddress(opcode);
    const bit = decode.decodeBitIoBit(opcode);
    const value = (try cpu.readIo(io_address)) & ~decode.bitMask(bit);
    try cpu.writeIo(io_address, value);
    cpu.tracePrint("CBI io[0x{x:0>2}] {}\n", .{ io_address, bit });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.cbi;
}

pub fn execSbis(cpu: *Cpu, opcode: u16) !void {
    const io_address = decode.decodeBitIoAddress(opcode);
    const bit = decode.decodeBitIoBit(opcode);
    const should_skip = ((try cpu.readIo(io_address)) & decode.bitMask(bit)) != 0;
    try cpu.skipIf(should_skip, "SBIS");
}

pub fn execMov(cpu: *Cpu, opcode: u16) !void {
    const destination = decode.decodeDestinationRegister(opcode);
    const source = decode.decodeSourceRegister(opcode);
    cpu.r[destination] = cpu.r[source];
    cpu.tracePrint("MOV r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, cpu.r[destination] });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execMovw(cpu: *Cpu, opcode: u16) !void {
    const destination = decode.decodeMovwDestination(opcode);
    const source = decode.decodeMovwSource(opcode);
    cpu.r[destination] = cpu.r[source];
    cpu.r[destination + 1] = cpu.r[source + 1];
    cpu.tracePrint("MOVW r{}:r{} r{}:r{}\n", .{ destination + 1, destination, source + 1, source });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execAdd(cpu: *Cpu, opcode: u16) !void {
    const destination = decode.decodeDestinationRegister(opcode);
    const source = decode.decodeSourceRegister(opcode);
    const result = cpu.r[destination] +% cpu.r[source];
    cpu.setAddFlags(cpu.r[destination], cpu.r[source], result);
    cpu.r[destination] = result;
    cpu.tracePrint("ADD r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execAdc(cpu: *Cpu, opcode: u16) !void {
    const destination = decode.decodeDestinationRegister(opcode);
    const source = decode.decodeSourceRegister(opcode);

    const left = cpu.r[destination];
    const right = cpu.r[source];
    const carry: u8 = if (cpu.getFlag(constants.Sreg.c)) 1 else 0;

    const result = left +% right +% carry;

    cpu.setAddFlags(left, right, result);
    cpu.r[destination] = result;

    cpu.tracePrint("ADC r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execSub(cpu: *Cpu, opcode: u16) !void {
    const destination = decode.decodeDestinationRegister(opcode);
    const source = decode.decodeSourceRegister(opcode);
    const result = cpu.r[destination] -% cpu.r[source];
    cpu.setSubtractFlags(cpu.r[destination], cpu.r[source], false);
    cpu.r[destination] = result;
    cpu.tracePrint("SUB r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execSbc(cpu: *Cpu, opcode: u16) !void {
    const destination = decode.decodeDestinationRegister(opcode);
    const source = decode.decodeSourceRegister(opcode);

    const left = cpu.r[destination];
    const right = cpu.r[source];
    const carry: u8 = if (cpu.getFlag(constants.Sreg.c)) 1 else 0;

    const result = left -% right -% carry;

    cpu.setSubtractResultFlags(left, right, result, true);
    cpu.r[destination] = result;

    cpu.tracePrint("SBC r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}
pub fn execOri(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeImmediateRegister(opcode);
    const value = decode.decodeImmediate(opcode);
    const result = cpu.r[register_index] | value;
    cpu.r[register_index] = result;
    cpu.setLogicFlags(result);
    cpu.tracePrint("ORI r{} 0x{x:0>2} ; value=0x{x:0>2}\n", .{ register_index, value, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execSubi(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeImmediateRegister(opcode);
    const value = decode.decodeImmediate(opcode);
    const result = cpu.r[register_index] -% value;
    cpu.setSubtractFlags(cpu.r[register_index], value, false);
    cpu.r[register_index] = result;
    cpu.tracePrint("SUBI r{} 0x{x:0>2} ; value=0x{x:0>2}\n", .{ register_index, value, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execSbci(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeImmediateRegister(opcode);

    const left = cpu.r[register_index];
    const right = decode.decodeImmediate(opcode);
    const carry: u8 = if (cpu.getFlag(constants.Sreg.c)) 1 else 0;

    const result = left -% right -% carry;

    cpu.setSubtractResultFlags(left, right, result, true);
    cpu.r[register_index] = result;

    cpu.tracePrint("SBCI r{} 0x{x:0>2} ; value=0x{x:0>2}\n", .{ register_index, right, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execAdiw(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeWordImmediateRegister(opcode);
    const value = decode.decodeWordImmediate(opcode);
    const left = cpu.readRegisterWord(register_index);
    const result = left +% value;
    cpu.writeRegisterWord(register_index, result);
    cpu.setAdiwFlags(left, result);
    cpu.tracePrint("ADIW r{}:r{} {} ; value=0x{x:0>4}\n", .{ register_index + 1, register_index, value, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execSbiw(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeWordImmediateRegister(opcode);
    const value = decode.decodeWordImmediate(opcode);
    const left = cpu.readRegisterWord(register_index);
    const result = left -% value;
    cpu.writeRegisterWord(register_index, result);
    cpu.setSbiwFlags(left, result);
    cpu.tracePrint("SBIW r{}:r{} {} ; value=0x{x:0>4}\n", .{ register_index + 1, register_index, value, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execAndi(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeImmediateRegister(opcode);
    const value = decode.decodeImmediate(opcode);
    const result = cpu.r[register_index] & value;
    cpu.r[register_index] = result;
    cpu.setLogicFlags(result);
    cpu.tracePrint("ANDI r{} 0x{x:0>2} ; value=0x{x:0>2}\n", .{ register_index, value, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execAnd(cpu: *Cpu, opcode: u16) !void {
    const destination = decode.decodeDestinationRegister(opcode);
    const source = decode.decodeSourceRegister(opcode);
    const result = cpu.r[destination] & cpu.r[source];
    cpu.r[destination] = result;
    cpu.setLogicFlags(result);
    cpu.tracePrint("AND r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execOr(cpu: *Cpu, opcode: u16) !void {
    const destination = decode.decodeDestinationRegister(opcode);
    const source = decode.decodeSourceRegister(opcode);
    const result = cpu.r[destination] | cpu.r[source];
    cpu.r[destination] = result;
    cpu.setLogicFlags(result);
    cpu.tracePrint("OR r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execEor(cpu: *Cpu, opcode: u16) !void {
    const destination = decode.decodeDestinationRegister(opcode);
    const source = decode.decodeSourceRegister(opcode);
    const result = cpu.r[destination] ^ cpu.r[source];
    cpu.r[destination] = result;
    cpu.setLogicFlags(result);
    if (destination == source) {
        cpu.tracePrint("CLR r{}\n", .{destination});
    } else {
        cpu.tracePrint("EOR r{} r{} ; value=0x{x:0>2}\n", .{ destination, source, result });
    }
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execInc(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const result = cpu.r[register_index] +% 1;
    cpu.r[register_index] = result;
    cpu.setFlag(constants.Sreg.z, result == 0);
    cpu.setFlag(constants.Sreg.n, (result & 0x80) != 0);
    cpu.setFlag(constants.Sreg.v, result == 0x80);
    cpu.setFlag(constants.Sreg.s, cpu.getFlag(constants.Sreg.n) != cpu.getFlag(constants.Sreg.v));
    cpu.tracePrint("INC r{} ; value=0x{x:0>2}\n", .{ register_index, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execDec(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const result = cpu.r[register_index] -% 1;
    cpu.r[register_index] = result;
    cpu.setFlag(constants.Sreg.z, result == 0);
    cpu.setFlag(constants.Sreg.n, (result & 0x80) != 0);
    cpu.setFlag(constants.Sreg.v, result == 0x7f);
    cpu.setFlag(constants.Sreg.s, cpu.getFlag(constants.Sreg.n) != cpu.getFlag(constants.Sreg.v));
    cpu.tracePrint("DEC r{} ; value=0x{x:0>2}\n", .{ register_index, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execCom(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const result = ~cpu.r[register_index];
    cpu.r[register_index] = result;
    cpu.setFlag(constants.Sreg.z, result == 0);
    cpu.setFlag(constants.Sreg.n, (result & 0x80) != 0);
    cpu.setFlag(constants.Sreg.v, false);
    cpu.setFlag(constants.Sreg.s, cpu.getFlag(constants.Sreg.n));
    cpu.setFlag(constants.Sreg.c, true);
    cpu.tracePrint("COM r{} ; value=0x{x:0>2}\n", .{ register_index, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execCpi(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeImmediateRegister(opcode);
    const value = decode.decodeImmediate(opcode);
    cpu.setSubtractFlags(cpu.r[register_index], value, false);
    cpu.tracePrint("CPI r{} 0x{x:0>2}\n", .{ register_index, value });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execCp(cpu: *Cpu, opcode: u16) !void {
    const destination = decode.decodeDestinationRegister(opcode);
    const source = decode.decodeSourceRegister(opcode);
    cpu.setSubtractFlags(cpu.r[destination], cpu.r[source], false);
    cpu.tracePrint("CP r{} r{}\n", .{ destination, source });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execCpc(cpu: *Cpu, opcode: u16) !void {
    const destination = decode.decodeDestinationRegister(opcode);
    const source = decode.decodeSourceRegister(opcode);

    const left = cpu.r[destination];
    const right = cpu.r[source];
    const carry: u8 = if (cpu.getFlag(constants.Sreg.c)) 1 else 0;

    const result = left -% right -% carry;

    cpu.setSubtractResultFlags(left, right, result, true);

    cpu.tracePrint("CPC r{} r{}\n", .{ destination, source });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execCpse(cpu: *Cpu, opcode: u16) !void {
    const destination = decode.decodeDestinationRegister(opcode);
    const source = decode.decodeSourceRegister(opcode);
    const should_skip = cpu.r[destination] == cpu.r[source];
    try cpu.skipIf(should_skip, "CPSE");
}

pub fn execCall(cpu: *Cpu, opcode: u16) !void {
    const next_word = try cpu.fetch16(cpu.pc + 1);
    const target = decode.decodeAbsolute22(opcode, next_word);
    const return_address = cpu.pc + 2;
    try cpu.pushReturnAddress(return_address);
    cpu.tracePrint("CALL 0x{x:0>4}\n", .{target});
    cpu.pc = target;
    cpu.cycles += constants.Cycles.call;
}

pub fn execPush(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const value = cpu.r[register_index];
    try cpu.pushByte(value);
    cpu.tracePrint("PUSH r{} ; value=0x{x:0>2}\n", .{ register_index, value });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.push;
}

pub fn execPop(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const value = try cpu.popByte();
    cpu.r[register_index] = value;
    cpu.tracePrint("POP r{} ; value=0x{x:0>2}\n", .{ register_index, value });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.pop;
}

pub fn execLds(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const address = try cpu.fetch16(cpu.pc + 1);
    const value = try cpu.readData(address);
    cpu.r[register_index] = value;
    cpu.tracePrint("LDS r{} 0x{x:0>4} ; value=0x{x:0>2}\n", .{ register_index, address, value });
    cpu.pc += 2;
    cpu.cycles += constants.Cycles.lds;
}

pub fn execSts(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const address = try cpu.fetch16(cpu.pc + 1);
    const value = cpu.r[register_index];
    try cpu.writeData(address, value);
    cpu.tracePrint("STS 0x{x:0>4} r{} ; value=0x{x:0>2}\n", .{ address, register_index, value });
    cpu.pc += 2;
    cpu.cycles += constants.Cycles.sts;
}

pub fn execLpm(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const address = cpu.readRegisterWord(30);
    const value = try cpu.flash.readByte(address);
    cpu.r[register_index] = value;
    if ((opcode & 0x0001) != 0) {
        cpu.writeRegisterWord(30, address +% 1);
    }
    cpu.tracePrint("LPM r{} Z ; value=0x{x:0>2}\n", .{ register_index, value });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.lpm;
}

pub fn execBranch(cpu: *Cpu, opcode: u16, take_branch: bool, name: []const u8) !void {
    const offset = decode.decodeRelative7(opcode);
    if (take_branch) {
        const next_pc: i32 = @as(i32, @intCast(cpu.pc)) + 1 + offset;
        if (next_pc < 0) {
            return error.ProgramCounterOutOfRange;
        }
        cpu.tracePrint("{s} {d} -> 0x{x:0>4}\n", .{ name, offset, @as(u32, @intCast(next_pc)) });
        cpu.pc = @as(u32, @intCast(next_pc));
        cpu.cycles += constants.Cycles.branch_taken;
    } else {
        cpu.tracePrint("{s} {d} ; not taken\n", .{ name, offset });
        cpu.pc += 1;
        cpu.cycles += constants.Cycles.branch_not_taken;
    }
}

pub fn execLdPointer(cpu: *Cpu, opcode: u16, pointer_register: usize, mode: PointerMode, comptime name: []const u8) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    var address = cpu.readRegisterWord(pointer_register);
    if (mode == .predecrement) {
        address -%= 1;
        cpu.writeRegisterWord(pointer_register, address);
    }
    const displacement = if (pointer_register == 26) 0 else decode.decodeDisplacement(opcode);
    const value = try cpu.readData(address +% displacement);
    cpu.r[register_index] = value;
    if (mode == .postincrement) {
        cpu.writeRegisterWord(pointer_register, address +% 1);
    }
    cpu.tracePrint("{s} r{} ; value=0x{x:0>2}\n", .{ name, register_index, value });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.ld;
}

pub fn execStPointer(cpu: *Cpu, opcode: u16, pointer_register: usize, mode: PointerMode, comptime name: []const u8) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    var address = cpu.readRegisterWord(pointer_register);
    const value = cpu.r[register_index];
    if (mode == .predecrement) {
        address -%= 1;
        cpu.writeRegisterWord(pointer_register, address);
    }
    const displacement = if (pointer_register == 26) 0 else decode.decodeDisplacement(opcode);
    try cpu.writeData(address +% displacement, value);
    if (mode == .postincrement) {
        cpu.writeRegisterWord(pointer_register, address +% 1);
    }
    cpu.tracePrint("{s} r{} ; value=0x{x:0>2}\n", .{ name, register_index, value });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.st;
}

pub fn execSetInterruptFlag(cpu: *Cpu, enabled: bool, comptime name: []const u8) !void {
    cpu.setFlag(constants.Sreg.i, enabled);
    cpu.tracePrint("{s}\n", .{name});
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

// ─── Branch variants ────────────────────────────────────────────────

pub fn execBrpl(cpu: *Cpu, opcode: u16) !void {
    try execBranch(cpu, opcode, !cpu.getFlag(constants.Sreg.n), "BRPL");
}

pub fn execBrmi(cpu: *Cpu, opcode: u16) !void {
    try execBranch(cpu, opcode, cpu.getFlag(constants.Sreg.n), "BRMI");
}

pub fn execBrvc(cpu: *Cpu, opcode: u16) !void {
    try execBranch(cpu, opcode, !cpu.getFlag(constants.Sreg.v), "BRVC");
}

pub fn execBrvs(cpu: *Cpu, opcode: u16) !void {
    try execBranch(cpu, opcode, cpu.getFlag(constants.Sreg.v), "BRVS");
}

pub fn execBrge(cpu: *Cpu, opcode: u16) !void {
    const take = cpu.getFlag(constants.Sreg.n) == cpu.getFlag(constants.Sreg.v);
    try execBranch(cpu, opcode, take, "BRGE");
}

pub fn execBrlt(cpu: *Cpu, opcode: u16) !void {
    const take = cpu.getFlag(constants.Sreg.n) != cpu.getFlag(constants.Sreg.v);
    try execBranch(cpu, opcode, take, "BRLT");
}

pub fn execBrhs(cpu: *Cpu, opcode: u16) !void {
    try execBranch(cpu, opcode, cpu.getFlag(constants.Sreg.h), "BRHS");
}

pub fn execBrhc(cpu: *Cpu, opcode: u16) !void {
    try execBranch(cpu, opcode, !cpu.getFlag(constants.Sreg.h), "BRHC");
}

pub fn execBrts(cpu: *Cpu, opcode: u16) !void {
    try execBranch(cpu, opcode, cpu.getFlag(constants.Sreg.t), "BRTS");
}

pub fn execBrtc(cpu: *Cpu, opcode: u16) !void {
    try execBranch(cpu, opcode, !cpu.getFlag(constants.Sreg.t), "BRTC");
}

pub fn execBrie(cpu: *Cpu, opcode: u16) !void {
    try execBranch(cpu, opcode, cpu.getFlag(constants.Sreg.i), "BRIE");
}

pub fn execBrid(cpu: *Cpu, opcode: u16) !void {
    try execBranch(cpu, opcode, !cpu.getFlag(constants.Sreg.i), "BRID");
}

// ─── Skip on register bit ────────────────────────────────────────────

pub fn execSbrc(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const bit: u3 = @intCast(opcode & 0x0007);
    const should_skip = (cpu.r[register_index] & decode.bitMask(bit)) == 0;
    try cpu.skipIf(should_skip, "SBRC");
}

pub fn execSbrs(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const bit: u3 = @intCast(opcode & 0x0007);
    const should_skip = (cpu.r[register_index] & decode.bitMask(bit)) != 0;
    try cpu.skipIf(should_skip, "SBRS");
}

pub fn execSbic(cpu: *Cpu, opcode: u16) !void {
    const io_address = decode.decodeBitIoAddress(opcode);
    const bit = decode.decodeBitIoBit(opcode);
    const should_skip = ((try cpu.readIo(io_address)) & decode.bitMask(bit)) == 0;
    try cpu.skipIf(should_skip, "SBIC");
}

// ─── Bit manip: BST / BLD ────────────────────────────────────────────

pub fn execBst(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const bit: u3 = @intCast(opcode & 0x0007);
    const value = (cpu.r[register_index] & decode.bitMask(bit)) != 0;
    cpu.setFlag(constants.Sreg.t, value);
    cpu.tracePrint("BST r{} {}\n", .{ register_index, bit });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execBld(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const bit: u3 = @intCast(opcode & 0x0007);
    if (cpu.getFlag(constants.Sreg.t)) {
        cpu.r[register_index] |= decode.bitMask(bit);
    } else {
        cpu.r[register_index] &= ~decode.bitMask(bit);
    }
    cpu.tracePrint("BLD r{} {}\n", .{ register_index, bit });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

// ─── BSET / BCLR (and aliases) ───────────────────────────────────────

pub fn execBset(cpu: *Cpu, opcode: u16) !void {
    const sreg_bit: u3 = @intCast((opcode & 0x0070) >> 4);
    cpu.setFlag(sreg_bit, true);
    cpu.tracePrint("BSET {}\n", .{sreg_bit});
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execBclr(cpu: *Cpu, opcode: u16) !void {
    const sreg_bit: u3 = @intCast((opcode & 0x0070) >> 4);
    cpu.setFlag(sreg_bit, false);
    cpu.tracePrint("BCLR {}\n", .{sreg_bit});
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

// ─── Multiply ────────────────────────────────────────────────────────

pub fn execMul(cpu: *Cpu, opcode: u16) !void {
    const destination = decode.decodeDestinationRegister(opcode);
    const source = decode.decodeSourceRegister(opcode);
    const result: u16 = @as(u16, cpu.r[destination]) * @as(u16, cpu.r[source]);
    cpu.r[1] = @intCast(result >> 8);
    cpu.r[0] = @intCast(result & 0xff);
    cpu.setFlag(constants.Sreg.z, result == 0);
    cpu.setFlag(constants.Sreg.c, (result & 0x8000) != 0);
    cpu.tracePrint("MUL r{} r{} ; result=0x{x:0>4}\n", .{ destination, source, result });
    cpu.pc += 1;
    cpu.cycles += 2;
}

pub fn execMuls(cpu: *Cpu, opcode: u16) !void {
    const rd: u8 = @intCast((opcode & 0x00f0) >> 4);
    const rr: u8 = @intCast(opcode & 0x000f);
    const src: i16 = @as(i16, @intCast(@as(i8, @bitCast(cpu.r[16 + rr]))));
    const dst: i16 = @as(i16, @intCast(@as(i8, @bitCast(cpu.r[16 + rd]))));
    const result: u16 = @bitCast(@as(i16, @truncate(dst *% src)));
    cpu.r[1] = @intCast(result >> 8);
    cpu.r[0] = @intCast(result & 0xff);
    cpu.setFlag(constants.Sreg.z, result == 0);
    cpu.setFlag(constants.Sreg.c, (result & 0x8000) != 0);
    cpu.tracePrint("MULS r{} r{} ; result=0x{x:0>4}\n", .{ 16 + rd, 16 + rr, result });
    cpu.pc += 1;
    cpu.cycles += 2;
}

pub fn execMulsu(cpu: *Cpu, opcode: u16) !void {
    const rd: usize = 16 + @as(usize, @intCast((opcode & 0x0070) >> 4));
    const rr: usize = 16 + @as(usize, @intCast(opcode & 0x0007));
    const src: u16 = @as(u16, cpu.r[rr]);
    const dst: i16 = @as(i16, @intCast(@as(i8, @bitCast(cpu.r[rd]))));
    const result: u16 = @bitCast(@as(i16, @truncate(dst *% @as(i16, @bitCast(@as(u16, src))))));
    cpu.r[1] = @intCast(result >> 8);
    cpu.r[0] = @intCast(result & 0xff);
    cpu.setFlag(constants.Sreg.z, result == 0);
    cpu.setFlag(constants.Sreg.c, (result & 0x8000) != 0);
    cpu.tracePrint("MULSU r{} r{} ; result=0x{x:0>4}\n", .{ rd, rr, result });
    cpu.pc += 1;
    cpu.cycles += 2;
}

pub fn execFmul(cpu: *Cpu, opcode: u16) !void {
    const rd: usize = 16 + @as(usize, @intCast((opcode & 0x0070) >> 4));
    const rr: usize = 16 + @as(usize, @intCast(opcode & 0x0007));
    const result: u16 = (@as(u16, cpu.r[rd]) * @as(u16, cpu.r[rr])) << 1;
    cpu.r[1] = @intCast(result >> 8);
    cpu.r[0] = @intCast(result & 0xff);
    cpu.setFlag(constants.Sreg.z, result == 0);
    cpu.setFlag(constants.Sreg.c, (result & 0x8000) != 0);
    cpu.tracePrint("FMUL r{} r{} ; result=0x{x:0>4}\n", .{ rd, rr, result });
    cpu.pc += 1;
    cpu.cycles += 2;
}

pub fn execFmuls(cpu: *Cpu, opcode: u16) !void {
    const rd: usize = 16 + @as(usize, @intCast((opcode & 0x0070) >> 4));
    const rr: usize = 16 + @as(usize, @intCast(opcode & 0x0007));
    const src: i16 = @as(i16, @intCast(@as(i8, @bitCast(cpu.r[rr]))));
    const dst: i16 = @as(i16, @intCast(@as(i8, @bitCast(cpu.r[rd]))));
    const result: u16 = @bitCast(@as(i16, @truncate((dst *% src) << 1)));
    cpu.r[1] = @intCast(result >> 8);
    cpu.r[0] = @intCast(result & 0xff);
    cpu.setFlag(constants.Sreg.z, result == 0);
    cpu.setFlag(constants.Sreg.c, (result & 0x8000) != 0);
    cpu.tracePrint("FMULS r{} r{} ; result=0x{x:0>4}\n", .{ rd, rr, result });
    cpu.pc += 1;
    cpu.cycles += 2;
}

pub fn execFmulsu(cpu: *Cpu, opcode: u16) !void {
    const rd: usize = 16 + @as(usize, @intCast((opcode & 0x0070) >> 4));
    const rr: usize = 16 + @as(usize, @intCast(opcode & 0x0007));
    const src: u16 = @as(u16, cpu.r[rr]);
    const dst: i16 = @as(i16, @intCast(@as(i8, @bitCast(cpu.r[rd]))));
    const product: i16 = @truncate(dst *% @as(i16, @bitCast(@as(u16, src))));
    const result: u16 = @bitCast(@as(i16, @truncate(product << 1)));
    cpu.r[1] = @intCast(result >> 8);
    cpu.r[0] = @intCast(result & 0xff);
    cpu.setFlag(constants.Sreg.z, result == 0);
    cpu.setFlag(constants.Sreg.c, (result & 0x8000) != 0);
    cpu.tracePrint("FMULSU r{} r{} ; result=0x{x:0>4}\n", .{ rd, rr, result });
    cpu.pc += 1;
    cpu.cycles += 2;
}

// ─── Shift / Rotate ─────────────────────────────────────────────────

pub fn execLsr(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const value = cpu.r[register_index];
    const result = value >> 1;
    cpu.r[register_index] = result;
    cpu.setFlag(constants.Sreg.z, result == 0);
    cpu.setFlag(constants.Sreg.n, false);
    cpu.setFlag(constants.Sreg.v, cpu.getFlag(constants.Sreg.n) != cpu.getFlag(constants.Sreg.c));
    cpu.setFlag(constants.Sreg.s, cpu.getFlag(constants.Sreg.n) != cpu.getFlag(constants.Sreg.v));
    cpu.setFlag(constants.Sreg.c, (value & 0x01) != 0);
    cpu.tracePrint("LSR r{} ; value=0x{x:0>2}\n", .{ register_index, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execRor(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const value = cpu.r[register_index];
    const lsb: u8 = if (cpu.getFlag(constants.Sreg.c)) 0x80 else 0x00;
    const result = (value >> 1) | lsb;
    cpu.r[register_index] = result;
    cpu.setFlag(constants.Sreg.z, result == 0);
    cpu.setFlag(constants.Sreg.n, (result & 0x80) != 0);
    cpu.setFlag(constants.Sreg.v, cpu.getFlag(constants.Sreg.n) != cpu.getFlag(constants.Sreg.c));
    cpu.setFlag(constants.Sreg.s, cpu.getFlag(constants.Sreg.n) != cpu.getFlag(constants.Sreg.v));
    cpu.setFlag(constants.Sreg.c, (value & 0x01) != 0);
    cpu.tracePrint("ROR r{} ; value=0x{x:0>2}\n", .{ register_index, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execAsr(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const value = cpu.r[register_index];
    const msb = value & 0x80;
    const result = (value >> 1) | msb;
    cpu.r[register_index] = result;
    cpu.setFlag(constants.Sreg.z, result == 0);
    cpu.setFlag(constants.Sreg.n, (result & 0x80) != 0);
    cpu.setFlag(constants.Sreg.v, cpu.getFlag(constants.Sreg.n) != cpu.getFlag(constants.Sreg.c));
    cpu.setFlag(constants.Sreg.s, cpu.getFlag(constants.Sreg.n) != cpu.getFlag(constants.Sreg.v));
    cpu.setFlag(constants.Sreg.c, (value & 0x01) != 0);
    cpu.tracePrint("ASR r{} ; value=0x{x:0>2}\n", .{ register_index, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execSwap(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const value = cpu.r[register_index];
    const result = (value << 4) | (value >> 4);
    cpu.r[register_index] = result;
    cpu.tracePrint("SWAP r{} ; value=0x{x:0>2}\n", .{ register_index, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execNeg(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const value = cpu.r[register_index];
    const result = 0 -% value;
    cpu.r[register_index] = result;
    cpu.setFlag(constants.Sreg.h, ((~value & 0x08) | (result & 0x08)) != 0);
    cpu.setFlag(constants.Sreg.z, result == 0);
    cpu.setFlag(constants.Sreg.n, (result & 0x80) != 0);
    cpu.setFlag(constants.Sreg.v, value == 0x80);
    cpu.setFlag(constants.Sreg.s, cpu.getFlag(constants.Sreg.n) != cpu.getFlag(constants.Sreg.v));
    cpu.setFlag(constants.Sreg.c, value != 0);
    cpu.tracePrint("NEG r{} ; value=0x{x:0>2}\n", .{ register_index, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

// ─── System ──────────────────────────────────────────────────────────

pub fn execSleep(cpu: *Cpu, _: u16) !void {
    cpu.tracePrint("SLEEP\n", .{});
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execWdr(cpu: *Cpu, _: u16) !void {
    cpu.tracePrint("WDR\n", .{});
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execBreak(cpu: *Cpu, _: u16) !void {
    cpu.tracePrint("BREAK\n", .{});
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

// ─── DES ─────────────────────────────────────────────────────────────

pub fn execDes(cpu: *Cpu, opcode: u16) !void {
    _ = opcode;
    cpu.tracePrint("DES\n", .{});
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

// ─── XCH / LAS / LAC / LAT ──────────────────────────────────────────

pub fn execXch(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const address = cpu.readRegisterWord(30);
    const mem_val = try cpu.readData(address);
    const reg_val = cpu.r[register_index];
    cpu.r[register_index] = mem_val;
    try cpu.writeData(address, reg_val);
    cpu.tracePrint("XCH Z r{} ; reg<-0x{x:0>2} mem<-0x{x:0>2}\n", .{ register_index, mem_val, reg_val });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.st;
}

pub fn execLas(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const address = cpu.readRegisterWord(30);
    const mem_val = try cpu.readData(address);
    const result = cpu.r[register_index] | mem_val;
    cpu.r[register_index] = mem_val;
    try cpu.writeData(address, result);
    cpu.tracePrint("LAS Z r{} ; reg<-0x{x:0>2} mem<-0x{x:0>2}\n", .{ register_index, mem_val, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.st;
}

pub fn execLac(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const address = cpu.readRegisterWord(30);
    const mem_val = try cpu.readData(address);
    const result = (~cpu.r[register_index]) & mem_val;
    cpu.r[register_index] = mem_val;
    try cpu.writeData(address, result);
    cpu.tracePrint("LAC Z r{} ; reg<-0x{x:0>2} mem<-0x{x:0>2}\n", .{ register_index, mem_val, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.st;
}

pub fn execLat(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const address = cpu.readRegisterWord(30);
    const mem_val = try cpu.readData(address);
    const result = cpu.r[register_index] ^ mem_val;
    cpu.r[register_index] = mem_val;
    try cpu.writeData(address, result);
    cpu.tracePrint("LAT Z r{} ; reg<-0x{x:0>2} mem<-0x{x:0>2}\n", .{ register_index, mem_val, result });
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.st;
}

// ─── Indirect Jump / Call ────────────────────────────────────────────

pub fn execIjmp(cpu: *Cpu, _: u16) !void {
    const target = cpu.readRegisterWord(30);
    cpu.tracePrint("IJMP -> 0x{x:0>4}\n", .{target});
    cpu.pc = target;
    cpu.cycles += 2;
}

pub fn execIcall(cpu: *Cpu, _: u16) !void {
    const target = cpu.readRegisterWord(30);
    try cpu.pushReturnAddress(cpu.pc + 1);
    cpu.tracePrint("ICALL -> 0x{x:0>4}\n", .{target});
    cpu.pc = target;
    cpu.cycles += 3;
}

pub fn execEijmp(cpu: *Cpu, _: u16) !void {
    const target = cpu.readRegisterWord(30);
    cpu.tracePrint("EIJMP -> 0x{x:0>4}\n", .{target});
    cpu.pc = target;
    cpu.cycles += 2;
}

pub fn execEicall(cpu: *Cpu, _: u16) !void {
    const target = cpu.readRegisterWord(30);
    try cpu.pushReturnAddress(cpu.pc + 1);
    cpu.tracePrint("EICALL -> 0x{x:0>4}\n", .{target});
    cpu.pc = target;
    cpu.cycles += 4;
}

// ─── ELPM ────────────────────────────────────────────────────────────

pub fn execElpmImplicit(cpu: *Cpu, _: u16) !void {
    const z = cpu.readRegisterWord(30);
    const address = z;
    const value = try cpu.flash.readByte(address);
    cpu.r[0] = value;
    cpu.tracePrint("ELPM ; value=0x{x:0>2}\n", .{value});
    cpu.pc += 1;
    cpu.cycles += 3;
}

pub fn execElpm(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const z = cpu.readRegisterWord(30);
    const address = z;
    const value = try cpu.flash.readByte(address);
    cpu.r[register_index] = value;
    cpu.tracePrint("ELPM r{} Z ; value=0x{x:0>2}\n", .{ register_index, value });
    cpu.pc += 1;
    cpu.cycles += 3;
}

pub fn execElpmZPlus(cpu: *Cpu, opcode: u16) !void {
    const register_index = decode.decodeSingleRegister(opcode);
    const z = cpu.readRegisterWord(30);
    const address = z;
    const value = try cpu.flash.readByte(address);
    cpu.r[register_index] = value;
    cpu.writeRegisterWord(30, z +% 1);
    cpu.tracePrint("ELPM r{} Z+ ; value=0x{x:0>2}\n", .{ register_index, value });
    cpu.pc += 1;
    cpu.cycles += 3;
}

// ─── SPM ─────────────────────────────────────────────────────────────

pub fn execSpm(cpu: *Cpu, _: u16) !void {
    cpu.tracePrint("SPM ; (no-op in simulator)\n", .{});
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

pub fn execSpmZPlus(cpu: *Cpu, _: u16) !void {
    const z = cpu.readRegisterWord(30);
    cpu.writeRegisterWord(30, z +% 2);
    cpu.tracePrint("SPM Z+ ; (no-op in simulator)\n", .{});
    cpu.pc += 1;
    cpu.cycles += constants.Cycles.register;
}

// ─── LD Y± / LD Z± ──────────────────────────────────────────────────

pub fn execLdZPlus(cpu: *Cpu, opcode: u16) !void {
    try execLdPointer(cpu, opcode, 30, .postincrement, "LD Z+");
}

pub fn execLdMinusZ(cpu: *Cpu, opcode: u16) !void {
    try execLdPointer(cpu, opcode, 30, .predecrement, "LD -Z");
}

pub fn execLdYPlus(cpu: *Cpu, opcode: u16) !void {
    try execLdPointer(cpu, opcode, 28, .postincrement, "LD Y+");
}

pub fn execLdMinusY(cpu: *Cpu, opcode: u16) !void {
    try execLdPointer(cpu, opcode, 28, .predecrement, "LD -Y");
}

// ─── ST Y± / ST Z± ──────────────────────────────────────────────────

pub fn execStZPlus(cpu: *Cpu, opcode: u16) !void {
    try execStPointer(cpu, opcode, 30, .postincrement, "ST Z+");
}

pub fn execStMinusZ(cpu: *Cpu, opcode: u16) !void {
    try execStPointer(cpu, opcode, 30, .predecrement, "ST -Z");
}

pub fn execStYPlus(cpu: *Cpu, opcode: u16) !void {
    try execStPointer(cpu, opcode, 28, .postincrement, "ST Y+");
}

pub fn execStMinusY(cpu: *Cpu, opcode: u16) !void {
    try execStPointer(cpu, opcode, 28, .predecrement, "ST -Y");
}

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
    const carry: u8 = if (cpu.getFlag(constants.Sreg.c)) 1 else 0;
    const right = cpu.r[source] +% carry;
    const result = cpu.r[destination] +% right;
    cpu.setAddFlags(cpu.r[destination], right, result);
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
    const carry: u8 = if (cpu.getFlag(constants.Sreg.c)) 1 else 0;
    const right = cpu.r[source] +% carry;
    const result = cpu.r[destination] -% right;
    cpu.setSubtractFlags(cpu.r[destination], right, true);
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
    const value = decode.decodeImmediate(opcode);
    const carry: u8 = if (cpu.getFlag(constants.Sreg.c)) 1 else 0;
    const right = value +% carry;
    const result = cpu.r[register_index] -% right;
    cpu.setSubtractFlags(cpu.r[register_index], right, true);
    cpu.r[register_index] = result;
    cpu.tracePrint("SBCI r{} 0x{x:0>2} ; value=0x{x:0>2}\n", .{ register_index, value, result });
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
    const carry: u8 = if (cpu.getFlag(constants.Sreg.c)) 1 else 0;
    cpu.setSubtractFlags(cpu.r[destination], cpu.r[source] +% carry, true);
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

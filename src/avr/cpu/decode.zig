const Cpu = @import("cpu.zig").Cpu;
const instructions = @import("instructions.zig");
const constants = @import("../constants/constants.zig");

pub const Handler = *const fn (*Cpu, u16) anyerror!void;

pub const Entry = struct {
    name: []const u8,
    mask: u16,
    pattern: u16,
    handler: Handler,
};

pub const table = [_]Entry{
    .{ .name = "NOP", .mask = 0xffff, .pattern = constants.Opcode.nop, .handler = &instructions.execNop },
    .{ .name = "RET", .mask = 0xffff, .pattern = constants.Opcode.ret, .handler = &instructions.execRet },
    .{ .name = "RETI", .mask = 0xffff, .pattern = constants.Opcode.reti, .handler = &instructions.execReti },
    .{ .name = "CLI", .mask = 0xffff, .pattern = constants.Opcode.cli, .handler = &instructions.execCli },
    .{ .name = "SEI", .mask = 0xffff, .pattern = constants.Opcode.sei, .handler = &instructions.execSei },
    .{ .name = "LPM", .mask = 0xffff, .pattern = constants.Opcode.lpm, .handler = &instructions.execLpmImplicit },
    .{ .name = "LD X", .mask = constants.Opcode.ld_x_mask, .pattern = constants.Opcode.ld_x_pattern, .handler = &instructions.execLdX },
    .{ .name = "LD X+", .mask = constants.Opcode.ld_x_postincrement_mask, .pattern = constants.Opcode.ld_x_postincrement_pattern, .handler = &instructions.execLdXPlus },
    .{ .name = "LD -X", .mask = constants.Opcode.ld_x_predecrement_mask, .pattern = constants.Opcode.ld_x_predecrement_pattern, .handler = &instructions.execLdMinusX },
    .{ .name = "ST X", .mask = constants.Opcode.st_x_mask, .pattern = constants.Opcode.st_x_pattern, .handler = &instructions.execStX },
    .{ .name = "ST X+", .mask = constants.Opcode.st_x_postincrement_mask, .pattern = constants.Opcode.st_x_postincrement_pattern, .handler = &instructions.execStXPlus },
    .{ .name = "ST -X", .mask = constants.Opcode.st_x_predecrement_mask, .pattern = constants.Opcode.st_x_predecrement_pattern, .handler = &instructions.execStMinusX },
    .{ .name = "CALL", .mask = constants.Opcode.call_mask, .pattern = constants.Opcode.call_pattern, .handler = &instructions.execCall },
    .{ .name = "JMP", .mask = constants.Opcode.jmp_mask, .pattern = constants.Opcode.jmp_pattern, .handler = &instructions.execJmp },
    .{ .name = "RCALL", .mask = constants.Opcode.rcall_mask, .pattern = constants.Opcode.rcall_pattern, .handler = &instructions.execRcall },
    .{ .name = "RJMP", .mask = constants.Opcode.rjmp_mask, .pattern = constants.Opcode.rjmp_pattern, .handler = &instructions.execRjmp },
    .{ .name = "BRNE", .mask = constants.Opcode.brne_mask, .pattern = constants.Opcode.brne_pattern, .handler = &instructions.execBrne },
    .{ .name = "BREQ", .mask = constants.Opcode.breq_mask, .pattern = constants.Opcode.breq_pattern, .handler = &instructions.execBreq },
    .{ .name = "BRCC", .mask = constants.Opcode.brcc_mask, .pattern = constants.Opcode.brcc_pattern, .handler = &instructions.execBrcc },
    .{ .name = "BRCS", .mask = constants.Opcode.brcs_mask, .pattern = constants.Opcode.brcs_pattern, .handler = &instructions.execBrcs },
    .{ .name = "LDI", .mask = constants.Opcode.ldi_mask, .pattern = constants.Opcode.ldi_pattern, .handler = &instructions.execLdi },
    .{ .name = "SUBI", .mask = constants.Opcode.subi_mask, .pattern = constants.Opcode.subi_pattern, .handler = &instructions.execSubi },
    .{ .name = "SBCI", .mask = constants.Opcode.sbci_mask, .pattern = constants.Opcode.sbci_pattern, .handler = &instructions.execSbci },
    .{ .name = "CPI", .mask = constants.Opcode.cpi_mask, .pattern = constants.Opcode.cpi_pattern, .handler = &instructions.execCpi },
    .{ .name = "ORI", .mask = constants.Opcode.ori_mask, .pattern = constants.Opcode.ori_pattern, .handler = &instructions.execOri },
    .{ .name = "ANDI", .mask = constants.Opcode.andi_mask, .pattern = constants.Opcode.andi_pattern, .handler = &instructions.execAndi },
    .{ .name = "ADIW", .mask = constants.Opcode.adiw_mask, .pattern = constants.Opcode.adiw_pattern, .handler = &instructions.execAdiw },
    .{ .name = "SBIW", .mask = constants.Opcode.sbiw_mask, .pattern = constants.Opcode.sbiw_pattern, .handler = &instructions.execSbiw },
    .{ .name = "IN", .mask = constants.Opcode.in_mask, .pattern = constants.Opcode.in_pattern, .handler = &instructions.execIn },
    .{ .name = "OUT", .mask = constants.Opcode.out_mask, .pattern = constants.Opcode.out_pattern, .handler = &instructions.execOut },
    .{ .name = "SBI", .mask = constants.Opcode.sbi_mask, .pattern = constants.Opcode.sbi_pattern, .handler = &instructions.execSbi },
    .{ .name = "CBI", .mask = constants.Opcode.cbi_mask, .pattern = constants.Opcode.cbi_pattern, .handler = &instructions.execCbi },
    .{ .name = "SBIS", .mask = constants.Opcode.sbis_mask, .pattern = constants.Opcode.sbis_pattern, .handler = &instructions.execSbis },
    .{ .name = "INC", .mask = constants.Opcode.inc_mask, .pattern = constants.Opcode.inc_pattern, .handler = &instructions.execInc },
    .{ .name = "DEC", .mask = constants.Opcode.dec_mask, .pattern = constants.Opcode.dec_pattern, .handler = &instructions.execDec },
    .{ .name = "COM", .mask = constants.Opcode.com_mask, .pattern = constants.Opcode.com_pattern, .handler = &instructions.execCom },
    .{ .name = "PUSH", .mask = constants.Opcode.push_mask, .pattern = constants.Opcode.push_pattern, .handler = &instructions.execPush },
    .{ .name = "POP", .mask = constants.Opcode.pop_mask, .pattern = constants.Opcode.pop_pattern, .handler = &instructions.execPop },
    .{ .name = "LDS", .mask = constants.Opcode.lds_mask, .pattern = constants.Opcode.lds_pattern, .handler = &instructions.execLds },
    .{ .name = "STS", .mask = constants.Opcode.sts_mask, .pattern = constants.Opcode.sts_pattern, .handler = &instructions.execSts },
    .{ .name = "LPM Z", .mask = constants.Opcode.lpm_z_mask, .pattern = constants.Opcode.lpm_z_pattern, .handler = &instructions.execLpm },
    .{ .name = "LD Z", .mask = constants.Opcode.ld_z_mask, .pattern = constants.Opcode.ld_z_pattern, .handler = &instructions.execLdZ },
    .{ .name = "LD Y", .mask = constants.Opcode.ld_y_mask, .pattern = constants.Opcode.ld_y_pattern, .handler = &instructions.execLdY },
    .{ .name = "ST Z", .mask = constants.Opcode.st_z_mask, .pattern = constants.Opcode.st_z_pattern, .handler = &instructions.execStZ },
    .{ .name = "ST Y", .mask = constants.Opcode.st_y_mask, .pattern = constants.Opcode.st_y_pattern, .handler = &instructions.execStY },
    .{ .name = "MOVW", .mask = constants.Opcode.movw_mask, .pattern = constants.Opcode.movw_pattern, .handler = &instructions.execMovw },
    .{ .name = "ADD", .mask = constants.Opcode.add_mask, .pattern = constants.Opcode.add_pattern, .handler = &instructions.execAdd },
    .{ .name = "ADC", .mask = constants.Opcode.adc_mask, .pattern = constants.Opcode.adc_pattern, .handler = &instructions.execAdc },
    .{ .name = "SUB", .mask = constants.Opcode.sub_mask, .pattern = constants.Opcode.sub_pattern, .handler = &instructions.execSub },
    .{ .name = "SBC", .mask = constants.Opcode.sbc_mask, .pattern = constants.Opcode.sbc_pattern, .handler = &instructions.execSbc },
    .{ .name = "CPC", .mask = constants.Opcode.cpc_mask, .pattern = constants.Opcode.cpc_pattern, .handler = &instructions.execCpc },
    .{ .name = "CPSE", .mask = constants.Opcode.cpse_mask, .pattern = constants.Opcode.cpse_pattern, .handler = &instructions.execCpse },
    .{ .name = "EOR", .mask = constants.Opcode.eor_mask, .pattern = constants.Opcode.eor_pattern, .handler = &instructions.execEor },
    .{ .name = "MOV", .mask = constants.Opcode.mov_mask, .pattern = constants.Opcode.mov_pattern, .handler = &instructions.execMov },
    .{ .name = "AND", .mask = constants.Opcode.and_mask, .pattern = constants.Opcode.and_pattern, .handler = &instructions.execAnd },
    .{ .name = "OR", .mask = constants.Opcode.or_mask, .pattern = constants.Opcode.or_pattern, .handler = &instructions.execOr },
    .{ .name = "CP", .mask = constants.Opcode.cp_mask, .pattern = constants.Opcode.cp_pattern, .handler = &instructions.execCp },
};

pub fn decode(opcode: u16) ?Handler {
    for (table) |entry| {
        if ((opcode & entry.mask) == entry.pattern) {
            return entry.handler;
        }
    }
    return null;
}

pub fn isTwoWordInstruction(opcode: u16) bool {
    return ((opcode & constants.Opcode.call_mask) == constants.Opcode.call_pattern) or
        ((opcode & constants.Opcode.jmp_mask) == constants.Opcode.jmp_pattern) or
        ((opcode & constants.Opcode.lds_mask) == constants.Opcode.lds_pattern) or
        ((opcode & constants.Opcode.sts_mask) == constants.Opcode.sts_pattern);
}

pub fn bitMask(bit: u3) u8 {
    return @as(u8, 1) << bit;
}

pub fn decodeAbsolute22(opcode: u16, next_word: u16) u32 {
    const high_bits =
        (@as(u32, opcode & constants.Jmp.high_bits_mask) << constants.Jmp.high_bits_shift) |
        (@as(u32, opcode & constants.Jmp.low_high_bit_mask) << constants.Jmp.low_high_bit_shift);

    return high_bits | @as(u32, next_word);
}

pub fn decodeRelative12(opcode: u16) i32 {
    const raw: i32 = @as(i32, @intCast(opcode & constants.Rjmp.offset_mask));

    return if ((opcode & constants.Rjmp.sign_bit) != 0)
        raw - constants.Rjmp.sign_extend_subtract
    else
        raw;
}

pub fn decodeRelative7(opcode: u16) i32 {
    const raw: i32 = @as(i32, @intCast(
        (opcode & constants.Branch.offset_mask) >> constants.Branch.offset_shift,
    ));

    return if ((raw & constants.Branch.sign_bit) != 0)
        raw - constants.Branch.sign_extend_subtract
    else
        raw;
}

pub fn decodeImmediateRegister(opcode: u16) usize {
    return constants.Immediate.register_base + @as(usize, @intCast(
        (opcode & constants.Immediate.register_mask) >> constants.Immediate.register_shift,
    ));
}

pub fn decodeImmediate(opcode: u16) u8 {
    const imm_low = opcode & constants.Immediate.imm_low_mask;
    const imm_high = (opcode & constants.Immediate.imm_high_mask) >> constants.Immediate.imm_high_shift;

    return @as(u8, @intCast(imm_high | imm_low));
}

pub fn decodeIoAddress(opcode: u16) usize {
    return @as(usize, @intCast(opcode & constants.Out.io_low_mask)) | @as(usize, @intCast(
        (opcode & constants.Out.io_high_mask) >> constants.Out.io_high_shift,
    ));
}

pub fn decodeIoRegister(opcode: u16) usize {
    return @as(usize, @intCast(
        (opcode & constants.Out.register_mask) >> constants.Out.register_shift,
    ));
}

pub fn decodeBitIoAddress(opcode: u16) usize {
    return @as(usize, @intCast((opcode & constants.BitIo.io_mask) >> constants.BitIo.io_shift));
}

pub fn decodeBitIoBit(opcode: u16) u3 {
    return @as(u3, @intCast(opcode & constants.BitIo.bit_mask));
}

pub fn decodeDestinationRegister(opcode: u16) usize {
    return @as(usize, @intCast(
        (opcode & constants.RegisterPair.destination_mask) >> constants.RegisterPair.destination_shift,
    ));
}

pub fn decodeSourceRegister(opcode: u16) usize {
    return @as(usize, @intCast(opcode & constants.RegisterPair.source_low_mask)) | @as(usize, @intCast(
        (opcode & constants.RegisterPair.source_high_mask) >> constants.RegisterPair.source_high_shift,
    ));
}

pub fn decodeSingleRegister(opcode: u16) usize {
    return @as(usize, @intCast(
        (opcode & constants.SingleRegister.register_mask) >> constants.SingleRegister.register_shift,
    ));
}

pub fn decodeWordImmediateRegister(opcode: u16) usize {
    return constants.WordImmediate.register_base + @as(usize, @intCast(
        (opcode & constants.WordImmediate.register_mask) >> constants.WordImmediate.register_shift,
    ));
}

pub fn decodeWordImmediate(opcode: u16) u16 {
    const imm_low = opcode & constants.WordImmediate.imm_low_mask;
    const imm_high = (opcode & constants.WordImmediate.imm_high_mask) >> constants.WordImmediate.imm_high_shift;

    return @as(u16, @intCast(imm_high | imm_low));
}

pub fn decodeMovwDestination(opcode: u16) usize {
    return @as(usize, @intCast(
        (opcode & constants.RegisterPairMove.destination_mask) >> constants.RegisterPairMove.destination_shift,
    ));
}

pub fn decodeMovwSource(opcode: u16) usize {
    return @as(usize, @intCast(
        (opcode & constants.RegisterPairMove.source_mask) << constants.RegisterPairMove.source_shift,
    ));
}

pub fn decodeDisplacement(opcode: u16) u16 {
    const q0_2 = opcode & 0x0007;
    const q3_4 = (opcode & 0x0c00) >> 7;
    const q5 = (opcode & 0x2000) >> 8;

    return @as(u16, @intCast(q0_2 | q3_4 | q5));
}

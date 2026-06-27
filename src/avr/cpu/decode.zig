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
    .{ .name = "ELPM", .mask = 0xffff, .pattern = constants.Opcode.elpm_implicit, .handler = &instructions.execElpmImplicit },
    .{ .name = "SLEEP", .mask = 0xffff, .pattern = constants.Opcode.sleep, .handler = &instructions.execSleep },
    .{ .name = "WDR", .mask = 0xffff, .pattern = constants.Opcode.wdr, .handler = &instructions.execWdr },
    .{ .name = "BREAK", .mask = 0xffff, .pattern = constants.Opcode.break_opcode, .handler = &instructions.execBreak },
    .{ .name = "ICALL", .mask = 0xffff, .pattern = constants.Opcode.icall, .handler = &instructions.execIcall },
    .{ .name = "IJMP", .mask = 0xffff, .pattern = constants.Opcode.ijmp, .handler = &instructions.execIjmp },
    .{ .name = "EICALL", .mask = 0xffff, .pattern = constants.Opcode.eicall, .handler = &instructions.execEicall },
    .{ .name = "EIJMP", .mask = 0xffff, .pattern = constants.Opcode.eijmp, .handler = &instructions.execEijmp },
    .{ .name = "SPM", .mask = 0xffff, .pattern = constants.Opcode.spm, .handler = &instructions.execSpm },
    .{ .name = "SPM Z+", .mask = 0xffff, .pattern = constants.Opcode.spm_z_plus, .handler = &instructions.execSpmZPlus },
    .{ .name = "BSET", .mask = constants.Opcode.bset_mask, .pattern = constants.Opcode.bset_pattern, .handler = &instructions.execBset },
    .{ .name = "BCLR", .mask = constants.Opcode.bclr_mask, .pattern = constants.Opcode.bclr_pattern, .handler = &instructions.execBclr },
    .{ .name = "DES", .mask = constants.Opcode.des_mask, .pattern = constants.Opcode.des_pattern, .handler = &instructions.execDes },
    .{ .name = "LD X", .mask = constants.Opcode.ld_x_mask, .pattern = constants.Opcode.ld_x_pattern, .handler = &instructions.execLdX },
    .{ .name = "LD X+", .mask = constants.Opcode.ld_x_postincrement_mask, .pattern = constants.Opcode.ld_x_postincrement_pattern, .handler = &instructions.execLdXPlus },
    .{ .name = "LD -X", .mask = constants.Opcode.ld_x_predecrement_mask, .pattern = constants.Opcode.ld_x_predecrement_pattern, .handler = &instructions.execLdMinusX },
    .{ .name = "ST X", .mask = constants.Opcode.st_x_mask, .pattern = constants.Opcode.st_x_pattern, .handler = &instructions.execStX },
    .{ .name = "ST X+", .mask = constants.Opcode.st_x_postincrement_mask, .pattern = constants.Opcode.st_x_postincrement_pattern, .handler = &instructions.execStXPlus },
    .{ .name = "ST -X", .mask = constants.Opcode.st_x_predecrement_mask, .pattern = constants.Opcode.st_x_predecrement_pattern, .handler = &instructions.execStMinusX },
    .{ .name = "LD Z+", .mask = constants.Opcode.ld_z_postincrement_mask, .pattern = constants.Opcode.ld_z_postincrement_pattern, .handler = &instructions.execLdZPlus },
    .{ .name = "LD -Z", .mask = constants.Opcode.ld_z_predecrement_mask, .pattern = constants.Opcode.ld_z_predecrement_pattern, .handler = &instructions.execLdMinusZ },
    .{ .name = "LD Y+", .mask = constants.Opcode.ld_y_postincrement_mask, .pattern = constants.Opcode.ld_y_postincrement_pattern, .handler = &instructions.execLdYPlus },
    .{ .name = "LD -Y", .mask = constants.Opcode.ld_y_predecrement_mask, .pattern = constants.Opcode.ld_y_predecrement_pattern, .handler = &instructions.execLdMinusY },
    .{ .name = "ST Z+", .mask = constants.Opcode.st_z_postincrement_mask, .pattern = constants.Opcode.st_z_postincrement_pattern, .handler = &instructions.execStZPlus },
    .{ .name = "ST -Z", .mask = constants.Opcode.st_z_predecrement_mask, .pattern = constants.Opcode.st_z_predecrement_pattern, .handler = &instructions.execStMinusZ },
    .{ .name = "ST Y+", .mask = constants.Opcode.st_y_postincrement_mask, .pattern = constants.Opcode.st_y_postincrement_pattern, .handler = &instructions.execStYPlus },
    .{ .name = "ST -Y", .mask = constants.Opcode.st_y_predecrement_mask, .pattern = constants.Opcode.st_y_predecrement_pattern, .handler = &instructions.execStMinusY },
    .{ .name = "LDD Z+q", .mask = constants.Opcode.ldd_std_mask, .pattern = constants.Opcode.ldd_z_pattern, .handler = &instructions.execLddZ },
    .{ .name = "LDD Y+q", .mask = constants.Opcode.ldd_std_mask, .pattern = constants.Opcode.ldd_y_pattern, .handler = &instructions.execLddY },
    .{ .name = "STD Z+q", .mask = constants.Opcode.ldd_std_mask, .pattern = constants.Opcode.std_z_pattern, .handler = &instructions.execStdZ },
    .{ .name = "STD Y+q", .mask = constants.Opcode.ldd_std_mask, .pattern = constants.Opcode.std_y_pattern, .handler = &instructions.execStdY },
    .{ .name = "CALL", .mask = constants.Opcode.call_mask, .pattern = constants.Opcode.call_pattern, .handler = &instructions.execCall },
    .{ .name = "JMP", .mask = constants.Opcode.jmp_mask, .pattern = constants.Opcode.jmp_pattern, .handler = &instructions.execJmp },
    .{ .name = "RCALL", .mask = constants.Opcode.rcall_mask, .pattern = constants.Opcode.rcall_pattern, .handler = &instructions.execRcall },
    .{ .name = "RJMP", .mask = constants.Opcode.rjmp_mask, .pattern = constants.Opcode.rjmp_pattern, .handler = &instructions.execRjmp },
    .{ .name = "BRNE", .mask = constants.Opcode.brne_mask, .pattern = constants.Opcode.brne_pattern, .handler = &instructions.execBrne },
    .{ .name = "BREQ", .mask = constants.Opcode.breq_mask, .pattern = constants.Opcode.breq_pattern, .handler = &instructions.execBreq },
    .{ .name = "BRCC", .mask = constants.Opcode.brcc_mask, .pattern = constants.Opcode.brcc_pattern, .handler = &instructions.execBrcc },
    .{ .name = "BRCS", .mask = constants.Opcode.brcs_mask, .pattern = constants.Opcode.brcs_pattern, .handler = &instructions.execBrcs },
    .{ .name = "BRPL", .mask = constants.Opcode.branch_mask, .pattern = 0xf402, .handler = &instructions.execBrpl },
    .{ .name = "BRMI", .mask = constants.Opcode.branch_mask, .pattern = 0xf002, .handler = &instructions.execBrmi },
    .{ .name = "BRVC", .mask = constants.Opcode.branch_mask, .pattern = 0xf403, .handler = &instructions.execBrvc },
    .{ .name = "BRVS", .mask = constants.Opcode.branch_mask, .pattern = 0xf003, .handler = &instructions.execBrvs },
    .{ .name = "BRGE", .mask = constants.Opcode.branch_mask, .pattern = 0xf404, .handler = &instructions.execBrge },
    .{ .name = "BRLT", .mask = constants.Opcode.branch_mask, .pattern = 0xf004, .handler = &instructions.execBrlt },
    .{ .name = "BRHS", .mask = constants.Opcode.branch_mask, .pattern = 0xf005, .handler = &instructions.execBrhs },
    .{ .name = "BRHC", .mask = constants.Opcode.branch_mask, .pattern = 0xf405, .handler = &instructions.execBrhc },
    .{ .name = "BRTS", .mask = constants.Opcode.branch_mask, .pattern = 0xf006, .handler = &instructions.execBrts },
    .{ .name = "BRTC", .mask = constants.Opcode.branch_mask, .pattern = 0xf406, .handler = &instructions.execBrtc },
    .{ .name = "BRIE", .mask = constants.Opcode.branch_mask, .pattern = 0xf007, .handler = &instructions.execBrie },
    .{ .name = "BRID", .mask = constants.Opcode.branch_mask, .pattern = 0xf407, .handler = &instructions.execBrid },
    .{ .name = "SBRC", .mask = constants.Opcode.sbrc_mask, .pattern = constants.Opcode.sbrc_pattern, .handler = &instructions.execSbrc },
    .{ .name = "SBRS", .mask = constants.Opcode.sbrs_mask, .pattern = constants.Opcode.sbrs_pattern, .handler = &instructions.execSbrs },
    .{ .name = "BST", .mask = constants.Opcode.bst_mask, .pattern = constants.Opcode.bst_pattern, .handler = &instructions.execBst },
    .{ .name = "BLD", .mask = constants.Opcode.bld_mask, .pattern = constants.Opcode.bld_pattern, .handler = &instructions.execBld },
    .{ .name = "LDI", .mask = constants.Opcode.ldi_mask, .pattern = constants.Opcode.ldi_pattern, .handler = &instructions.execLdi },
    .{ .name = "SUBI", .mask = constants.Opcode.subi_mask, .pattern = constants.Opcode.subi_pattern, .handler = &instructions.execSubi },
    .{ .name = "SBCI", .mask = constants.Opcode.sbci_mask, .pattern = constants.Opcode.sbci_pattern, .handler = &instructions.execSbci },
    .{ .name = "CPI", .mask = constants.Opcode.cpi_mask, .pattern = constants.Opcode.cpi_pattern, .handler = &instructions.execCpi },
    .{ .name = "ORI", .mask = constants.Opcode.ori_mask, .pattern = constants.Opcode.ori_pattern, .handler = &instructions.execOri },
    .{ .name = "ANDI", .mask = constants.Opcode.andi_mask, .pattern = constants.Opcode.andi_pattern, .handler = &instructions.execAndi },
    .{ .name = "ADIW", .mask = constants.Opcode.adiw_mask, .pattern = constants.Opcode.adiw_pattern, .handler = &instructions.execAdiw },
    .{ .name = "SBIW", .mask = constants.Opcode.sbiw_mask, .pattern = constants.Opcode.sbiw_pattern, .handler = &instructions.execSbiw },
    .{ .name = "MULS", .mask = constants.Opcode.muls_mask, .pattern = constants.Opcode.muls_pattern, .handler = &instructions.execMuls },
    .{ .name = "MULSU", .mask = constants.Opcode.mul_su_fm_variants_mask, .pattern = constants.Opcode.mulsu_pattern, .handler = &instructions.execMulsu },
    .{ .name = "FMUL", .mask = constants.Opcode.mul_su_fm_variants_mask, .pattern = constants.Opcode.fmul_pattern, .handler = &instructions.execFmul },
    .{ .name = "FMULS", .mask = constants.Opcode.mul_su_fm_variants_mask, .pattern = constants.Opcode.fmuls_pattern, .handler = &instructions.execFmuls },
    .{ .name = "FMULSU", .mask = constants.Opcode.mul_su_fm_variants_mask, .pattern = constants.Opcode.fmulsu_pattern, .handler = &instructions.execFmulsu },
    .{ .name = "IN", .mask = constants.Opcode.in_mask, .pattern = constants.Opcode.in_pattern, .handler = &instructions.execIn },
    .{ .name = "OUT", .mask = constants.Opcode.out_mask, .pattern = constants.Opcode.out_pattern, .handler = &instructions.execOut },
    .{ .name = "SBI", .mask = constants.Opcode.sbi_mask, .pattern = constants.Opcode.sbi_pattern, .handler = &instructions.execSbi },
    .{ .name = "CBI", .mask = constants.Opcode.cbi_mask, .pattern = constants.Opcode.cbi_pattern, .handler = &instructions.execCbi },
    .{ .name = "SBIS", .mask = constants.Opcode.sbis_mask, .pattern = constants.Opcode.sbis_pattern, .handler = &instructions.execSbis },
    .{ .name = "SBIC", .mask = constants.Opcode.sbic_mask, .pattern = constants.Opcode.sbic_pattern, .handler = &instructions.execSbic },
    .{ .name = "INC", .mask = constants.Opcode.inc_mask, .pattern = constants.Opcode.inc_pattern, .handler = &instructions.execInc },
    .{ .name = "DEC", .mask = constants.Opcode.dec_mask, .pattern = constants.Opcode.dec_pattern, .handler = &instructions.execDec },
    .{ .name = "COM", .mask = constants.Opcode.com_mask, .pattern = constants.Opcode.com_pattern, .handler = &instructions.execCom },
    .{ .name = "NEG", .mask = constants.Opcode.neg_mask, .pattern = constants.Opcode.neg_pattern, .handler = &instructions.execNeg },
    .{ .name = "LSR", .mask = constants.Opcode.lsr_mask, .pattern = constants.Opcode.lsr_pattern, .handler = &instructions.execLsr },
    .{ .name = "ROR", .mask = constants.Opcode.ror_mask, .pattern = constants.Opcode.ror_pattern, .handler = &instructions.execRor },
    .{ .name = "ASR", .mask = constants.Opcode.asr_mask, .pattern = constants.Opcode.asr_pattern, .handler = &instructions.execAsr },
    .{ .name = "SWAP", .mask = constants.Opcode.swap_mask, .pattern = constants.Opcode.swap_pattern, .handler = &instructions.execSwap },
    .{ .name = "PUSH", .mask = constants.Opcode.push_mask, .pattern = constants.Opcode.push_pattern, .handler = &instructions.execPush },
    .{ .name = "POP", .mask = constants.Opcode.pop_mask, .pattern = constants.Opcode.pop_pattern, .handler = &instructions.execPop },
    .{ .name = "LDS", .mask = constants.Opcode.lds_mask, .pattern = constants.Opcode.lds_pattern, .handler = &instructions.execLds },
    .{ .name = "STS", .mask = constants.Opcode.sts_mask, .pattern = constants.Opcode.sts_pattern, .handler = &instructions.execSts },
    .{ .name = "XCH", .mask = constants.Opcode.xch_mask, .pattern = constants.Opcode.xch_pattern, .handler = &instructions.execXch },
    .{ .name = "LAS", .mask = constants.Opcode.las_mask, .pattern = constants.Opcode.las_pattern, .handler = &instructions.execLas },
    .{ .name = "LAC", .mask = constants.Opcode.lac_mask, .pattern = constants.Opcode.lac_pattern, .handler = &instructions.execLac },
    .{ .name = "LAT", .mask = constants.Opcode.lat_mask, .pattern = constants.Opcode.lat_pattern, .handler = &instructions.execLat },
    .{ .name = "ELPM Z", .mask = constants.Opcode.elpm_z_mask, .pattern = constants.Opcode.elpm_z_pattern, .handler = &instructions.execElpm },
    .{ .name = "ELPM Z+", .mask = constants.Opcode.elpm_z_postincrement_mask, .pattern = constants.Opcode.elpm_z_postincrement_pattern, .handler = &instructions.execElpmZPlus },
    .{ .name = "LPM Z", .mask = constants.Opcode.lpm_z_mask, .pattern = constants.Opcode.lpm_z_pattern, .handler = &instructions.execLpm },
    .{ .name = "LD Z", .mask = constants.Opcode.ld_z_mask, .pattern = constants.Opcode.ld_z_pattern, .handler = &instructions.execLdZ },
    .{ .name = "LD Y", .mask = constants.Opcode.ld_y_mask, .pattern = constants.Opcode.ld_y_pattern, .handler = &instructions.execLdY },
    .{ .name = "ST Z", .mask = constants.Opcode.st_z_mask, .pattern = constants.Opcode.st_z_pattern, .handler = &instructions.execStZ },
    .{ .name = "ST Y", .mask = constants.Opcode.st_y_mask, .pattern = constants.Opcode.st_y_pattern, .handler = &instructions.execStY },
    .{ .name = "MOVW", .mask = constants.Opcode.movw_mask, .pattern = constants.Opcode.movw_pattern, .handler = &instructions.execMovw },
    .{ .name = "MUL", .mask = constants.Opcode.mul_mask, .pattern = constants.Opcode.mul_pattern, .handler = &instructions.execMul },
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

const testing = @import("std").testing;

test "decode NOP" {
    try testing.expect(decode(0x0000) != null);
    try testing.expectEqualStrings("NOP", table[0].name);
}

test "decode RJMP" {
    try testing.expect(decode(0xc000) != null);
    try testing.expect(decode(0xcfff) != null);
    try testing.expect(decode(0x8000) == null);
}

test "decode BRNE" {
    const brne_opcode: u16 = 0xf401;
    try testing.expect(decode(brne_opcode) != null);
}

test "decode BREQ" {
    const breq_opcode: u16 = 0xf001;
    try testing.expect(decode(breq_opcode) != null);
}

test "decode LDI" {
    const ldi_r16_0xff: u16 = 0xef0f;
    try testing.expect(decode(ldi_r16_0xff) != null);
    try testing.expectEqual(@as(usize, 16), decodeImmediateRegister(ldi_r16_0xff));
    try testing.expectEqual(@as(u8, 0xff), decodeImmediate(ldi_r16_0xff));
}

test "decode LDI r31=0xaa" {
    const opcode: u16 = 0xefaa;
    try testing.expectEqual(@as(usize, 31), decodeImmediateRegister(opcode));
    try testing.expectEqual(@as(u8, 0xaa), decodeImmediate(opcode));
}

test "decode OUT" {
    const out_portb_r16: u16 = 0xb905;
    try testing.expect(decode(out_portb_r16) != null);
    try testing.expectEqual(@as(usize, 0x05), decodeIoAddress(out_portb_r16));
    try testing.expectEqual(@as(usize, 16), decodeIoRegister(out_portb_r16));
}

test "decode IN" {
    const in_r16_pinb: u16 = 0xb103;
    try testing.expect(decode(in_r16_pinb) != null);
    try testing.expectEqual(@as(usize, 0x03), decodeIoAddress(in_r16_pinb));
    try testing.expectEqual(@as(usize, 16), decodeIoRegister(in_r16_pinb));
}

test "decode SBI" {
    const sbi_portb_5: u16 = 0x9a2d;
    try testing.expect(decode(sbi_portb_5) != null);
    try testing.expectEqual(@as(usize, 0x05), decodeBitIoAddress(sbi_portb_5));
    try testing.expectEqual(@as(u3, 5), decodeBitIoBit(sbi_portb_5));
}

test "decode CBI" {
    try testing.expect(decode(0x982d) != null);
}

test "decode ADD" {
    const add_r0_r1: u16 = 0x0c01;
    try testing.expect(decode(add_r0_r1) != null);
    try testing.expectEqual(@as(usize, 0), decodeDestinationRegister(add_r0_r1));
    try testing.expectEqual(@as(usize, 1), decodeSourceRegister(add_r0_r1));
}

test "decode ADC" {
    try testing.expect(decode(0x1c34) != null);
}

test "decode SUB" {
    try testing.expect(decode(0x1812) != null);
}

test "decode SUBI" {
    const subi_r16_1: u16 = 0x5001;
    try testing.expect(decode(subi_r16_1) != null);
}

test "decode SBCI" {
    try testing.expect(decode(0x40ff) != null);
}

test "decode MOV" {
    const mov_r0_r1: u16 = 0x2c01;
    try testing.expect(decode(mov_r0_r1) != null);
}

test "decode INC" {
    try testing.expect(decode(0x9403) != null);
    try testing.expectEqual(@as(usize, 0), decodeSingleRegister(0x9403));
    try testing.expectEqual(@as(usize, 16), decodeSingleRegister(0x9513));
}

test "decode DEC" {
    try testing.expect(decode(0x940a) != null);
}

test "decode PUSH" {
    try testing.expect(decode(0x920f) != null);
}

test "decode POP" {
    try testing.expect(decode(0x900f) != null);
}

test "decode CALL" {
    try testing.expect(decode(0x940e) != null);
}

test "decode JMP" {
    try testing.expect(decode(0x940c) != null);
}

test "decode RCALL" {
    try testing.expect(decode(0xd000) != null);
}

test "decode ADIW" {
    const adiw_r24_0x3f: u16 = 0x963f;
    try testing.expect(decode(adiw_r24_0x3f) != null);
    try testing.expectEqual(@as(usize, 24), decodeWordImmediateRegister(adiw_r24_0x3f));
    try testing.expectEqual(@as(u16, 0x3f), decodeWordImmediate(adiw_r24_0x3f));
}

test "decode SBIW" {
    try testing.expect(decode(0x973f) != null);
}

test "decode CPI" {
    try testing.expect(decode(0x30ff) != null);
}

test "decode CP" {
    try testing.expect(decode(0x1401) != null);
}

test "decode CPC" {
    try testing.expect(decode(0x0401) != null);
}

test "decode EOR" {
    try testing.expect(decode(0x2401) != null);
}

test "decode AND" {
    try testing.expect(decode(0x2001) != null);
}

test "decode OR" {
    try testing.expect(decode(0x2801) != null);
}

test "decode ORI" {
    try testing.expect(decode(0x60ff) != null);
}

test "decode ANDI" {
    try testing.expect(decode(0x70ff) != null);
}

test "decode LSL" {
    try testing.expect(decode(0x0c66) != null);
}

test "decode ROL" {
    try testing.expect(decode(0x1c66) != null);
}

test "decode MOVW" {
    const movw_r0_r2: u16 = 0x0101;
    try testing.expect(decode(movw_r0_r2) != null);
    try testing.expectEqual(@as(usize, 0), decodeMovwDestination(movw_r0_r2));
    try testing.expectEqual(@as(usize, 2), decodeMovwSource(movw_r0_r2));
}

test "decode MUL" {
    try testing.expect(decode(0x9c01) != null);
}

test "decode MULS" {
    try testing.expect(decode(0x0200) != null);
}

test "decode MULSU" {
    try testing.expect(decode(0x0300) != null);
}

test "decode LDS" {
    try testing.expect(decode(0x9000) != null);
}

test "decode STS" {
    try testing.expect(decode(0x9200) != null);
}

test "decode SWAP" {
    try testing.expect(decode(0x9402) != null);
}

test "decode LSR" {
    try testing.expect(decode(0x9406) != null);
}

test "decode ROR" {
    try testing.expect(decode(0x9407) != null);
}

test "decode ASR" {
    try testing.expect(decode(0x9405) != null);
}

test "decode COM" {
    try testing.expect(decode(0x9400) != null);
}

test "decode NEG" {
    try testing.expect(decode(0x9401) != null);
}

test "decode BSET" {
    try testing.expect(decode(0x9408) != null);
}

test "decode BCLR" {
    try testing.expect(decode(0x9488) != null);
}

test "decode SBRC" {
    try testing.expect(decode(0xfc00) != null);
}

test "decode SBRS" {
    try testing.expect(decode(0xfe00) != null);
}

test "decode BST" {
    try testing.expect(decode(0xfa00) != null);
}

test "decode BLD" {
    try testing.expect(decode(0xf800) != null);
}

test "decode SLEEP" {
    try testing.expect(decode(0x9588) != null);
}

test "decode WDR" {
    try testing.expect(decode(0x95a8) != null);
}

test "decode BREAK" {
    try testing.expect(decode(0x9598) != null);
}

test "decode LPM implicit" {
    try testing.expect(decode(0x95c8) != null);
}

test "decode LPM Z" {
    try testing.expect(decode(0x9004) != null);
}

test "decode ELPM Z" {
    try testing.expect(decode(0x9006) != null);
}

test "decode ELPM Z+" {
    try testing.expect(decode(0x9007) != null);
}

test "decode ICALL" {
    try testing.expect(decode(0x9509) != null);
}

test "decode IJMP" {
    try testing.expect(decode(0x9409) != null);
}

test "decode EICALL" {
    try testing.expect(decode(0x9519) != null);
}

test "decode EIJMP" {
    try testing.expect(decode(0x9419) != null);
}

test "decode XCH" {
    try testing.expect(decode(0x9204) != null);
}

test "decode LAS" {
    try testing.expect(decode(0x9205) != null);
}

test "decode LAC" {
    try testing.expect(decode(0x9206) != null);
}

test "decode LAT" {
    try testing.expect(decode(0x9207) != null);
}

test "decode unknown opcode returns null" {
    try testing.expect(decode(0xffff) == null);
}

test "isTwoWordInstruction CALL" {
    try testing.expect(isTwoWordInstruction(0x940e));
}

test "isTwoWordInstruction JMP" {
    try testing.expect(isTwoWordInstruction(0x940c));
}

test "isTwoWordInstruction LDS" {
    try testing.expect(isTwoWordInstruction(0x9000));
}

test "isTwoWordInstruction STS" {
    try testing.expect(isTwoWordInstruction(0x9200));
}

test "isTwoWordInstruction NOP is single word" {
    try testing.expect(!isTwoWordInstruction(0x0000));
}

test "isTwoWordInstruction RJMP is single word" {
    try testing.expect(!isTwoWordInstruction(0xc000));
}

test "bitMask" {
    try testing.expectEqual(@as(u8, 0x01), bitMask(0));
    try testing.expectEqual(@as(u8, 0x02), bitMask(1));
    try testing.expectEqual(@as(u8, 0x80), bitMask(7));
}

test "decodeAbsolute22" {
    const opcode: u16 = 0x940c;
    const next_word: u16 = 0x1234;
    const result = decodeAbsolute22(opcode, next_word);
    try testing.expectEqual(@as(u32, 0x1234), result);
}

test "decodeRelative12 positive" {
    const result = decodeRelative12(0xc005);
    try testing.expectEqual(@as(i32, 5), result);
}

test "decodeRelative12 negative" {
    const result = decodeRelative12(0xcfff);
    try testing.expectEqual(@as(i32, -1), result);
}

test "decodeRelative7 positive" {
    const result = decodeRelative7(0xf008);
    try testing.expectEqual(@as(i32, 1), result);
}

test "decodeRelative7 negative" {
    const result = decodeRelative7(0xf078);
    try testing.expectEqual(@as(i32, -1), result);
}

test "decodeDisplacement" {
    const result = decodeDisplacement(0x8000);
    try testing.expectEqual(@as(u16, 0), result);
}

test "decodeDisplacement max" {
    const result = decodeDisplacement(0x23ff);
    try testing.expectEqual(@as(u16, 63), result);
}

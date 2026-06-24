const cpu_mod = @import("cpu.zig");
const memory = @import("../memory/memory.zig");
const constants = @import("../constants/constants.zig");
const std = @import("std");
const testing = std.testing;

const Cpu = cpu_mod.Cpu;

fn makeFlash() memory.Flash {
    return memory.Flash{};
}

fn makeCpu(flash: *const memory.Flash) Cpu {
    return Cpu.init(flash);
}

fn writeOpcode(flash: *memory.Flash, word_address: usize, opcode: u16) !void {
    const byte_addr = word_address * 2;
    try flash.writeByte(byte_addr, @as(u8, @intCast(opcode & 0xff)));
    try flash.writeByte(byte_addr + 1, @as(u8, @intCast((opcode >> 8) & 0xff)));
}

test "cpu init" {
    var flash = makeFlash();
    const cpu = makeCpu(&flash);
    try testing.expectEqual(@as(u32, 0), cpu.pc);
    try testing.expectEqual(@as(u16, constants.Sram.end), cpu.sp);
    try testing.expectEqual(@as(u8, 0), cpu.sreg);
    try testing.expectEqual(@as(u64, 0), cpu.cycles);
    try testing.expectEqual(false, cpu.trace);
}

test "NOP" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.nop);
    var cpu = makeCpu(&flash);

    try cpu.step();
    try testing.expectEqual(@as(u32, 1), cpu.pc);
    try testing.expectEqual(constants.Cycles.nop, cpu.cycles);
}

test "LDI r16 0x42" {
    var flash = makeFlash();
    const opcode = constants.Opcode.ldi_pattern | ((16 - constants.Ldi.register_base) << 4) | 0x02 | (0x04 << 8);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x42), cpu.r[16]);
    try testing.expectEqual(@as(u32, 1), cpu.pc);
}

test "LDI r31 0xff" {
    var flash = makeFlash();
    const reg_index: u16 = 31;
    const opcode = constants.Opcode.ldi_pattern | ((reg_index - constants.Ldi.register_base) << 4) | 0x0f | (0x0f << 8);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);

    try cpu.step();
    try testing.expectEqual(@as(u8, 0xff), cpu.r[31]);
}

test "MOV r0 r1" {
    var flash = makeFlash();
    const opcode = constants.Opcode.mov_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[1] = 0xab;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0xab), cpu.r[0]);
    try testing.expectEqual(@as(u8, 0xab), cpu.r[1]);
}

test "MOVW r0:r1 r2:r3" {
    var flash = makeFlash();
    const opcode = constants.Opcode.movw_pattern | (0 << 3) | 1;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[2] = 0x34;
    cpu.r[3] = 0x12;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x34), cpu.r[0]);
    try testing.expectEqual(@as(u8, 0x12), cpu.r[1]);
}

test "ADD r0 r1" {
    var flash = makeFlash();
    const opcode = constants.Opcode.add_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x05;
    cpu.r[1] = 0x03;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x08), cpu.r[0]);
    try testing.expectEqual(@as(u8, 0x03), cpu.r[1]);
    try testing.expectEqual(false, cpu.getFlag(constants.Sreg.z));
    try testing.expectEqual(false, cpu.getFlag(constants.Sreg.c));
    try testing.expectEqual(false, cpu.getFlag(constants.Sreg.v));
}

test "ADD with zero result sets Z flag" {
    var flash = makeFlash();
    const opcode = constants.Opcode.add_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x80;
    cpu.r[1] = 0x80;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x00), cpu.r[0]);
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.z));
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.c));
}

test "ADD with carry" {
    var flash = makeFlash();
    const opcode = constants.Opcode.add_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0xff;
    cpu.r[1] = 0x01;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x00), cpu.r[0]);
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.c));
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.z));
}

test "ADC with carry flag set" {
    var flash = makeFlash();
    const opcode = constants.Opcode.adc_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x05;
    cpu.r[1] = 0x03;
    cpu.setFlag(constants.Sreg.c, true);

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x09), cpu.r[0]);
}

test "ADC with carry flag clear" {
    var flash = makeFlash();
    const opcode = constants.Opcode.adc_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x05;
    cpu.r[1] = 0x03;
    cpu.setFlag(constants.Sreg.c, false);

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x08), cpu.r[0]);
}

test "SUB r0 r1" {
    var flash = makeFlash();
    const opcode = constants.Opcode.sub_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x08;
    cpu.r[1] = 0x03;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x05), cpu.r[0]);
    try testing.expectEqual(false, cpu.getFlag(constants.Sreg.z));
}

test "SUB zero result" {
    var flash = makeFlash();
    const opcode = constants.Opcode.sub_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x05;
    cpu.r[1] = 0x05;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x00), cpu.r[0]);
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.z));
}

test "SBC with carry flag set" {
    var flash = makeFlash();
    const opcode = constants.Opcode.sbc_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x08;
    cpu.r[1] = 0x03;
    cpu.setFlag(constants.Sreg.c, true);

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x04), cpu.r[0]);
}

test "AND r0 r1" {
    var flash = makeFlash();
    const opcode = constants.Opcode.and_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0xf0;
    cpu.r[1] = 0x0f;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x00), cpu.r[0]);
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.z));
}

test "OR r0 r1" {
    var flash = makeFlash();
    const opcode = constants.Opcode.or_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x0f;
    cpu.r[1] = 0xf0;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0xff), cpu.r[0]);
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.n));
}

test "EOR r0 r0 (CLR)" {
    var flash = makeFlash();
    const opcode = constants.Opcode.eor_pattern | (0 << 4) | 0;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x55;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x00), cpu.r[0]);
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.z));
}

test "EOR r0 r1" {
    var flash = makeFlash();
    const opcode = constants.Opcode.eor_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0xaa;
    cpu.r[1] = 0x55;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0xff), cpu.r[0]);
}

test "INC r0" {
    var flash = makeFlash();
    const opcode = constants.Opcode.inc_pattern | (0 << 4);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x05;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x06), cpu.r[0]);
    try testing.expectEqual(false, cpu.getFlag(constants.Sreg.z));
}

test "INC overflow to zero" {
    var flash = makeFlash();
    const opcode = constants.Opcode.inc_pattern | (0 << 4);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0xff;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x00), cpu.r[0]);
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.z));
}

test "INC from 0x7f sets V flag" {
    var flash = makeFlash();
    const opcode = constants.Opcode.inc_pattern | (0 << 4);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x7f;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x80), cpu.r[0]);
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.v));
}

test "DEC r0" {
    var flash = makeFlash();
    const opcode = constants.Opcode.dec_pattern | (0 << 4);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x05;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x04), cpu.r[0]);
}

test "DEC to zero" {
    var flash = makeFlash();
    const opcode = constants.Opcode.dec_pattern | (0 << 4);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x01;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x00), cpu.r[0]);
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.z));
}

test "COM r0" {
    var flash = makeFlash();
    const opcode = constants.Opcode.com_pattern | (0 << 4);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x55;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0xaa), cpu.r[0]);
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.c));
}

test "CPI sets flags only" {
    var flash = makeFlash();
    const reg_index: u16 = 16;
    const opcode = constants.Opcode.cpi_pattern | ((reg_index - constants.Immediate.register_base) << 4) | 0x05;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[reg_index] = 0x05;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x05), cpu.r[reg_index]);
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.z));
}

test "SUBI r16 0x01" {
    var flash = makeFlash();
    const reg_index: u16 = 16;
    const opcode = constants.Opcode.subi_pattern | ((reg_index - constants.Immediate.register_base) << 4) | 0x01;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[reg_index] = 0x05;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x04), cpu.r[reg_index]);
}

test "SBCI with carry" {
    var flash = makeFlash();
    const reg_index: u16 = 16;
    const opcode = constants.Opcode.sbci_pattern | ((reg_index - constants.Immediate.register_base) << 4) | 0x01;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[reg_index] = 0x05;
    cpu.setFlag(constants.Sreg.c, true);

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x03), cpu.r[reg_index]);
}

test "ORI r16 0x0f" {
    var flash = makeFlash();
    const reg_index: u16 = 16;
    const opcode = constants.Opcode.ori_pattern | ((reg_index - constants.Immediate.register_base) << 4) | 0x0f;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[reg_index] = 0xf0;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0xff), cpu.r[reg_index]);
}

test "ANDI r16 0x0f" {
    var flash = makeFlash();
    const reg_index: u16 = 16;
    const opcode = constants.Opcode.andi_pattern | ((reg_index - constants.Immediate.register_base) << 4) | 0x0f;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[reg_index] = 0xff;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x0f), cpu.r[reg_index]);
}

test "ADIW r24:r25 0x10" {
    var flash = makeFlash();
    const reg_index: u16 = 24;
    const value: u16 = 0x10;
    const imm_low = value & constants.WordImmediate.imm_low_mask;
    const imm_high = (value & 0x30) << 2;
    const opcode = constants.Opcode.adiw_pattern | ((reg_index - constants.WordImmediate.register_base) << constants.WordImmediate.register_shift) | imm_low | imm_high;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[24] = 0x10;
    cpu.r[25] = 0x00;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x20), cpu.r[24]);
    try testing.expectEqual(@as(u8, 0x00), cpu.r[25]);
}

test "SBIW r24:r25" {
    var flash = makeFlash();
    const reg_index: u16 = 24;
    const opcode = constants.Opcode.sbiw_pattern | ((reg_index - constants.WordImmediate.register_base) << constants.WordImmediate.register_shift) | 0x01;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[24] = 0x10;
    cpu.r[25] = 0x00;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x0f), cpu.r[24]);
    try testing.expectEqual(@as(u8, 0x00), cpu.r[25]);
}

test "CP equal sets Z flag" {
    var flash = makeFlash();
    const opcode = constants.Opcode.cp_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x42;
    cpu.r[1] = 0x42;

    try cpu.step();
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.z));
}

test "CPC with carry preserves Z" {
    var flash = makeFlash();
    const opcode = constants.Opcode.cpc_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x01;
    cpu.r[1] = 0x00;
    cpu.setFlag(constants.Sreg.z, true);
    cpu.setFlag(constants.Sreg.c, true);

    try cpu.step();
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.z));
}

test "CPSE skip equal" {
    var flash = makeFlash();
    const opcode = constants.Opcode.cpse_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    try writeOpcode(&flash, 1, constants.Opcode.nop);
    try writeOpcode(&flash, 2, constants.Opcode.nop);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x42;
    cpu.r[1] = 0x42;

    try cpu.step();
    try testing.expectEqual(@as(u32, 2), cpu.pc);
}

test "CPSE skip not equal" {
    var flash = makeFlash();
    const opcode = constants.Opcode.cpse_pattern | (0 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    try writeOpcode(&flash, 1, constants.Opcode.nop);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x42;
    cpu.r[1] = 0x43;

    try cpu.step();
    try testing.expectEqual(@as(u32, 1), cpu.pc);
}

test "BRNE taken" {
    var flash = makeFlash();
    const offset: u16 = 5;
    const opcode = constants.Opcode.brne_pattern | ((offset << constants.Branch.offset_shift) & constants.Branch.offset_mask);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.setFlag(constants.Sreg.z, false);

    try cpu.step();
    try testing.expectEqual(@as(u32, 1 + 5), cpu.pc);
    try testing.expectEqual(constants.Cycles.branch_taken, cpu.cycles);
}

test "BRNE not taken" {
    var flash = makeFlash();
    const offset: u16 = 5;
    const opcode = constants.Opcode.brne_pattern | ((offset << constants.Branch.offset_shift) & constants.Branch.offset_mask);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.setFlag(constants.Sreg.z, true);

    try cpu.step();
    try testing.expectEqual(@as(u32, 1), cpu.pc);
    try testing.expectEqual(constants.Cycles.branch_not_taken, cpu.cycles);
}

test "BREQ taken" {
    var flash = makeFlash();
    const offset: u16 = 3;
    const opcode = constants.Opcode.breq_pattern | ((offset << constants.Branch.offset_shift) & constants.Branch.offset_mask);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.setFlag(constants.Sreg.z, true);

    try cpu.step();
    try testing.expectEqual(@as(u32, 1 + 3), cpu.pc);
}

test "BRCC taken" {
    var flash = makeFlash();
    const offset: u16 = 2;
    const opcode = constants.Opcode.brcc_pattern | ((offset << constants.Branch.offset_shift) & constants.Branch.offset_mask);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.setFlag(constants.Sreg.c, false);

    try cpu.step();
    try testing.expectEqual(@as(u32, 1 + 2), cpu.pc);
}

test "BRCS taken" {
    var flash = makeFlash();
    const offset: u16 = 4;
    const opcode = constants.Opcode.brcs_pattern | ((offset << constants.Branch.offset_shift) & constants.Branch.offset_mask);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.setFlag(constants.Sreg.c, true);

    try cpu.step();
    try testing.expectEqual(@as(u32, 1 + 4), cpu.pc);
}

test "BRCS not taken" {
    var flash = makeFlash();
    const offset: u16 = 4;
    const opcode = constants.Opcode.brcs_pattern | ((offset << constants.Branch.offset_shift) & constants.Branch.offset_mask);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.setFlag(constants.Sreg.c, false);

    try cpu.step();
    try testing.expectEqual(@as(u32, 1), cpu.pc);
}

test "RJMP forward" {
    var flash = makeFlash();
    const offset: u16 = 10;
    const opcode = constants.Opcode.rjmp_pattern | offset;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);

    try cpu.step();
    try testing.expectEqual(@as(u32, 1 + 10), cpu.pc);
    try testing.expectEqual(constants.Cycles.rjmp, cpu.cycles);
}

test "RJMP backward" {
    var flash = makeFlash();
    const negative: u16 = 0x0ffe;
    const opcode = constants.Opcode.rjmp_pattern | negative;
    try writeOpcode(&flash, 10, opcode);
    var cpu = makeCpu(&flash);
    cpu.pc = 10;

    try cpu.step();
    try testing.expectEqual(@as(u32, 9), cpu.pc);
}

test "JMP absolute" {
    var flash = makeFlash();
    const opcode = constants.Opcode.jmp_pattern | 0x0100;
    const target: u16 = 0xabcd;
    try writeOpcode(&flash, 0, opcode);
    try writeOpcode(&flash, 1, target);
    var cpu = makeCpu(&flash);

    try cpu.step();
    try testing.expectEqual(constants.Cycles.jmp, cpu.cycles);
}

test "RCALL and RET" {
    var flash = makeFlash();
    const offset: u16 = 3;
    const rcall_opcode = constants.Opcode.rcall_pattern | offset;
    try writeOpcode(&flash, 0, rcall_opcode);
    try writeOpcode(&flash, 1 + 3, constants.Opcode.ret);
    var cpu = makeCpu(&flash);

    try cpu.step();
    try testing.expectEqual(@as(u32, 1 + 3), cpu.pc);
    try testing.expectEqual(constants.Cycles.rcall, cpu.cycles);

    try cpu.step();
    try testing.expectEqual(@as(u32, 1), cpu.pc);
    try testing.expectEqual(constants.Cycles.rcall + constants.Cycles.ret, cpu.cycles);
}

test "CALL and RET" {
    var flash = makeFlash();
    const target: u16 = 5;
    try writeOpcode(&flash, 0, constants.Opcode.call_pattern);
    try writeOpcode(&flash, 1, target);
    try writeOpcode(&flash, target, constants.Opcode.ret);
    var cpu = makeCpu(&flash);

    try cpu.step();
    try testing.expect(cpu.cycles > 0);

    try cpu.step();
    try testing.expectEqual(@as(u32, 2), cpu.pc);
}

test "SEI and CLI" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.sei);
    try writeOpcode(&flash, 1, constants.Opcode.cli);
    var cpu = makeCpu(&flash);

    try cpu.step();
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.i));

    try cpu.step();
    try testing.expectEqual(false, cpu.getFlag(constants.Sreg.i));
}

test "RETI restores I flag" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.reti);
    var cpu = makeCpu(&flash);
    cpu.sp = constants.Sram.end - 2;
    cpu.sram[cpu.sp + 1] = 0x0a;
    cpu.sram[cpu.sp + 2] = 0x00;

    try cpu.step();
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.i));
    try testing.expectEqual(@as(u32, 0x000a), cpu.pc);
}

test "PUSH and POP" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.push_pattern | (5 << 4));
    try writeOpcode(&flash, 1, constants.Opcode.pop_pattern | (10 << 4));
    var cpu = makeCpu(&flash);
    cpu.r[5] = 0x42;

    try cpu.step();
    try testing.expectEqual(constants.Sram.end - 1, cpu.sp);
    try testing.expectEqual(@as(u8, 0x42), cpu.sram[constants.Sram.end]);

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x42), cpu.r[10]);
    try testing.expectEqual(constants.Sram.end, cpu.sp);
}

test "IN and OUT" {
    var flash = makeFlash();
    const io_addr: u16 = constants.Io.portb;
    const out_opcode = constants.Opcode.out_pattern | (10 << 4) | (io_addr & 0x000f) | ((io_addr & 0x0030) << 5);
    const in_opcode = constants.Opcode.in_pattern | (5 << 4) | (io_addr & 0x000f) | ((io_addr & 0x0030) << 5);
    try writeOpcode(&flash, 0, out_opcode);
    try writeOpcode(&flash, 1, in_opcode);
    var cpu = makeCpu(&flash);
    cpu.r[10] = 0x55;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x55), cpu.io[io_addr]);

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x55), cpu.r[5]);
}

test "SBI and CBI" {
    var flash = makeFlash();
    const io_addr: u16 = constants.Io.portb;
    const sbi_opcode = constants.Opcode.sbi_pattern | ((io_addr & 0x1f) << 3) | 2;
    const cbi_opcode = constants.Opcode.cbi_pattern | ((io_addr & 0x1f) << 3) | 2;
    try writeOpcode(&flash, 0, sbi_opcode);
    try writeOpcode(&flash, 1, cbi_opcode);
    var cpu = makeCpu(&flash);

    try cpu.step();
    try testing.expectEqual(@as(u8, 1 << 2), cpu.io[io_addr]);

    try cpu.step();
    try testing.expectEqual(@as(u8, 0), cpu.io[io_addr]);
}

test "SBIS skip when bit set" {
    var flash = makeFlash();
    const io_addr: u16 = constants.Io.portb;
    const opcode = constants.Opcode.sbis_pattern | ((io_addr & 0x1f) << 3) | 3;
    try writeOpcode(&flash, 0, opcode);
    try writeOpcode(&flash, 1, constants.Opcode.nop);
    try writeOpcode(&flash, 2, constants.Opcode.nop);
    var cpu = makeCpu(&flash);
    cpu.io[io_addr] = 1 << 3;

    try cpu.step();
    try testing.expectEqual(@as(u32, 2), cpu.pc);
}

test "SBIS not skip when bit clear" {
    var flash = makeFlash();
    const io_addr: u16 = constants.Io.portb;
    const opcode = constants.Opcode.sbis_pattern | ((io_addr & 0x1f) << 3) | 3;
    try writeOpcode(&flash, 0, opcode);
    try writeOpcode(&flash, 1, constants.Opcode.nop);
    var cpu = makeCpu(&flash);
    cpu.io[io_addr] = 0;

    try cpu.step();
    try testing.expectEqual(@as(u32, 1), cpu.pc);
}

test "LDS and STS" {
    var flash = makeFlash();
    const sram_addr: u16 = 0x0200;
    try writeOpcode(&flash, 0, constants.Opcode.sts_pattern | (5 << 4));
    try writeOpcode(&flash, 1, sram_addr);
    try writeOpcode(&flash, 2, constants.Opcode.lds_pattern | (10 << 4));
    try writeOpcode(&flash, 3, sram_addr);
    var cpu = makeCpu(&flash);
    cpu.r[5] = 0x77;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x77), cpu.sram[sram_addr]);

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x77), cpu.r[10]);
}

test "LD X (no displacement)" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.ld_x_pattern | (0 << 4));
    var cpu = makeCpu(&flash);
    cpu.r[26] = 0x00;
    cpu.r[27] = 0x02;
    cpu.sram[0x0200] = 0xab;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0xab), cpu.r[0]);
}

test "LD X+ (post-increment)" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.ld_x_postincrement_pattern | (0 << 4));
    var cpu = makeCpu(&flash);
    cpu.r[26] = 0x00;
    cpu.r[27] = 0x02;
    cpu.sram[0x0200] = 0xcd;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0xcd), cpu.r[0]);
    try testing.expectEqual(@as(u8, 0x01), cpu.r[26]);
    try testing.expectEqual(@as(u8, 0x02), cpu.r[27]);
}

test "LD -X (pre-decrement)" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.ld_x_predecrement_pattern | (0 << 4));
    var cpu = makeCpu(&flash);
    cpu.r[26] = 0xff;
    cpu.r[27] = 0x01;
    cpu.sram[0x01fe] = 0xef;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0xef), cpu.r[0]);
    try testing.expectEqual(@as(u8, 0xfe), cpu.r[26]);
    try testing.expectEqual(@as(u8, 0x01), cpu.r[27]);
}

test "ST X (no displacement)" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.st_x_pattern | (5 << 4));
    var cpu = makeCpu(&flash);
    cpu.r[26] = 0xff;
    cpu.r[27] = 0x01;
    cpu.r[5] = 0x99;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x99), cpu.sram[0x01ff]);
}

test "ST X+ (post-increment)" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.st_x_postincrement_pattern | (5 << 4));
    var cpu = makeCpu(&flash);
    cpu.r[26] = 0x00;
    cpu.r[27] = 0x02;
    cpu.r[5] = 0x88;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x88), cpu.sram[0x0200]);
    try testing.expectEqual(@as(u8, 0x01), cpu.r[26]);
}

test "ST -X (pre-decrement)" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.st_x_predecrement_pattern | (5 << 4));
    var cpu = makeCpu(&flash);
    cpu.r[26] = 0x00;
    cpu.r[27] = 0x02;
    cpu.r[5] = 0xbb;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0xbb), cpu.sram[0x01ff]);
    try testing.expectEqual(@as(u8, 0xff), cpu.r[26]);
}

test "LD Z with displacement 0" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.ld_z_pattern | (0 << 4));
    var cpu = makeCpu(&flash);
    cpu.r[30] = 0xfb;
    cpu.r[31] = 0x01;
    cpu.sram[0x01fb] = 0xcc;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0xcc), cpu.r[0]);
}

test "ST Y with displacement 0" {
    var flash = makeFlash();
    const opcode = constants.Opcode.st_y_pattern | (5 << 4);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[28] = 0x00;
    cpu.r[29] = 0x02;
    cpu.r[5] = 0xdd;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0xdd), cpu.sram[0x0200]);
}

test "LPM implicit loads r0" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.lpm);
    try flash.writeByte(0x0200, 0x5a);
    var cpu = makeCpu(&flash);
    cpu.r[30] = 0x00;
    cpu.r[31] = 0x02;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x5a), cpu.r[0]);
}

test "LPM Z with post-increment" {
    var flash = makeFlash();
    const opcode = constants.Opcode.lpm_z_pattern | (3 << 4) | 1;
    try writeOpcode(&flash, 0, opcode);
    try flash.writeByte(0x0200, 0x5a);
    var cpu = makeCpu(&flash);
    cpu.r[30] = 0x00;
    cpu.r[31] = 0x02;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x5a), cpu.r[3]);
    try testing.expectEqual(@as(u8, 0x01), cpu.r[30]);
}

test "stack push and pop byte" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.push_pattern | (1 << 4));
    try writeOpcode(&flash, 1, constants.Opcode.pop_pattern | (2 << 4));
    var cpu = makeCpu(&flash);
    cpu.r[1] = 0x37;

    try cpu.step();
    const pushed_at = cpu.sram[constants.Sram.end];

    try cpu.step();
    try testing.expectEqual(@as(u8, pushed_at), cpu.r[2]);
}

test "stack underflow (pop on empty stack)" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.pop_pattern | (0 << 4));
    var cpu = makeCpu(&flash);
    cpu.sp = constants.Sram.end;

    try testing.expectError(error.StackPointerOutOfRange, cpu.step());
}

test "IO read/write via readData/writeData" {
    var flash = makeFlash();
    var cpu = makeCpu(&flash);
    const io_data_addr = constants.Data.portb;

    try cpu.writeData(io_data_addr, 0x42);
    try testing.expectEqual(@as(u8, 0x42), try cpu.readData(io_data_addr));
    try testing.expectEqual(@as(u8, 0x42), cpu.io[constants.Io.portb]);
}

test "writeData to IO via writeIo triggers timer" {
    var flash = makeFlash();
    var cpu = makeCpu(&flash);
    const io_data_addr = constants.Data.tccr0b;

    try cpu.writeData(io_data_addr, constants.Timer0.Tccr0b.prescale_64);
    try testing.expectEqual(constants.Timer0.Tccr0b.prescale_64, cpu.timer0.tccr0b);
}

test "readData from timer registers" {
    var flash = makeFlash();
    var cpu = makeCpu(&flash);
    cpu.timer0.tcnt0 = 0x80;

    try testing.expectEqual(@as(u8, 0x80), try cpu.readData(constants.Data.tcnt0));
}

test "sreg read/write via io" {
    var flash = makeFlash();
    const opcode = constants.Opcode.out_pattern | (0 << 4) | (constants.Io.sreg & 0x000f) | ((constants.Io.sreg & 0x0030) << 5);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.r[0] = 0x80;

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x80), cpu.sreg);
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.i));
}

test "setFlag and getFlag" {
    var flash = makeFlash();
    var cpu = makeCpu(&flash);

    try testing.expectEqual(false, cpu.getFlag(constants.Sreg.z));
    cpu.setFlag(constants.Sreg.z, true);
    try testing.expectEqual(true, cpu.getFlag(constants.Sreg.z));
    cpu.setFlag(constants.Sreg.z, false);
    try testing.expectEqual(false, cpu.getFlag(constants.Sreg.z));
}

test "readRegisterWord and writeRegisterWord" {
    var flash = makeFlash();
    var cpu = makeCpu(&flash);
    cpu.r[26] = 0x34;
    cpu.r[27] = 0x12;
    try testing.expectEqual(@as(u16, 0x1234), cpu.readRegisterWord(26));

    cpu.writeRegisterWord(28, 0xabcd);
    try testing.expectEqual(@as(u8, 0xcd), cpu.r[28]);
    try testing.expectEqual(@as(u8, 0xab), cpu.r[29]);
}

test "decodeAbsolute22" {
    const target: u16 = 0x0005;
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.call_pattern);
    try writeOpcode(&flash, 1, target);
    try writeOpcode(&flash, target, constants.Opcode.ret);
    var cpu = makeCpu(&flash);

    try cpu.step();
    try testing.expectEqual(@as(u32, target), cpu.pc);
}

test "decodeRelative12 positive" {
    var flash = makeFlash();
    const offset: u16 = 0x0005;
    const opcode = constants.Opcode.rjmp_pattern | offset;
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);

    try cpu.step();
    try testing.expectEqual(@as(u32, 1 + 5), cpu.pc);
}

test "decodeRelative12 negative" {
    var flash = makeFlash();
    const offset: u16 = 0x0ffe;
    const opcode = constants.Opcode.rjmp_pattern | offset;
    try writeOpcode(&flash, 10, opcode);
    var cpu = makeCpu(&flash);
    cpu.pc = 10;

    try cpu.step();
    try testing.expectEqual(@as(u32, 10 + 1 - 2), cpu.pc);
}

test "decodeRelative7 positive" {
    var flash = makeFlash();
    const offset: u16 = 3;
    const opcode = constants.Opcode.brne_pattern | ((offset << constants.Branch.offset_shift) & constants.Branch.offset_mask);
    try writeOpcode(&flash, 0, opcode);
    var cpu = makeCpu(&flash);
    cpu.setFlag(constants.Sreg.z, false);

    try cpu.step();
    try testing.expectEqual(@as(u32, 1 + 3), cpu.pc);
}

test "isTwoWordInstruction CALL" {
    try testing.expectEqual(true, Cpu.isTwoWordInstruction(constants.Opcode.call_pattern));
    try testing.expectEqual(true, Cpu.isTwoWordInstruction(constants.Opcode.jmp_pattern));
    try testing.expectEqual(true, Cpu.isTwoWordInstruction(constants.Opcode.lds_pattern | (0 << 4)));
    try testing.expectEqual(true, Cpu.isTwoWordInstruction(constants.Opcode.sts_pattern | (0 << 4)));
    try testing.expectEqual(false, Cpu.isTwoWordInstruction(constants.Opcode.nop));
    try testing.expectEqual(false, Cpu.isTwoWordInstruction(constants.Opcode.ldi_pattern));
}

test "unknown opcode returns error" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, 0xaaaa);
    var cpu = makeCpu(&flash);

    try testing.expectError(error.UnimplementedOpcode, cpu.step());
}

test "io read/write out of range" {
    var flash = makeFlash();
    var cpu = makeCpu(&flash);

    try testing.expectError(error.IoAddressOutOfRange, cpu.writeIo(constants.Io.size, 0x00));
    try testing.expectError(error.IoAddressOutOfRange, cpu.readIo(constants.Io.size));
}

test "timer0 tick called after instruction" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.nop);
    var cpu = makeCpu(&flash);
    cpu.timer0.tccr0b = constants.Timer0.Tccr0b.prescale_1;

    try cpu.step();
    try testing.expectEqual(@as(u8, 1), cpu.timer0.tcnt0);
}

test "timer0 overflow triggers interrupt" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.sei);
    try writeOpcode(&flash, 1, constants.Opcode.nop);
    var cpu = makeCpu(&flash);
    cpu.timer0.tccr0b = constants.Timer0.Tccr0b.prescale_1;
    cpu.timer0.tcnt0 = 0xff;
    cpu.timer0.timsk0 |= @as(u8, 1) << constants.Timer0.Timsk0.toie0;

    try cpu.step();
    try testing.expectEqual(constants.InterruptVector.timer0_ovf_word, cpu.pc);
    try testing.expectEqual(false, cpu.getFlag(constants.Sreg.i));
}

test "timer0 interrupt not taken when disabled" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.nop);
    var cpu = makeCpu(&flash);
    cpu.timer0.tccr0b = constants.Timer0.Tccr0b.prescale_1;
    cpu.timer0.tcnt0 = 0xff;
    cpu.timer0.timsk0 |= @as(u8, 1) << constants.Timer0.Timsk0.toie0;

    try cpu.step();
    try testing.expectEqual(@as(u32, 1), cpu.pc);
}

test "handlePinSideEffects DDRB output" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.sei);
    var cpu = makeCpu(&flash);
    cpu.quiet = true;

    try cpu.writeIo(constants.Io.ddrb, constants.Io.pb5_mask);
}

test "handlePinSideEffects PORTB high when output" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.sei);
    var cpu = makeCpu(&flash);
    cpu.quiet = true;
    cpu.io[constants.Io.ddrb] = constants.Io.pb5_mask;

    try cpu.writeIo(constants.Io.portb, constants.Io.pb5_mask);
}

test "handlePinSideEffects PORTB ignored when input" {
    var flash = makeFlash();
    try writeOpcode(&flash, 0, constants.Opcode.sei);
    var cpu = makeCpu(&flash);
    cpu.quiet = true;
    cpu.io[constants.Io.ddrb] = 0x00;

    try cpu.writeIo(constants.Io.portb, constants.Io.pb5_mask);
}

test "multiple instructions in sequence" {
    var flash = makeFlash();

    const op1 = constants.Opcode.ldi_pattern | ((16 - constants.Ldi.register_base) << 4) | 0x0a | (0x02 << 8);
    const op2 = constants.Opcode.ldi_pattern | ((17 - constants.Ldi.register_base) << 4) | 0x03;
    const op3 = constants.Opcode.add_pattern | (16 << 4) | (17 & 0x0f) | (((17 >> 4) & 1) << 9);

    try writeOpcode(&flash, 0, op1);
    try writeOpcode(&flash, 1, op2);
    try writeOpcode(&flash, 2, op3);

    try testing.expectEqual(op1, try flash.readWord(0));
    try testing.expectEqual(op2, try flash.readWord(1));
    try testing.expectEqual(op3, try flash.readWord(2));

    var cpu = makeCpu(&flash);

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x2a), cpu.r[16]);

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x03), cpu.r[17]);

    try cpu.step();
    try testing.expectEqual(@as(u8, 0x2d), cpu.r[16]);
    try testing.expectEqual(@as(u32, 3), cpu.pc);
}

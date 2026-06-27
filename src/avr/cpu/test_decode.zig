const decode = @import("decode.zig");

const testing = @import("std").testing;

test "decode NOP" {
    try testing.expect(decode.decode(0x0000) != null);
}

test "decode RJMP" {
    try testing.expect(decode.decode(0xc000) != null);
    try testing.expect(decode.decode(0xcfff) != null);
}

test "decode unknown returns null" {
    try testing.expect(decode.decode(0xffff) == null);
}

test "decode BRNE" {
    try testing.expect(decode.decode(0xf401) != null);
}

test "decode BREQ" {
    try testing.expect(decode.decode(0xf001) != null);
}

test "decode LDI" {
    const opcode: u16 = 0xef0f;
    try testing.expect(decode.decode(opcode) != null);
    try testing.expectEqual(@as(usize, 16), decode.decodeImmediateRegister(opcode));
    try testing.expectEqual(@as(u8, 0xff), decode.decodeImmediate(opcode));
}

test "decode LDI r26=0xfa" {
    const opcode: u16 = 0xefaa;
    try testing.expectEqual(@as(usize, 26), decode.decodeImmediateRegister(opcode));
    try testing.expectEqual(@as(u8, 0xfa), decode.decodeImmediate(opcode));
}

test "decode OUT" {
    const opcode: u16 = 0xb905;
    try testing.expect(decode.decode(opcode) != null);
    try testing.expectEqual(@as(usize, 0x05), decode.decodeIoAddress(opcode));
    try testing.expectEqual(@as(usize, 16), decode.decodeIoRegister(opcode));
}

test "decode IN" {
    const opcode: u16 = 0xb103;
    try testing.expect(decode.decode(opcode) != null);
    try testing.expectEqual(@as(usize, 0x03), decode.decodeIoAddress(opcode));
    try testing.expectEqual(@as(usize, 16), decode.decodeIoRegister(opcode));
}

test "decode SBI" {
    const opcode: u16 = 0x9a2d;
    try testing.expect(decode.decode(opcode) != null);
    try testing.expectEqual(@as(usize, 0x05), decode.decodeBitIoAddress(opcode));
    try testing.expectEqual(@as(u3, 5), decode.decodeBitIoBit(opcode));
}

test "decode CBI" {
    try testing.expect(decode.decode(0x982d) != null);
}

test "decode ADD" {
    const opcode: u16 = 0x0c01;
    try testing.expect(decode.decode(opcode) != null);
    try testing.expectEqual(@as(usize, 0), decode.decodeDestinationRegister(opcode));
    try testing.expectEqual(@as(usize, 1), decode.decodeSourceRegister(opcode));
}

test "decode ADC" {
    try testing.expect(decode.decode(0x1c34) != null);
}

test "decode SUB" {
    try testing.expect(decode.decode(0x1812) != null);
}

test "decode SUBI" {
    try testing.expect(decode.decode(0x5001) != null);
}

test "decode SBCI" {
    try testing.expect(decode.decode(0x40ff) != null);
}

test "decode MOV" {
    try testing.expect(decode.decode(0x2c01) != null);
}

test "decode INC r0" {
    try testing.expect(decode.decode(0x9403) != null);
    try testing.expectEqual(@as(usize, 0), decode.decodeSingleRegister(0x9403));
}

test "decode INC r17" {
    try testing.expectEqual(@as(usize, 17), decode.decodeSingleRegister(0x9513));
}

test "decode DEC" {
    try testing.expect(decode.decode(0x940a) != null);
}

test "decode PUSH" {
    try testing.expect(decode.decode(0x920f) != null);
}

test "decode POP" {
    try testing.expect(decode.decode(0x900f) != null);
}

test "decode CALL" {
    try testing.expect(decode.decode(0x940e) != null);
}

test "decode JMP" {
    try testing.expect(decode.decode(0x940c) != null);
}

test "decode RCALL" {
    try testing.expect(decode.decode(0xd000) != null);
}

test "decode ADIW r30=0x0f" {
    const opcode: u16 = 0x963f;
    try testing.expect(decode.decode(opcode) != null);
    try testing.expectEqual(@as(usize, 30), decode.decodeWordImmediateRegister(opcode));
    try testing.expectEqual(@as(u16, 0x0f), decode.decodeWordImmediate(opcode));
}

test "decode SBIW" {
    try testing.expect(decode.decode(0x973f) != null);
}

test "decode CPI" {
    try testing.expect(decode.decode(0x30ff) != null);
}

test "decode CP" {
    try testing.expect(decode.decode(0x1401) != null);
}

test "decode CPC" {
    try testing.expect(decode.decode(0x0401) != null);
}

test "decode EOR" {
    try testing.expect(decode.decode(0x2401) != null);
}

test "decode AND" {
    try testing.expect(decode.decode(0x2001) != null);
}

test "decode OR" {
    try testing.expect(decode.decode(0x2801) != null);
}

test "decode ORI" {
    try testing.expect(decode.decode(0x60ff) != null);
}

test "decode ANDI" {
    try testing.expect(decode.decode(0x70ff) != null);
}

test "decode MOVW" {
    const opcode: u16 = 0x0101;
    try testing.expect(decode.decode(opcode) != null);
    try testing.expectEqual(@as(usize, 0), decode.decodeMovwDestination(opcode));
    try testing.expectEqual(@as(usize, 2), decode.decodeMovwSource(opcode));
}

test "decode MUL" {
    try testing.expect(decode.decode(0x9c01) != null);
}

test "decode MULS" {
    try testing.expect(decode.decode(0x0200) != null);
}

test "decode MULSU" {
    try testing.expect(decode.decode(0x0300) != null);
}

test "decode LDS" {
    try testing.expect(decode.decode(0x9000) != null);
}

test "decode STS" {
    try testing.expect(decode.decode(0x9200) != null);
}

test "decode SWAP" {
    try testing.expect(decode.decode(0x9402) != null);
}

test "decode LSR" {
    try testing.expect(decode.decode(0x9406) != null);
}

test "decode ROR" {
    try testing.expect(decode.decode(0x9407) != null);
}

test "decode ASR" {
    try testing.expect(decode.decode(0x9405) != null);
}

test "decode COM" {
    try testing.expect(decode.decode(0x9400) != null);
}

test "decode NEG" {
    try testing.expect(decode.decode(0x9401) != null);
}

test "decode BSET" {
    try testing.expect(decode.decode(0x9408) != null);
}

test "decode BCLR" {
    try testing.expect(decode.decode(0x9488) != null);
}

test "decode SBRC" {
    try testing.expect(decode.decode(0xfc00) != null);
}

test "decode SBRS" {
    try testing.expect(decode.decode(0xfe00) != null);
}

test "decode BST" {
    try testing.expect(decode.decode(0xfa00) != null);
}

test "decode BLD" {
    try testing.expect(decode.decode(0xf800) != null);
}

test "decode SLEEP" {
    try testing.expect(decode.decode(0x9588) != null);
}

test "decode WDR" {
    try testing.expect(decode.decode(0x95a8) != null);
}

test "decode BREAK" {
    try testing.expect(decode.decode(0x9598) != null);
}

test "decode LPM" {
    try testing.expect(decode.decode(0x95c8) != null);
}

test "decode ELPM Z" {
    try testing.expect(decode.decode(0x9006) != null);
}

test "decode ELPM Z+" {
    try testing.expect(decode.decode(0x9007) != null);
}

test "decode ICALL" {
    try testing.expect(decode.decode(0x9509) != null);
}

test "decode IJMP" {
    try testing.expect(decode.decode(0x9409) != null);
}

test "decode EICALL" {
    try testing.expect(decode.decode(0x9519) != null);
}

test "decode EIJMP" {
    try testing.expect(decode.decode(0x9419) != null);
}

test "isTwoWordInstruction CALL" {
    try testing.expect(decode.isTwoWordInstruction(0x940e));
}

test "isTwoWordInstruction JMP" {
    try testing.expect(decode.isTwoWordInstruction(0x940c));
}

test "isTwoWordInstruction LDS" {
    try testing.expect(decode.isTwoWordInstruction(0x9000));
}

test "isTwoWordInstruction STS" {
    try testing.expect(decode.isTwoWordInstruction(0x9200));
}

test "isTwoWordInstruction NOP is single" {
    try testing.expect(!decode.isTwoWordInstruction(0x0000));
}

test "isTwoWordInstruction RJMP is single" {
    try testing.expect(!decode.isTwoWordInstruction(0xc000));
}

test "bitMask" {
    try testing.expectEqual(@as(u8, 0x01), decode.bitMask(0));
    try testing.expectEqual(@as(u8, 0x02), decode.bitMask(1));
    try testing.expectEqual(@as(u8, 0x80), decode.bitMask(7));
}

test "decodeAbsolute22" {
    const result = decode.decodeAbsolute22(0x940c, 0x1234);
    try testing.expectEqual(@as(u32, 0x1234), result);
}

test "decodeRelative12 positive" {
    try testing.expectEqual(@as(i32, 5), decode.decodeRelative12(0xc005));
}

test "decodeRelative12 negative" {
    try testing.expectEqual(@as(i32, -1), decode.decodeRelative12(0xcfff));
}

test "decodeRelative7 positive" {
    try testing.expectEqual(@as(i32, 1), decode.decodeRelative7(0xf008));
}

test "decodeRelative7 negative" {
    try testing.expectEqual(@as(i32, -1), decode.decodeRelative7(0xf7f9));
}

test "decodeDisplacement zero" {
    try testing.expectEqual(@as(u16, 0), decode.decodeDisplacement(0x8000));
}

test "decodeDisplacement max" {
    try testing.expectEqual(@as(u16, 63), decode.decodeDisplacement(0x3c07));
}

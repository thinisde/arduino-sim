const memory = @import("memory.zig");
const constants = @import("../constants/constants.zig");
const testing = @import("std").testing;

test "flash initial state is erased" {
    const flash = memory.Flash{};
    try testing.expectEqual(constants.Flash.erased_byte, flash.bytes[0]);
    try testing.expectEqual(constants.Flash.erased_byte, flash.bytes[memory.FlashSize - 1]);
}

test "flash writeByte and readByte" {
    var flash = memory.Flash{};
    try flash.writeByte(0x0040, 0x0c);
    try flash.writeByte(0x0041, 0x94);
    try testing.expectEqual(@as(u8, 0x0c), try flash.readByte(0x0040));
    try testing.expectEqual(@as(u8, 0x94), try flash.readByte(0x0041));
}

test "flash readWord little-endian" {
    var flash = memory.Flash{};
    try flash.writeByte(0x0100, 0x34);
    try flash.writeByte(0x0101, 0x12);
    try testing.expectEqual(@as(u16, 0x1234), try flash.readWord(0x0080));
}

test "flash writeByte out of range" {
    var flash = memory.Flash{};
    try testing.expectError(error.FlashAddressOutOfRange, flash.writeByte(memory.FlashSize, 0x00));
}

test "flash readByte out of range" {
    var flash = memory.Flash{};
    try testing.expectError(error.FlashAddressOutOfRange, flash.readByte(memory.FlashSize));
}

test "flash readWord wraps to byte address correctly" {
    var flash = memory.Flash{};
    try flash.writeByte(0, 0x0c);
    try flash.writeByte(1, 0x94);
    try testing.expectEqual(@as(u16, 0x940c), try flash.readWord(0));
}

const std = @import("std");
const testing = std.testing;
const hex = @import("hex.zig");
const memory = @import("../avr/memory/memory.zig");

const sample1_hex = @embedFile("../../examples/minimal/sample1.hex");
const corrupt1_hex = @embedFile("../../examples/minimal/corrupt1.hex");
const out_portb_hex = @embedFile("../../examples/minimal/out_portb.hex");

test "loadIntoFlash sample1" {
    var flash = try memory.Flash.initTest(testing.allocator, 256, 0xff);
    defer flash.deinit(testing.allocator);

    const count = try hex.loadIntoFlash(sample1_hex, &flash);
    try testing.expectEqual(@as(usize, 16), count);

    try testing.expectEqual(@as(u8, 0x0c), try flash.readByte(0x0000));
    try testing.expectEqual(@as(u8, 0x94), try flash.readByte(0x0001));
    try testing.expectEqual(@as(u8, 0x34), try flash.readByte(0x0002));
    try testing.expectEqual(@as(u8, 0x00), try flash.readByte(0x0003));
}

test "loadIntoFlash out_portb" {
    var flash = try memory.Flash.initTest(testing.allocator, 256, 0xff);
    defer flash.deinit(testing.allocator);

    const count = try hex.loadIntoFlash(out_portb_hex, &flash);
    try testing.expectEqual(@as(usize, 8), count);

    try testing.expectEqual(@as(u8, 0x00), try flash.readByte(0x0000));
    try testing.expectEqual(@as(u8, 0xe2), try flash.readByte(0x0001));
}

test "loadIntoFlash corrupt1 invalid line" {
    var flash = try memory.Flash.initTest(testing.allocator, 256, 0xff);
    defer flash.deinit(testing.allocator);

    try testing.expectError(error.InvalidHexRecord, hex.loadIntoFlash(corrupt1_hex, &flash));
}

test "loadIntoFlash empty file returns zero" {
    var flash = try memory.Flash.initTest(testing.allocator, 256, 0xff);
    defer flash.deinit(testing.allocator);

    const count = try hex.loadIntoFlash("", &flash);
    try testing.expectEqual(@as(usize, 0), count);
}

test "loadIntoFlash only EOF record" {
    var flash = try memory.Flash.initTest(testing.allocator, 256, 0xff);
    defer flash.deinit(testing.allocator);

    const count = try hex.loadIntoFlash(":00000001FF\n", &flash);
    try testing.expectEqual(@as(usize, 0), count);
}

test "loadIntoFlash ignores whitespace and empty lines" {
    var flash = try memory.Flash.initTest(testing.allocator, 256, 0xff);
    defer flash.deinit(testing.allocator);

    const hex_data = "\n  :0800000000E204B905B9FFCFCD\n:00000001FF\n";
    const count = try hex.loadIntoFlash(hex_data, &flash);
    try testing.expectEqual(@as(usize, 8), count);
}

test "parseHexByte valid" {
    try testing.expectEqual(@as(u8, 0x0c), try hex.parseHexByte("0c"));
    try testing.expectEqual(@as(u8, 0xff), try hex.parseHexByte("FF"));
    try testing.expectEqual(@as(u8, 0x94), try hex.parseHexByte("94"));
}

test "parseHexByte invalid" {
    try testing.expectError(error.InvalidCharacter, hex.parseHexByte("xx"));
}

test "parseHexU16 valid" {
    try testing.expectEqual(@as(u16, 0x0100), try hex.parseHexU16("0100"));
    try testing.expectEqual(@as(u16, 0xffff), try hex.parseHexU16("FFFF"));
}

test "loadIntoFlash out of range" {
    var flash = try memory.Flash.initTest(testing.allocator, 8, 0xff);
    defer flash.deinit(testing.allocator);

    try testing.expectError(error.FlashAddressOutOfRange, hex.loadIntoFlash(sample1_hex, &flash));
}

test "loadIntoFlash extended address" {
    var flash = try memory.Flash.initTest(testing.allocator, 0x10100, 0xff);
    defer flash.deinit(testing.allocator);

    const hex_data = ":020000040001F9\n:020000000C9460\n:0100020000FF\n:00000001FF\n";
    const count = try hex.loadIntoFlash(hex_data, &flash);
    try testing.expectEqual(@as(usize, 3), count);

    try testing.expectEqual(@as(u8, 0x0c), try flash.readByte(0x10000));
    try testing.expectEqual(@as(u8, 0x94), try flash.readByte(0x10001));
    try testing.expectEqual(@as(u8, 0x00), try flash.readByte(0x10002));
}

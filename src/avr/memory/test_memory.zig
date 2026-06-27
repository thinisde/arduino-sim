const std = @import("std");
const testing = std.testing;
const memory = @import("memory.zig");
const test_mcu = @import("../../mcu/atmega328p.zig");

test "flash initTest allocates and fills" {
    var flash = try memory.Flash.initTest(testing.allocator, 64, 0xff);
    defer flash.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 64), flash.bytes.len);
    try testing.expectEqual(@as(u8, 0xff), flash.bytes[0]);
    try testing.expectEqual(@as(u8, 0xff), flash.bytes[63]);
}

test "flash writeByte and readByte" {
    var flash = try memory.Flash.initTest(testing.allocator, 64, 0xff);
    defer flash.deinit(testing.allocator);
    try flash.writeByte(10, 0x42);
    try testing.expectEqual(@as(u8, 0x42), try flash.readByte(10));
}

test "flash readByte out of range" {
    var flash = try memory.Flash.initTest(testing.allocator, 8, 0xff);
    defer flash.deinit(testing.allocator);
    try testing.expectError(error.FlashAddressOutOfRange, flash.readByte(8));
}

test "flash writeByte out of range" {
    var flash = try memory.Flash.initTest(testing.allocator, 8, 0xff);
    defer flash.deinit(testing.allocator);
    try testing.expectError(error.FlashAddressOutOfRange, flash.writeByte(8, 0x00));
}

test "flash readWord" {
    var flash = try memory.Flash.initTest(testing.allocator, 64, 0xff);
    defer flash.deinit(testing.allocator);
    try flash.writeByte(0, 0x34);
    try flash.writeByte(1, 0x12);
    try testing.expectEqual(@as(u16, 0x1234), try flash.readWord(0));
}

test "data memory init and read write" {
    var data = try memory.DataMemory.init(testing.allocator, &test_mcu.spec);
    defer data.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 0x0900), data.bytes.len);
    try testing.expectEqual(@as(u8, 0), try data.readRawByte(0x0100));
    try data.writeRawByte(0x0100, 0xab);
    try testing.expectEqual(@as(u8, 0xab), try data.readRawByte(0x0100));
}

test "data memory out of range" {
    var data = try memory.DataMemory.init(testing.allocator, &test_mcu.spec);
    defer data.deinit(testing.allocator);
    try testing.expectError(error.DataAddressOutOfRange, data.readRawByte(0x0900));
    try testing.expectError(error.DataAddressOutOfRange, data.writeRawByte(0x0900, 0x00));
}

test "ioToDataAddress" {
    var data = try memory.DataMemory.init(testing.allocator, &test_mcu.spec);
    defer data.deinit(testing.allocator);
    try testing.expectEqual(@as(u16, 0x0023), data.ioToDataAddress(0x03));
    try testing.expectEqual(@as(u16, 0x005f), data.ioToDataAddress(0x3f));
}

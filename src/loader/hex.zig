const std = @import("std");
const memory = @import("../avr/memory/memory.zig");

fn parseHexByte(text: []const u8) !u8 {
    return try std.fmt.parseInt(u8, text, 16);
}

fn parseHexU16(text: []const u8) !u16 {
    return try std.fmt.parseInt(u16, text, 16);
}

pub fn loadIntoFlash(contents: []const u8, flash: *memory.Flash) !usize {
    var loaded_count: usize = 0;
    var upper_address: usize = 0;

    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \r\t");
        if (line.len == 0) continue;
        if (line[0] != ':') {
            return error.InvalidHexRecord;
        }

        const byte_count = try parseHexByte(line[1..3]);
        const address = try parseHexU16(line[3..7]);
        const record_type = try parseHexByte(line[7..9]);

        switch (record_type) {
            0x00 => {
                var i: usize = 0;
                while (i < byte_count) : (i += 1) {
                    const start = 9 + i * 2;
                    const value = try parseHexByte(line[start .. start + 2]);
                    const absolute_address = upper_address + @as(usize, address) + i;

                    try flash.writeByte(absolute_address, value);
                    loaded_count += 1;
                }
            },

            0x01 => {
                break;
            },

            0x04 => {
                const high = try parseHexU16(line[9..13]);
                upper_address = @as(usize, high) << 16;
            },
            else => {},
        }
    }

    return loaded_count;
}

const testing = std.testing;
const sample1_hex = @embedFile("../../examples/minimal/sample1.hex");
const corrupt1_hex = @embedFile("../../examples/minimal/corrupt1.hex");
const out_portb_hex = @embedFile("../../examples/minimal/out_portb.hex");

test "loadIntoFlash sample1" {
    var flash = try memory.Flash.initTest(testing.allocator, 256, 0xff);
    defer flash.deinit(testing.allocator);

    const count = try loadIntoFlash(sample1_hex, &flash);
    try testing.expectEqual(@as(usize, 16), count);

    try testing.expectEqual(@as(u8, 0x0c), try flash.readByte(0x0000));
    try testing.expectEqual(@as(u8, 0x94), try flash.readByte(0x0001));
    try testing.expectEqual(@as(u8, 0x34), try flash.readByte(0x0002));
    try testing.expectEqual(@as(u8, 0x00), try flash.readByte(0x0003));
}

test "loadIntoFlash out_portb" {
    var flash = try memory.Flash.initTest(testing.allocator, 256, 0xff);
    defer flash.deinit(testing.allocator);

    const count = try loadIntoFlash(out_portb_hex, &flash);
    try testing.expectEqual(@as(usize, 8), count);

    try testing.expectEqual(@as(u8, 0x00), try flash.readByte(0x0000));
    try testing.expectEqual(@as(u8, 0xe2), try flash.readByte(0x0001));
}

test "loadIntoFlash corrupt1 invalid line" {
    var flash = try memory.Flash.initTest(testing.allocator, 256, 0xff);
    defer flash.deinit(testing.allocator);

    try testing.expectError(error.InvalidHexRecord, loadIntoFlash(corrupt1_hex, &flash));
}

test "loadIntoFlash empty file returns zero" {
    var flash = try memory.Flash.initTest(testing.allocator, 256, 0xff);
    defer flash.deinit(testing.allocator);

    const count = try loadIntoFlash("", &flash);
    try testing.expectEqual(@as(usize, 0), count);
}

test "loadIntoFlash only EOF record" {
    var flash = try memory.Flash.initTest(testing.allocator, 256, 0xff);
    defer flash.deinit(testing.allocator);

    const count = try loadIntoFlash(":00000001FF\n", &flash);
    try testing.expectEqual(@as(usize, 0), count);
}

test "loadIntoFlash ignores whitespace and empty lines" {
    var flash = try memory.Flash.initTest(testing.allocator, 256, 0xff);
    defer flash.deinit(testing.allocator);

    const hex_data = "\n  :0800000000E204B905B9FFCFCD\n:00000001FF\n";

    const count = try loadIntoFlash(hex_data, &flash);
    try testing.expectEqual(@as(usize, 8), count);
}

test "parseHexByte valid" {
    try testing.expectEqual(@as(u8, 0x0c), try parseHexByte("0c"));
    try testing.expectEqual(@as(u8, 0xff), try parseHexByte("FF"));
    try testing.expectEqual(@as(u8, 0x94), try parseHexByte("94"));
}

test "parseHexByte invalid" {
    try testing.expectError(error.InvalidCharacter, parseHexByte("xx"));
}

test "parseHexU16 valid" {
    try testing.expectEqual(@as(u16, 0x0100), try parseHexU16("0100"));
    try testing.expectEqual(@as(u16, 0xffff), try parseHexU16("FFFF"));
}

test "loadIntoFlash out of range" {
    var flash = try memory.Flash.initTest(testing.allocator, 8, 0xff);
    defer flash.deinit(testing.allocator);

    try testing.expectError(error.FlashAddressOutOfRange, loadIntoFlash(sample1_hex, &flash));
}

test "loadIntoFlash extended address" {
    var flash = try memory.Flash.initTest(testing.allocator, 0x10100, 0xff);
    defer flash.deinit(testing.allocator);

    const hex_data = ":020000040001F9\n:020000000C9460\n:0100020000FF\n:00000001FF\n";

    const count = try loadIntoFlash(hex_data, &flash);
    try testing.expectEqual(@as(usize, 3), count);

    try testing.expectEqual(@as(u8, 0x0c), try flash.readByte(0x10000));
    try testing.expectEqual(@as(u8, 0x94), try flash.readByte(0x10001));
    try testing.expectEqual(@as(u8, 0x00), try flash.readByte(0x10002));
}

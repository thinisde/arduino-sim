const std = @import("std");
const memory = @import("../avr/memory.zig");

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

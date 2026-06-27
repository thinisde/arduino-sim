const board = @import("spec.zig");
const arduino_uno = @import("arduino_uno.zig");

pub fn get(kind: board.BoardKind) *const board.BoardSpec {
    return switch (kind) {
        .arduino_uno => &arduino_uno.spec,
    };
}

pub fn parse(name: []const u8) ?board.BoardKind {
    if (std.mem.eql(u8, name, "arduino-uno")) return .arduino_uno;
    if (std.mem.eql(u8, name, "uno")) return .arduino_uno;
    return null;
}

const std = @import("std");

const testing = std.testing;

test "get arduino_uno" {
    const b = get(.arduino_uno);
    try testing.expectEqualStrings("Arduino Uno", b.name);
    try testing.expectEqual(@as(u32, 16_000_000), b.clock_hz);
}

test "parse 'arduino-uno'" {
    try testing.expectEqual(board.BoardKind.arduino_uno, parse("arduino-uno").?);
}

test "parse 'uno'" {
    try testing.expectEqual(board.BoardKind.arduino_uno, parse("uno").?);
}

test "parse unknown" {
    try testing.expect(parse("mega2560") == null);
}

test "parse empty" {
    try testing.expect(parse("") == null);
}


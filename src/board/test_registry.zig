const std = @import("std");
const testing = std.testing;
const registry = @import("registry.zig");

test "get arduino_uno" {
    const b = registry.get(.arduino_uno);
    try testing.expectEqualStrings("Arduino Uno", b.name);
    try testing.expectEqual(@as(u32, 16_000_000), b.clock_hz);
}

test "parse 'arduino-uno'" {
    try testing.expect(registry.parse("arduino-uno") != null);
}

test "parse 'uno'" {
    try testing.expect(registry.parse("uno") != null);
}

test "parse unknown" {
    try testing.expect(registry.parse("mega2560") == null);
}

test "parse empty" {
    try testing.expect(registry.parse("") == null);
}

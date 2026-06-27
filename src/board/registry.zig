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


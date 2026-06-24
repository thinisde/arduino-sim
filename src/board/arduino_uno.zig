const board = @import("spec.zig");
const atmega328p = @import("../mcu/atmega328p.zig");

pub const digital_pins = [_]board.Pin{
    .{ .port = .D, .bit = 0 }, // D0
    .{ .port = .D, .bit = 1 }, // D1
    .{ .port = .D, .bit = 2 }, // D2
    .{ .port = .D, .bit = 3 }, // D3
    .{ .port = .D, .bit = 4 }, // D4
    .{ .port = .D, .bit = 5 }, // D5
    .{ .port = .D, .bit = 6 }, // D6
    .{ .port = .D, .bit = 7 }, // D7
    .{ .port = .B, .bit = 0 }, // D8
    .{ .port = .B, .bit = 1 }, // D9
    .{ .port = .B, .bit = 2 }, // D10
    .{ .port = .B, .bit = 3 }, // D11
    .{ .port = .B, .bit = 4 }, // D12
    .{ .port = .B, .bit = 5 }, // D13
};

pub const spec = board.BoardSpec{
    .kind = .arduino_uno,
    .name = "Arduino Uno",

    .mcu_kind = .atmega328p,
    .mcu = &atmega328p.spec,

    .clock_hz = 16_000_000,

    .digital_pins = &digital_pins,
    .led_builtin = 13,
};

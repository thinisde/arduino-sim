// src/board/spec.zig

const mcu = @import("../mcu/spec.zig");

pub const BoardKind = enum {
    arduino_uno,
};

pub const Port = enum {
    B,
    C,
    D,
};

pub const Pin = struct {
    port: mcu.PortId,
    bit: u3,
};

pub const BoardSpec = struct {
    kind: BoardKind,
    name: []const u8,

    mcu_kind: mcu.McuKind,
    mcu: *const mcu.McuSpec,

    default_serial_usart: usize,
    exposed_usarts: []const usize,

    clock_hz: u32,

    digital_pins: []const Pin,
    led_builtin: ?u8,
};

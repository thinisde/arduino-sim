const std = @import("std");
const testing = std.testing;
const gpio = @import("gpio.zig");
const test_board = @import("../../board/arduino_uno.zig");
const mem = @import("../memory/memory.zig");

test "gpio bitMask" {
    try testing.expectEqual(@as(u8, 0x01), gpio.Gpio.bitMask(0));
    try testing.expectEqual(@as(u8, 0x04), gpio.Gpio.bitMask(2));
    try testing.expectEqual(@as(u8, 0x80), gpio.Gpio.bitMask(7));
}

test "findDigitalPin D13 = index 13" {
    var data = try mem.DataMemory.init(testing.allocator, test_board.spec.mcu);
    defer data.deinit(testing.allocator);
    var cycles: u64 = 0;
    var g = gpio.Gpio.init(&test_board.spec, &data, &cycles);
    try testing.expectEqual(@as(usize, 13), g.findDigitalPin(.B, 5).?);
}

test "findDigitalPin D0 = index 0" {
    var data = try mem.DataMemory.init(testing.allocator, test_board.spec.mcu);
    defer data.deinit(testing.allocator);
    var cycles: u64 = 0;
    var g = gpio.Gpio.init(&test_board.spec, &data, &cycles);
    try testing.expectEqual(@as(usize, 0), g.findDigitalPin(.D, 0).?);
}

test "findDigitalPin undefined returns null" {
    var data = try mem.DataMemory.init(testing.allocator, test_board.spec.mcu);
    defer data.deinit(testing.allocator);
    var cycles: u64 = 0;
    var g = gpio.Gpio.init(&test_board.spec, &data, &cycles);
    try testing.expect(g.findDigitalPin(.C, 7) == null);
}

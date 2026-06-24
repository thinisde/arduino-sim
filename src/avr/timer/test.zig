const timer = @import("timer.zig");
const constants = @import("../constants/constants.zig");
const testing = @import("std").testing;

test "timer0 initial state" {
    const t = timer.Timer0{};
    try testing.expectEqual(@as(u8, 0), t.tccr0a);
    try testing.expectEqual(@as(u8, 0), t.tccr0b);
    try testing.expectEqual(@as(u8, 0), t.tcnt0);
    try testing.expectEqual(@as(u8, 0), t.tifr0);
    try testing.expectEqual(@as(u8, 0), t.timsk0);
    try testing.expectEqual(@as(u32, 0), t.prescaler_accum);
}

test "timer0 readIo returns values" {
    var t = timer.Timer0{};
    t.tccr0a = 0x03;
    t.tccr0b = 0x05;
    t.tcnt0 = 0x80;
    t.tifr0 = 0x01;

    try testing.expectEqual(@as(u8, 0x03), t.readIo(constants.Io.tccr0a).?);
    try testing.expectEqual(@as(u8, 0x05), t.readIo(constants.Io.tccr0b).?);
    try testing.expectEqual(@as(u8, 0x80), t.readIo(constants.Io.tcnt0).?);
    try testing.expectEqual(@as(u8, 0x01), t.readIo(constants.Io.tifr0).?);
    try testing.expectEqual(@as(?u8, null), t.readIo(constants.Io.portb));
}

test "timer0 writeIo sets values" {
    var t = timer.Timer0{};

    try testing.expectEqual(@as(?void, {}), t.writeIo(constants.Io.tccr0a, 0x03));
    try testing.expectEqual(@as(u8, 0x03), t.tccr0a);

    try testing.expectEqual(@as(?void, {}), t.writeIo(constants.Io.tccr0b, 0x05));
    try testing.expectEqual(@as(u8, 0x05), t.tccr0b);

    try testing.expectEqual(@as(?void, {}), t.writeIo(constants.Io.tcnt0, 0x80));
    try testing.expectEqual(@as(u8, 0x80), t.tcnt0);
    try testing.expectEqual(@as(u32, 0), t.prescaler_accum);

    try testing.expectEqual(@as(?void, null), t.writeIo(constants.Io.portb, 0xff));
}

test "timer0 writeIo tifr0 clears bits" {
    var t = timer.Timer0{};
    t.tifr0 = 0x07;
    try testing.expectEqual(@as(?void, {}), t.writeIo(constants.Io.tifr0, 0x01));
    try testing.expectEqual(@as(u8, 0x06), t.tifr0);
}

test "timer0 writeIo tcnt0 resets prescaler" {
    var t = timer.Timer0{};
    t.prescaler_accum = 100;
    try testing.expectEqual(@as(?void, {}), t.writeIo(constants.Io.tcnt0, 0x00));
    try testing.expectEqual(@as(u32, 0), t.prescaler_accum);
}

test "timer0 readData and writeData timsk0" {
    var t = timer.Timer0{};
    try testing.expectEqual(@as(?u8, 0), t.readData(constants.Data.timsk0));

    try testing.expectEqual(@as(?void, {}), t.writeData(constants.Data.timsk0, 0x01));
    try testing.expectEqual(@as(u8, 0x01), t.timsk0);
    try testing.expectEqual(@as(?u8, 0x01), t.readData(constants.Data.timsk0));

    try testing.expectEqual(@as(?void, null), t.writeData(0x9999, 0xff));
    try testing.expectEqual(@as(?u8, null), t.readData(0x9999));
}

test "timer0 prescaler stopped" {
    var t = timer.Timer0{};
    t.tccr0b = constants.Timer0.Tccr0b.stopped;
    try testing.expectEqual(@as(?u32, null), t.prescaler());
}

test "timer0 prescaler values" {
    var t = timer.Timer0{};
    t.tccr0b = constants.Timer0.Tccr0b.prescale_1;
    try testing.expectEqual(@as(u32, 1), t.prescaler().?);

    t.tccr0b = constants.Timer0.Tccr0b.prescale_8;
    try testing.expectEqual(@as(u32, 8), t.prescaler().?);

    t.tccr0b = constants.Timer0.Tccr0b.prescale_64;
    try testing.expectEqual(@as(u32, 64), t.prescaler().?);

    t.tccr0b = constants.Timer0.Tccr0b.prescale_256;
    try testing.expectEqual(@as(u32, 256), t.prescaler().?);

    t.tccr0b = constants.Timer0.Tccr0b.prescale_1024;
    try testing.expectEqual(@as(u32, 1024), t.prescaler().?);
}

test "timer0 tick with prescaler 1 increments tcnt0" {
    var t = timer.Timer0{};
    t.tccr0b = constants.Timer0.Tccr0b.prescale_1;
    t.tick(1);
    try testing.expectEqual(@as(u8, 1), t.tcnt0);
    t.tick(1);
    try testing.expectEqual(@as(u8, 2), t.tcnt0);
    t.tick(1);
    try testing.expectEqual(@as(u8, 3), t.tcnt0);
}

test "timer0 tick with prescaler 8 accumulates" {
    var t = timer.Timer0{};
    t.tccr0b = constants.Timer0.Tccr0b.prescale_8;
    t.tick(5);
    try testing.expectEqual(@as(u8, 0), t.tcnt0);
    t.tick(5);
    try testing.expectEqual(@as(u8, 1), t.tcnt0);
    try testing.expectEqual(@as(u32, 2), t.prescaler_accum);
}

test "timer0 tick stopped does nothing" {
    var t = timer.Timer0{};
    t.tccr0b = constants.Timer0.Tccr0b.stopped;
    t.tick(100);
    try testing.expectEqual(@as(u8, 0), t.tcnt0);
}

test "timer0 overflow sets tov0 flag" {
    var t = timer.Timer0{};
    t.tccr0b = constants.Timer0.Tccr0b.prescale_1;
    t.tcnt0 = 0xff;
    t.tick(1);
    try testing.expectEqual(@as(u8, 0x00), t.tcnt0);
    try testing.expectEqual(@as(u8, 1), t.tifr0);
}

test "timer0 overflowInterruptPending" {
    var t = timer.Timer0{};
    try testing.expectEqual(false, t.overflowInterruptPending());

    t.tifr0 |= @as(u8, 1) << constants.Timer0.Tifr0.tov0;
    try testing.expectEqual(false, t.overflowInterruptPending());

    t.timsk0 |= @as(u8, 1) << constants.Timer0.Timsk0.toie0;
    try testing.expectEqual(true, t.overflowInterruptPending());
}

test "timer0 acceptOverflowInterrupt clears tov0" {
    var t = timer.Timer0{};
    t.tifr0 = 0x07;
    t.acceptOverflowInterrupt();
    try testing.expectEqual(@as(u8, 0x06), t.tifr0);

    t.acceptOverflowInterrupt();
    try testing.expectEqual(@as(u8, 0x06), t.tifr0);
}

test "timer0 tick overflow across prescaler boundary" {
    var t = timer.Timer0{};
    t.tccr0b = constants.Timer0.Tccr0b.prescale_64;
    t.tcnt0 = 0xff;
    t.prescaler_accum = 63;
    t.tick(1);
    try testing.expectEqual(@as(u8, 0x00), t.tcnt0);
    try testing.expectEqual(@as(u8, 1), t.tifr0);
    try testing.expectEqual(@as(u32, 0), t.prescaler_accum);
}

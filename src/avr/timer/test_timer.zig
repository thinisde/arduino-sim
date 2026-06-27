const std = @import("std");
const testing = std.testing;
const timer = @import("timer.zig");
const timer0_spec = @import("../../mcu/atmega328p.zig").timer0;

test "init timer" {
    const t = timer.Timer.init(&timer0_spec);
    try testing.expectEqual(@as(u8, 0), timer.Timer.lowByte(t.tcnt));
    try testing.expectEqual(@as(u16, 0), t.tcnt);
    try testing.expectEqual(@as(u8, 0), t.tifr);
    try testing.expectEqual(@as(u8, 0), t.timsk);
}

test "prescaler stopped" {
    var t = timer.Timer.init(&timer0_spec);
    t.tccrb = timer0_spec.stopped;
    try testing.expect(t.prescaler() == null);
}

test "prescaler 1" {
    var t = timer.Timer.init(&timer0_spec);
    t.tccrb = timer0_spec.prescale_1.?;
    try testing.expectEqual(@as(u16, 1), t.prescaler().?);
}

test "prescaler 8" {
    var t = timer.Timer.init(&timer0_spec);
    t.tccrb = timer0_spec.prescale_8.?;
    try testing.expectEqual(@as(u16, 8), t.prescaler().?);
}

test "prescaler 64" {
    var t = timer.Timer.init(&timer0_spec);
    t.tccrb = timer0_spec.prescale_64.?;
    try testing.expectEqual(@as(u16, 64), t.prescaler().?);
}

test "prescaler 256" {
    var t = timer.Timer.init(&timer0_spec);
    t.tccrb = timer0_spec.prescale_256.?;
    try testing.expectEqual(@as(u16, 256), t.prescaler().?);
}

test "prescaler 1024" {
    var t = timer.Timer.init(&timer0_spec);
    t.tccrb = timer0_spec.prescale_1024.?;
    try testing.expectEqual(@as(u16, 1024), t.prescaler().?);
}

test "tick increments counter" {
    var t = timer.Timer.init(&timer0_spec);
    t.tccrb = timer0_spec.prescale_1.?;
    t.tick(1);
    try testing.expectEqual(@as(u16, 1), t.tcnt);
}

test "tick prescaler accumulate" {
    var t = timer.Timer.init(&timer0_spec);
    t.tccrb = timer0_spec.prescale_8.?;
    t.tick(7);
    try testing.expectEqual(@as(u16, 0), t.tcnt);
    t.tick(1);
    try testing.expectEqual(@as(u16, 1), t.tcnt);
}

test "tick overflow sets TOV" {
    var t = timer.Timer.init(&timer0_spec);
    t.tccrb = timer0_spec.prescale_1.?;
    t.tcnt = timer0_spec.max;
    t.tick(1);
    try testing.expectEqual(@as(u16, 0), t.tcnt);
    try testing.expect((t.tifr & (@as(u8, 1) << timer0_spec.tov_bit)) != 0);
}

test "overflow interrupt pending" {
    var t = timer.Timer.init(&timer0_spec);
    try testing.expect(!t.overflowInterruptPending());
    t.tifr |= @as(u8, 1) << timer0_spec.tov_bit;
    try testing.expect(!t.overflowInterruptPending());
    t.timsk |= @as(u8, 1) << timer0_spec.toie_bit;
    try testing.expect(t.overflowInterruptPending());
}

test "accept overflow interrupt clears TOV" {
    var t = timer.Timer.init(&timer0_spec);
    t.tifr |= @as(u8, 1) << timer0_spec.tov_bit;
    t.timsk |= @as(u8, 1) << timer0_spec.toie_bit;
    try testing.expect(t.overflowInterruptPending());
    t.acceptOverflowInterrupt();
    try testing.expect(!t.overflowInterruptPending());
    try testing.expectEqual(@as(u8, 0), t.tifr & (@as(u8, 1) << timer0_spec.tov_bit));
}

test "tifr write clears flags" {
    var t = timer.Timer.init(&timer0_spec);
    t.tifr = 0xff;
    _ = t.write(timer0_spec.tifr.?, 0x0f, 0);
    try testing.expectEqual(@as(u8, 0xf0), t.tifr);
}

test "tick stopped timer does nothing" {
    var t = timer.Timer.init(&timer0_spec);
    t.tccrb = timer0_spec.stopped;
    t.tcnt = 100;
    t.tick(1000);
    try testing.expectEqual(@as(u16, 100), t.tcnt);
}

test "handles known address" {
    var t = timer.Timer.init(&timer0_spec);
    try testing.expect(t.handles(timer0_spec.tcntl.?));
    try testing.expect(t.handles(timer0_spec.tifr.?));
}

test "handles unknown address" {
    var t = timer.Timer.init(&timer0_spec);
    try testing.expect(!t.handles(0xffff));
}

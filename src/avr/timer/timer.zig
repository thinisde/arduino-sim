const mcu_spec = @import("../../mcu/spec.zig");
const std = @import("std");

pub const Timer = struct {
    spec: *const mcu_spec.TimerSpec,

    tccra: u8 = 0,
    tccrb: u8 = 0,
    tccrc: u8 = 0,

    tcnt: u16 = 0,
    ocra: u16 = 0,
    ocrb: u16 = 0,
    icr: u16 = 0,

    tifr: u8 = 0,
    timsk: u8 = 0,

    last_ovf_cycle: ?u64 = null,
    prescaler_accum: u64 = 0,

    pub fn init(spec: *const mcu_spec.TimerSpec) Timer {
        return .{
            .spec = spec,
        };
    }

    fn matchesAddress(address: u16, maybe_addr: ?u16) bool {
        return maybe_addr != null and address == maybe_addr.?;
    }

    pub fn handles(self: *const Timer, address: u16) bool {
        return matchesAddress(address, self.spec.tccra) or
            matchesAddress(address, self.spec.tccrb) or
            matchesAddress(address, self.spec.tccrc) or
            matchesAddress(address, self.spec.tcntl) or
            matchesAddress(address, self.spec.tcnth) or
            matchesAddress(address, self.spec.ocral) or
            matchesAddress(address, self.spec.ocrah) or
            matchesAddress(address, self.spec.ocrbl) or
            matchesAddress(address, self.spec.ocrbh) or
            matchesAddress(address, self.spec.icrl) or
            matchesAddress(address, self.spec.icrh) or
            matchesAddress(address, self.spec.timsk) or
            matchesAddress(address, self.spec.tifr);
    }

    fn maskValue(self: *const Timer, value: u16) u16 {
        return switch (self.spec.width) {
            .bits8 => value & 0x00ff,
            .bits16 => value,
        };
    }

    fn lowByte(value: u16) u8 {
        return @truncate(value);
    }

    fn highByte(value: u16) u8 {
        return @truncate(value >> 8);
    }

    fn writeLow(old: u16, value: u8) u16 {
        return (old & 0xff00) | @as(u16, value);
    }

    fn writeHigh(old: u16, value: u8) u16 {
        return (@as(u16, value) << 8) | (old & 0x00ff);
    }

    pub fn read(
        self: *const Timer,
        address: u16,
        backing_value: u8,
        cycles: u64,
    ) u8 {
        _ = cycles;

        if (matchesAddress(address, self.spec.tifr)) return self.tifr;
        if (matchesAddress(address, self.spec.timsk)) return self.timsk;

        if (matchesAddress(address, self.spec.tccra)) return self.tccra;
        if (matchesAddress(address, self.spec.tccrb)) return self.tccrb;
        if (matchesAddress(address, self.spec.tccrc)) return self.tccrc;

        if (matchesAddress(address, self.spec.tcntl)) return lowByte(self.tcnt);
        if (matchesAddress(address, self.spec.tcnth)) return highByte(self.tcnt);

        if (matchesAddress(address, self.spec.ocral)) return lowByte(self.ocra);
        if (matchesAddress(address, self.spec.ocrah)) return highByte(self.ocra);

        if (matchesAddress(address, self.spec.ocrbl)) return lowByte(self.ocrb);
        if (matchesAddress(address, self.spec.ocrbh)) return highByte(self.ocrb);

        if (matchesAddress(address, self.spec.icrl)) return lowByte(self.icr);
        if (matchesAddress(address, self.spec.icrh)) return highByte(self.icr);

        return backing_value;
    }

    pub fn write(
        self: *Timer,
        address: u16,
        value: u8,
        cycles: u64,
    ) bool {
        _ = cycles;

        if (matchesAddress(address, self.spec.tifr)) {
            // AVR timer interrupt flags are usually cleared by writing 1.
            self.tifr &= ~value;
            return true;
        }

        if (matchesAddress(address, self.spec.timsk)) {
            self.timsk = value;
            return true;
        }

        if (matchesAddress(address, self.spec.tccra)) {
            self.tccra = value;
            return true;
        }

        if (matchesAddress(address, self.spec.tccrb)) {
            self.tccrb = value;
            return true;
        }

        if (matchesAddress(address, self.spec.tccrc)) {
            self.tccrc = value;
            return true;
        }

        if (matchesAddress(address, self.spec.tcntl)) {
            self.tcnt = self.maskValue(writeLow(self.tcnt, value));
            return true;
        }

        if (matchesAddress(address, self.spec.tcnth)) {
            self.tcnt = self.maskValue(writeHigh(self.tcnt, value));
            return true;
        }

        if (matchesAddress(address, self.spec.ocral)) {
            self.ocra = self.maskValue(writeLow(self.ocra, value));
            return true;
        }

        if (matchesAddress(address, self.spec.ocrah)) {
            self.ocra = self.maskValue(writeHigh(self.ocra, value));
            return true;
        }

        if (matchesAddress(address, self.spec.ocrbl)) {
            self.ocrb = self.maskValue(writeLow(self.ocrb, value));
            return true;
        }

        if (matchesAddress(address, self.spec.ocrbh)) {
            self.ocrb = self.maskValue(writeHigh(self.ocrb, value));
            return true;
        }

        if (matchesAddress(address, self.spec.icrl)) {
            self.icr = self.maskValue(writeLow(self.icr, value));
            return true;
        }

        if (matchesAddress(address, self.spec.icrh)) {
            self.icr = self.maskValue(writeHigh(self.icr, value));
            return true;
        }

        return false;
    }

    fn prescaler(self: *const Timer) ?u16 {
        const cs = self.tccrb & self.spec.cs_mask;

        if (cs == self.spec.stopped) return null;

        if (self.spec.prescale_1) |v| {
            if (cs == v) return 1;
        }

        if (self.spec.prescale_8) |v| {
            if (cs == v) return 8;
        }

        if (self.spec.prescale_32) |v| {
            if (cs == v) return 32;
        }

        if (self.spec.prescale_64) |v| {
            if (cs == v) return 64;
        }

        if (self.spec.prescale_128) |v| {
            if (cs == v) return 128;
        }

        if (self.spec.prescale_256) |v| {
            if (cs == v) return 256;
        }

        if (self.spec.prescale_1024) |v| {
            if (cs == v) return 1024;
        }

        return null;
    }

    pub fn tick(self: *Timer, cpu_cycles: u64) void {
        const div = self.prescaler() orelse return;

        self.prescaler_accum += cpu_cycles;

        while (self.prescaler_accum >= div) {
            self.prescaler_accum -= div;

            const old = self.tcnt;
            self.tcnt = self.maskValue(self.tcnt +% 1);

            if (old == self.spec.max) {
                self.tifr |= @as(u8, 1) << self.spec.tov_bit;
            }
        }
    }

    pub fn overflowInterruptPending(self: *const Timer) bool {
        const tov_set =
            (self.tifr & (@as(u8, 1) << self.spec.tov_bit)) != 0;

        const toie_set =
            (self.timsk & (@as(u8, 1) << self.spec.toie_bit)) != 0;

        return tov_set and toie_set;
    }

    pub fn acceptOverflowInterrupt(self: *Timer) void {
        self.tifr &= ~(@as(u8, 1) << self.spec.tov_bit);
    }

    pub fn debugAcceptedOverflow(self: *Timer, total_cycles: u64) void {
        if (self.last_ovf_cycle) |last| {
            std.debug.print("Timer ISR delta cycles={}\n", .{
                total_cycles - last,
            });
        }

        self.last_ovf_cycle = total_cycles;
    }
};

const testing = std.testing;
const timer0_spec = @import("../../mcu/atmega328p.zig").timer0;

test "init timer" {
    const timer = Timer.init(&timer0_spec);
    try testing.expectEqual(@as(u8, 0), Timer.lowByte(timer.tcnt));
    try testing.expectEqual(@as(u16, 0), timer.tcnt);
    try testing.expectEqual(@as(u8, 0), timer.tifr);
    try testing.expectEqual(@as(u8, 0), timer.timsk);
}

test "prescaler stopped" {
    var timer = Timer.init(&timer0_spec);
    timer.tccrb = timer0_spec.stopped;
    try testing.expectEqual(@TypeOf(null), @TypeOf(timer.prescaler()));
    try testing.expect(timer.prescaler() == null);
}

test "prescaler 1" {
    var timer = Timer.init(&timer0_spec);
    timer.tccrb = timer0_spec.prescale_1.?;
    try testing.expectEqual(@as(u16, 1), timer.prescaler().?);
}

test "prescaler 8" {
    var timer = Timer.init(&timer0_spec);
    timer.tccrb = timer0_spec.prescale_8.?;
    try testing.expectEqual(@as(u16, 8), timer.prescaler().?);
}

test "prescaler 64" {
    var timer = Timer.init(&timer0_spec);
    timer.tccrb = timer0_spec.prescale_64.?;
    try testing.expectEqual(@as(u16, 64), timer.prescaler().?);
}

test "prescaler 256" {
    var timer = Timer.init(&timer0_spec);
    timer.tccrb = timer0_spec.prescale_256.?;
    try testing.expectEqual(@as(u16, 256), timer.prescaler().?);
}

test "prescaler 1024" {
    var timer = Timer.init(&timer0_spec);
    timer.tccrb = timer0_spec.prescale_1024.?;
    try testing.expectEqual(@as(u16, 1024), timer.prescaler().?);
}

test "tick increments counter" {
    var timer = Timer.init(&timer0_spec);
    timer.tccrb = timer0_spec.prescale_1.?;
    timer.tick(1);
    try testing.expectEqual(@as(u16, 1), timer.tcnt);
}

test "tick prescaler accumulate" {
    var timer = Timer.init(&timer0_spec);
    timer.tccrb = timer0_spec.prescale_8.?;
    timer.tick(7);
    try testing.expectEqual(@as(u16, 0), timer.tcnt);
    timer.tick(1);
    try testing.expectEqual(@as(u16, 1), timer.tcnt);
}

test "tick overflow sets TOV" {
    var timer = Timer.init(&timer0_spec);
    timer.tccrb = timer0_spec.prescale_1.?;
    timer.tcnt = timer0_spec.max;
    timer.tick(1);
    try testing.expectEqual(@as(u16, 0), timer.tcnt);
    try testing.expect((timer.tifr & (@as(u8, 1) << timer0_spec.tov_bit)) != 0);
}

test "overflow interrupt pending" {
    var timer = Timer.init(&timer0_spec);
    try testing.expect(!timer.overflowInterruptPending());
    timer.tifr |= @as(u8, 1) << timer0_spec.tov_bit;
    try testing.expect(!timer.overflowInterruptPending());
    timer.timsk |= @as(u8, 1) << timer0_spec.toie_bit;
    try testing.expect(timer.overflowInterruptPending());
}

test "accept overflow interrupt clears TOV" {
    var timer = Timer.init(&timer0_spec);
    timer.tifr |= @as(u8, 1) << timer0_spec.tov_bit;
    timer.timsk |= @as(u8, 1) << timer0_spec.toie_bit;
    try testing.expect(timer.overflowInterruptPending());
    timer.acceptOverflowInterrupt();
    try testing.expect(!timer.overflowInterruptPending());
    try testing.expectEqual(@as(u8, 0), timer.tifr & (@as(u8, 1) << timer0_spec.tov_bit));
}

test "tifr write clears flags" {
    var timer = Timer.init(&timer0_spec);
    timer.tifr = 0xff;
    _ = timer.write(timer0_spec.tifr.?, 0x0f, 0);
    try testing.expectEqual(@as(u8, 0xf0), timer.tifr);
}

test "tick stopped timer does nothing" {
    var timer = Timer.init(&timer0_spec);
    timer.tccrb = timer0_spec.stopped;
    timer.tcnt = 100;
    timer.tick(1000);
    try testing.expectEqual(@as(u16, 100), timer.tcnt);
}

test "handles known address" {
    var timer = Timer.init(&timer0_spec);
    try testing.expect(timer.handles(timer0_spec.tcntl.?));
    try testing.expect(timer.handles(timer0_spec.tifr.?));
}

test "handles unknown address" {
    var timer = Timer.init(&timer0_spec);
    try testing.expect(!timer.handles(0xffff));
}


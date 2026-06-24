const constants = @import("../constants/constants.zig");
const mcu_spec = @import("../../mcu/spec.zig");

pub const Timer0 = struct {
    mcu: *const mcu_spec.McuSpec,

    tccr0a: u8 = 0,
    tccr0b: u8 = 0,
    tcnt0: u8 = 0,
    tifr0: u8 = 0,
    timsk0: u8 = 0,

    prescaler_accum: u32 = 0,

    pub fn init(mcu: *const mcu_spec.McuSpec) Timer0 {
        return .{
            .mcu = mcu,
        };
    }

    pub fn readIo(self: *const Timer0, address: usize) ?u8 {
        const io = self.mcu.io;

        if (address == io.tifr0) return self.tifr0;
        if (address == io.tccr0a) return self.tccr0a;
        if (address == io.tccr0b) return self.tccr0b;
        if (address == io.tcnt0) return self.tcnt0;

        return null;
    }

    pub fn writeIo(self: *Timer0, address: usize, value: u8) bool {
        const io = self.mcu.io;

        if (address == io.tifr0) {
            // AVR timer flags are usually cleared by writing 1.
            self.tifr0 &= ~value;
            return true;
        }

        if (address == io.tccr0a) {
            self.tccr0a = value;
            return true;
        }

        if (address == io.tccr0b) {
            self.tccr0b = value;
            return true;
        }

        if (address == io.tcnt0) {
            self.tcnt0 = value;
            return true;
        }

        return false;
    }

    pub fn readData(self: *const Timer0, address: usize) ?u8 {
        if (address == self.mcu.data.timsk0) return self.timsk0;
        return null;
    }

    pub fn writeData(self: *Timer0, address: usize, value: u8) bool {
        if (address == self.mcu.data.timsk0) {
            self.timsk0 = value;
            return true;
        }

        return false;
    }

    fn prescaler(self: *const Timer0) ?u16 {
        const t = self.mcu.timer0;
        const cs = self.tccr0b & t.cs_mask;

        if (cs == t.stopped) return null;
        if (cs == t.prescale_1) return 1;
        if (cs == t.prescale_8) return 8;
        if (cs == t.prescale_64) return 64;
        if (cs == t.prescale_256) return 256;
        if (cs == t.prescale_1024) return 1024;

        return null;
    }

    pub fn tick(self: *Timer0, cpu_cycles: u8) void {
        const div = self.prescaler() orelse return;

        self.prescaler_accum += cpu_cycles;

        while (self.prescaler_accum >= div) {
            self.prescaler_accum -= div;

            const old = self.tcnt0;
            self.tcnt0 +%= 1;

            if (old == 0xff) {
                self.tifr0 |= @as(u8, 1) << self.mcu.timer0.tov0_bit;
            }
        }
    }

    pub fn overflowInterruptPending(self: *const Timer0) bool {
        const tov0_set =
            (self.tifr0 & (@as(u8, 1) << self.mcu.timer0.tov0_bit)) != 0;

        const toie0_set =
            (self.timsk0 & (@as(u8, 1) << self.mcu.timer0.tov0_bit)) != 0;

        return tov0_set and toie0_set;
    }

    pub fn acceptOverflowInterrupt(self: *Timer0) void {
        self.tifr0 &= ~(@as(u8, 1) << self.mcu.timer0.tov0_bit);
    }
};

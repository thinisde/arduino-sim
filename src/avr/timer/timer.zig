const constants = @import("../constants/constants.zig");

pub const Timer0 = struct {
    tccr0a: u8 = 0,
    tccr0b: u8 = 0,
    tcnt0: u8 = 0,
    tifr0: u8 = 0,
    timsk0: u8 = 0,

    prescaler_accum: u32 = 0,

    pub fn readIo(self: *const Timer0, address: usize) ?u8 {
        return switch (address) {
            constants.Io.tifr0 => self.tifr0,
            constants.Io.tccr0a => self.tccr0a,
            constants.Io.tccr0b => self.tccr0b,
            constants.Io.tcnt0 => self.tcnt0,
            else => null,
        };
    }

    pub fn writeIo(self: *Timer0, address: usize, value: u8) ?void {
        switch (address) {
            constants.Io.tifr0 => {
                self.tifr0 &= ~value;
                return {};
            },
            constants.Io.tccr0a => {
                self.tccr0a = value;
                return {};
            },
            constants.Io.tccr0b => {
                self.tccr0b = value;
                return {};
            },
            constants.Io.tcnt0 => {
                self.tcnt0 = value;
                self.prescaler_accum = 0;
                return {};
            },
            else => return null,
        }
    }

    pub fn readData(self: *const Timer0, address: u16) ?u8 {
        return switch (address) {
            constants.Data.timsk0 => self.timsk0,
            else => null,
        };
    }

    pub fn writeData(self: *Timer0, address: u16, value: u8) ?void {
        switch (address) {
            constants.Data.timsk0 => {
                self.timsk0 = value;
                return;
            },
            else => return null,
        }
    }

    pub fn prescaler(self: *const Timer0) ?u32 {
        return switch (self.tccr0b & constants.Timer0.Tccr0b.cs_mask) {
            constants.Timer0.Tccr0b.stopped => null,
            constants.Timer0.Tccr0b.prescale_1 => 1,
            constants.Timer0.Tccr0b.prescale_8 => 8,
            constants.Timer0.Tccr0b.prescale_64 => 64,
            constants.Timer0.Tccr0b.prescale_256 => 256,
            constants.Timer0.Tccr0b.prescale_1024 => 1024,
            else => null,
        };
    }

    pub fn tick(self: *Timer0, cpu_cycles: u8) void {
        const div = self.prescaler() orelse return;

        self.prescaler_accum += cpu_cycles;

        while (self.prescaler_accum >= div) {
            self.prescaler_accum -= div;

            const old = self.tcnt0;
            self.tcnt0 +%= 1;

            if (old == 0xff) {
                self.tifr0 |= @as(u8, 1) << constants.Timer0.Tifr0.tov0;
            }
        }
    }

    pub fn overflowInterruptPending(self: *const Timer0) bool {
        const tov0_set =
            (self.tifr0 & (@as(u8, 1) << constants.Timer0.Tifr0.tov0)) != 0;

        const toie0_set =
            (self.timsk0 & (@as(u8, 1) << constants.Timer0.Timsk0.toie0)) != 0;

        return tov0_set and toie0_set;
    }

    pub fn acceptOverflowInterrupt(self: *Timer0) void {
        self.tifr0 &= ~(@as(u8, 1) << constants.Timer0.Tifr0.tov0);
    }
};

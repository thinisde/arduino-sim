const std = @import("std");

pub const RealTimeThrottle = struct {
    const check_every_steps: usize = 1000;

    io: std.Io,
    clock_hz: u64,
    start_time: std.Io.Timestamp,
    steps_until_check: usize = check_every_steps,

    pub fn init(io: std.Io, clock_hz: u64) RealTimeThrottle {
        std.debug.assert(clock_hz > 0);

        return .{
            .io = io,
            .clock_hz = clock_hz,
            .start_time = std.Io.Timestamp.now(io, .awake),
        };
    }

    pub fn afterStep(self: *RealTimeThrottle, cycles: u64) !void {
        self.steps_until_check -= 1;

        if (self.steps_until_check != 0) {
            return;
        }

        self.steps_until_check = check_every_steps;

        const simulated_ns_u128 =
            (@as(u128, cycles) * @as(u128, std.time.ns_per_s)) /
            @as(u128, self.clock_hz);

        const real_ns_i = self.start_time.untilNow(self.io, .awake).toNanoseconds();

        if (real_ns_i <= 0) {
            return;
        }

        const real_ns: u128 = @intCast(real_ns_i);

        if (simulated_ns_u128 <= @as(u128, real_ns)) {
            return;
        }

        const sleep_ns_u128 = simulated_ns_u128 - @as(u128, real_ns);

        const sleep_ns: u64 = if (sleep_ns_u128 > @as(u128, std.math.maxInt(u64)))
            std.math.maxInt(u64)
        else
            @intCast(sleep_ns_u128);

        try self.io.sleep(.fromNanoseconds(sleep_ns), .awake);
    }
};

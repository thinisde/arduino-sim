const std = @import("std");

pub const RealTimeThrottle = struct {
    const check_every_steps: usize = 1000;
    const min_sleep_ns: u64 = std.time.ns_per_ms;

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

        const simulated_elapsed_ns =
            (@as(u128, cycles) * @as(u128, std.time.ns_per_s)) /
            @as(u128, self.clock_hz);

        const real_elapsed_ns = self.start_time.untilNow(self.io, .awake).toNanoseconds();

        if (real_elapsed_ns <= 0) {
            return;
        }

        const real_elapsed_ns_u128: u128 = @intCast(real_elapsed_ns);

        if (simulated_elapsed_ns <= real_elapsed_ns_u128) {
            return;
        }

        const sleep_ns_u128 = simulated_elapsed_ns - real_elapsed_ns_u128;

        const sleep_ns: u64 = if (sleep_ns_u128 > @as(u128, std.math.maxInt(u64)))
            std.math.maxInt(u64)
        else
            @intCast(sleep_ns_u128);

        if (sleep_ns < min_sleep_ns) {
            return;
        }

        try self.io.sleep(.fromNanoseconds(sleep_ns), .awake);
    }
};

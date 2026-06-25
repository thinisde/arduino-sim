const std = @import("std");

const board_registry = @import("board/registry.zig");
const board_spec = @import("board/spec.zig");

const memory = @import("avr/memory/memory.zig");
const hex = @import("loader/hex.zig");
const cpu_mod = @import("avr/cpu/cpu.zig");
const gpio_mod = @import("avr/gpio/gpio.zig");
const real_time_throttle = @import("utils/real_time_throttle.zig");

const default_board: board_spec.BoardKind = .arduino_uno;

var stop_requested = std.atomic.Value(bool).init(false);

fn handleSigint(sig: std.posix.SIG) callconv(.c) void {
    _ = sig;
    stop_requested.store(true, .release);
}

fn installSigintHandler() void {
    const action: std.posix.Sigaction = .{
        .handler = .{ .handler = handleSigint },
        .flags = 0,
        .mask = std.posix.sigemptyset(),
    };

    std.posix.sigaction(std.posix.SIG.INT, &action, null);
}

const Options = struct {
    path: []const u8,
    steps: usize = 1000,
    trace: bool = false,
    quiet: bool = false,
    selected_board_kind: board_spec.BoardKind = default_board,
    run_forever: bool = false,
    real_time: bool = true,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    installSigintHandler();

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    const options = parseOptions(args) catch |err| {
        printUsage();
        return err;
    };

    if (options.path.len == 0) {
        printUsage();
        return;
    }

    const board = board_registry.get(options.selected_board_kind);

    const contents = try std.Io.Dir.cwd().readFileAlloc(io, options.path, allocator, .limited(1024 * 1024));
    defer allocator.free(contents);

    var flash = try memory.Flash.init(allocator, board.mcu);
    defer flash.deinit(allocator);

    _ = try hex.loadIntoFlash(contents, &flash);

    var cpu = try cpu_mod.Cpu.init(allocator, board, &flash);
    defer cpu.deinit(allocator);

    cpu.trace = options.trace;
    cpu.quiet = options.quiet;

    var gpio = gpio_mod.Gpio.init(board, &cpu.data, &cpu.cycles);
    cpu.gpio = &gpio;

    const clock_hz: u64 = board.clock_hz;

    var throttle = real_time_throttle.RealTimeThrottle.init(io, clock_hz);

    var step_count: usize = 0;

    if (options.run_forever) {
        while (!stop_requested.load(.acquire)) {
            try cpu.step();

            if (options.real_time) {
                try throttle.afterStep(cpu.cycles);
            }
        }
    } else {
        while (step_count < options.steps and !stop_requested.load(.acquire)) : (step_count += 1) {
            try cpu.step();

            if (options.real_time) {
                try throttle.afterStep(cpu.cycles);
            }
        }
    }
    if (!options.quiet) {
        const simulated_seconds =
            @as(f64, @floatFromInt(cpu.cycles)) /
            @as(f64, @floatFromInt(clock_hz));

        const simulated_minutes = simulated_seconds / 60.0;

        std.debug.print("PC=0x{x:0>4} cycles={} simulated_time={d:.9}s ({d:.12} min)\n", .{
            cpu.pc,
            cpu.cycles,
            simulated_seconds,
            simulated_minutes,
        });
    }
}

fn parseOptions(args: []const []const u8) !Options {
    var options = Options{ .path = "" };

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--trace")) {
            options.trace = true;
        } else if (std.mem.eql(u8, arg, "--run-forever")) {
            options.run_forever = true;
        } else if (std.mem.eql(u8, arg, "--disable-real-time")) {
            options.real_time = false;
        } else if (std.mem.eql(u8, arg, "--quiet")) {
            options.quiet = true;
        } else if (std.mem.eql(u8, arg, "--steps")) {
            i += 1;

            if (i >= args.len) {
                return error.MissingStepsValue;
            }

            options.steps = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.eql(u8, arg, "--board")) {
            i += 1;

            if (i >= args.len) {
                return error.MissingBoardValue;
            }

            const board_name = args[i];

            options.selected_board_kind = board_registry.parse(board_name) orelse {
                std.debug.print("error: unknown board '{s}'\n", .{board_name});
                return error.UnknownBoard;
            };
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownOption;
        } else if (options.path.len == 0) {
            options.path = arg;
        } else {
            return error.UnexpectedArgument;
        }
    }

    return options;
}

fn printUsage() void {
    std.debug.print(
        \\usage: arduino-sim <program.hex> [--steps N] [--trace] [--quiet]
        \\
        \\  --steps N     max number of CPU instructions
        \\  --trace       print every instruction
        \\  --quiet       print only final summary
        \\
    , .{});
}

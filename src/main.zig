const std = @import("std");

const board_registry = @import("board/registry.zig");
const board_spec = @import("board/spec.zig");

const memory = @import("avr/memory/memory.zig");
const hex = @import("loader/hex.zig");
const cpu_mod = @import("avr/cpu/cpu.zig");
const gpio_mod = @import("avr/gpio/gpio.zig");

const real_time_throttle = @import("utils/real_time_throttle.zig");
const terminal = @import("utils/usart.zig");

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
    serial_raw: bool = false,
    selected_board_kind: board_spec.BoardKind = default_board,
    run_forever: bool = false,
    real_time: bool = true,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io: std.Io = init.io;

    const start: std.Io.Timestamp = std.Io.Clock.real.now(io);

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

    var terminal_mode = terminal.TerminalMode{};
    defer terminal_mode.restore();

    if (options.serial_raw) {
        try terminal_mode.enableRaw();
    }

    var step_count: usize = 0;

    if (options.run_forever) {
        while (!stop_requested.load(.acquire)) {
            terminal.sliceUsarts(&cpu);
            if ((step_count & 0x0fff) == 0) { // every 4096 instructions
                try terminal.pumpTerminalInput(&cpu);
            }

            try cpu.step();
            step_count += 1;

            if (options.real_time) {
                try throttle.afterStep(cpu.cycles);
            }
        }
    } else {
        while (step_count < options.steps and !stop_requested.load(.acquire)) : (step_count += 1) {
            terminal.sliceUsarts(&cpu);
            if ((step_count & 0x0fff) == 0) { // every 4096 instructions
                try terminal.pumpTerminalInput(&cpu);
            }
            try cpu.step();

            if (options.real_time) {
                try throttle.afterStep(cpu.cycles);
            }
        }
    }

    terminal.sliceUsarts(&cpu);

    if (!options.quiet) {
        const untilNow = start.untilNow(io, std.Io.Clock.real);
        const program_seconds = @as(f64, @floatFromInt(untilNow.toNanoseconds())) / 1e9;

        const simulated_seconds =
            @as(f64, @floatFromInt(cpu.cycles)) /
            @as(f64, @floatFromInt(clock_hz));

        std.debug.print("program_time={d:.3}s\n", .{program_seconds});

        std.debug.print("PC=0x{x:0>4} cycles={} simulated_time={d:.6}s\n", .{
            cpu.pc,
            cpu.cycles,
            simulated_seconds,
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
        } else if (std.mem.eql(u8, arg, "--disable-realtime")) {
            options.real_time = false;
        } else if (std.mem.eql(u8, arg, "--serialraw")) {
            options.serial_raw = true;
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

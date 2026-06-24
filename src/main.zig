const std = @import("std");

const board_registry = @import("board/registry.zig");
const board_spec = @import("board/spec.zig");

const memory = @import("avr/memory/memory.zig");
const hex = @import("loader/hex.zig");
const cpu_mod = @import("avr/cpu/cpu.zig");
const gpio_mod = @import("avr/gpio/gpio.zig");

const default_board: board_spec.BoardKind = .arduino_uno;

const Options = struct {
    path: []const u8,
    steps: usize = 1000,
    trace: bool = false,
    quiet: bool = false,
    selected_board_kind: board_spec.BoardKind = default_board,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

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

    try hex.loadIntoFlash(contents, &flash);

    var cpu = cpu_mod.Cpu.init(allocator, board, &flash);
    cpu.trace = options.trace;
    cpu.quiet = options.quiet;

    var gpio = gpio_mod.Gpio.init(board, cpu.io);
    cpu.gpio = &gpio;

    var step_count: usize = 0;

    while (step_count < options.steps) : (step_count += 1) {
        try cpu.step();
    }

    if (options.quiet) {
        std.debug.print("Stopped after {} steps\n", .{options.steps});
        std.debug.print("PC=0x{x:0>4} cycles={}\n", .{
            cpu.pc,
            cpu.cycles,
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
        } else if (std.mem.eql(u8, arg, "--quiet")) {
            options.quiet = true;
        } else if (std.mem.eql(u8, arg, "--steps")) {
            i += 1;

            if (i >= args.len) {
                return error.MissingStepsValue;
            }

            options.steps = try std.fmt.parseInt(usize, args[i], 10);
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownOption;
        } else if (std.mem.eql(u8, arg, "--board")) {
            const board_name = args.next() orelse {
                std.debug.print("error: --board requires a value\n", .{});
                return;
            };

            options.selected_board_kind = board_registry.parse(board_name) orelse {
                std.debug.print("error: unkown board '{s}'", .{board_name});
                return;
            };
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

const testing = std.testing;

test "parseOptions default path" {
    const args = [_][]const u8{"arduino_sim"};
    const opts = try parseOptions(&args);
    try testing.expectEqualStrings("", opts.path);
    try testing.expectEqual(@as(usize, 1000), opts.steps);
    try testing.expectEqual(false, opts.trace);
    try testing.expectEqual(false, opts.quiet);
}

test "parseOptions path only" {
    const args = [_][]const u8{ "arduino_sim", "blink.hex" };
    const opts = try parseOptions(&args);
    try testing.expectEqualStrings("blink.hex", opts.path);
    try testing.expectEqual(@as(usize, 1000), opts.steps);
}

test "parseOptions trace flag" {
    const args = [_][]const u8{ "arduino_sim", "blink.hex", "--trace" };
    const opts = try parseOptions(&args);
    try testing.expectEqual(true, opts.trace);
    try testing.expectEqual(false, opts.quiet);
}

test "parseOptions quiet flag" {
    const args = [_][]const u8{ "arduino_sim", "blink.hex", "--quiet" };
    const opts = try parseOptions(&args);
    try testing.expectEqual(false, opts.trace);
    try testing.expectEqual(true, opts.quiet);
}

test "parseOptions trace and quiet" {
    const args = [_][]const u8{ "arduino_sim", "blink.hex", "--trace", "--quiet" };
    const opts = try parseOptions(&args);
    try testing.expectEqual(true, opts.trace);
    try testing.expectEqual(true, opts.quiet);
}

test "parseOptions steps flag" {
    const args = [_][]const u8{ "arduino_sim", "blink.hex", "--steps", "500" };
    const opts = try parseOptions(&args);
    try testing.expectEqual(@as(usize, 500), opts.steps);
}

test "parseOptions all flags" {
    const args = [_][]const u8{ "arduino_sim", "blink.hex", "--steps", "2000", "--trace", "--quiet" };
    const opts = try parseOptions(&args);
    try testing.expectEqualStrings("blink.hex", opts.path);
    try testing.expectEqual(@as(usize, 2000), opts.steps);
    try testing.expectEqual(true, opts.trace);
    try testing.expectEqual(true, opts.quiet);
}

test "parseOptions missing steps value" {
    const args = [_][]const u8{ "arduino_sim", "--steps" };
    try testing.expectError(error.MissingStepsValue, parseOptions(&args));
}

test "parseOptions unknown flag" {
    const args = [_][]const u8{ "arduino_sim", "blink.hex", "--unknown" };
    try testing.expectError(error.UnknownOption, parseOptions(&args));
}

test "parseOptions unexpected second path argument" {
    const args = [_][]const u8{ "arduino_sim", "blink.hex", "other.hex" };
    try testing.expectError(error.UnexpectedArgument, parseOptions(&args));
}

comptime {
    _ = @import("std").testing.refAllDecls(@This());
    _ = @import("avr/memory/test.zig");
    _ = @import("avr/cpu/test.zig");
    _ = @import("avr/timer/test.zig");
    _ = @import("avr/constants/test.zig");
}

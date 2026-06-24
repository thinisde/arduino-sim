const std = @import("std");

const memory = @import("avr/memory.zig");
const hex = @import("loader/hex.zig");
const cpu_mod = @import("avr/cpu.zig");

const Options = struct {
    path: []const u8,
    steps: usize = 1000,
    trace: bool = false,
    quiet: bool = false,
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

    const contents = try std.Io.Dir.cwd().readFileAlloc(io, options.path, allocator, .limited(1024 * 1024));
    defer allocator.free(contents);

    var flash = memory.Flash{};

    _ = try hex.loadIntoFlash(contents, &flash);

    var cpu = cpu_mod.Cpu.init(&flash);
    cpu.trace = options.trace;
    cpu.quiet = options.quiet;

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

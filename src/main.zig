const std = @import("std");

const memory = @import("avr/memory.zig");
const hex = @import("loader/hex.zig");
const cpu_mod = @import("avr/cpu.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len < 2) {
        std.debug.print("usage: arduino-sim <program.hex>\n", .{});
        return;
    }

    const path = args[1];

    const contents = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024));
    defer allocator.free(contents);

    var flash = memory.Flash{};

    const loaded = try hex.loadIntoFlash(contents, &flash);

    std.debug.print("Loaded HEX file: {s}\n", .{path});
    std.debug.print("Program bytes loaded: {}\n", .{loaded});
    std.debug.print("First 16 bytes:\n", .{});

    var i: usize = 0;
    while (i < 16) : (i += 16) {
        std.debug.print("0x{x}: 0x{x}\n", .{ i, flash.bytes[i] });
    }

    var cpu = cpu_mod.Cpu.init(&flash);

    std.debug.print("\nFetching first 8 instructions:\n", .{});

    var step_count: usize = 0;
    while (step_count < 8) : (step_count += 1) {
        try cpu.step();
    }
}

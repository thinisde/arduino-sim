//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

/// This is a documentation comment to explain the `printAnotherMessage` function below.
///
/// Accepting an `Io.Writer` instance is a handy way to write reusable code.
pub fn printAnotherMessage(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print("Run `zig build test` to run the tests.\n", .{});
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

const testing = std.testing;

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}

test "add negative numbers" {
    try testing.expectEqual(0, add(5, -5));
    try testing.expectEqual(-3, add(-1, -2));
}

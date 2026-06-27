const std = @import("std");
const cpu_mod = @import("../avr/cpu/cpu.zig");
const usart_mod = @import("../avr/usart/usart.zig");

pub const TerminalMode = struct {
    enabled: bool = false,
    original: std.posix.termios = undefined,

    pub fn enableRaw(self: *TerminalMode) !void {
        if (!std.posix.isatty(std.posix.STDIN_FILENO)) {
            return null;
        }

        self.original = try std.posix.tcgetattr(std.posix.STDIN_FILENO);

        var raw = self.original;

        raw.iflag.BRKINT = false;
        raw.iflag.ICRNL = false;
        raw.iflag.INPCK = false;
        raw.iflag.ISTRIP = false;
        raw.iflag.IXON = false;
        raw.oflag.OPOST = false;
        raw.cflag.CSIZE = .CS8;
        raw.cflag.PARENB = false;

        // Disable canonical line buffering, local echo, and signal generation.
        raw.lflag.ICANON = false;
        raw.lflag.ECHO = false;
        raw.lflag.IEXTEN = false;
        raw.lflag.ISIG = false;

        // Make read return as soon as data is available.
        raw.cc[@intFromEnum(std.posix.V.MIN)] = 0;
        raw.cc[@intFromEnum(std.posix.V.TIME)] = 0;

        try std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, raw);
        self.enabled = true;
    }

    pub fn restore(self: *TerminalMode) void {
        if (!self.enabled) return;
        std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, self.original) catch {};
        self.enabled = false;
    }
};

fn drainUsartTx(usart: *usart_mod.Usart, cycles: u64) void {
    while (usart.takeTxByte(cycles)) |byte| {
        if (byte == '\r') continue;

        if (byte == '\n') {
            std.debug.print("\n", .{});
        } else {
            std.debug.print("{c}", .{byte});
        }
    }
}

pub fn sliceUsarts(cpu: *cpu_mod.Cpu) void {
    for (&cpu.usarts) |*maybe_usart| {
        if (maybe_usart.*) |*usart| {
            drainUsartTx(usart, cpu.cycles);
        }
    }
}

pub fn pumpTerminalInput(cpu: *cpu_mod.Cpu) !void {
    while (true) {
        var fds = [_]std.posix.pollfd{
            .{
                .fd = std.posix.STDIN_FILENO,
                .events = std.posix.POLL.IN,
                .revents = 0,
            },
        };

        const ready = try std.posix.poll(&fds, 0);
        if (ready == 0) return;

        if ((fds[0].revents & std.posix.POLL.IN) == 0) {
            return;
        }

        var buf: [256]u8 = undefined;
        const n = try std.posix.read(std.posix.STDIN_FILENO, &buf);
        if (n == 0) return;

        for (buf[0..n]) |byte| {
            cpu.injectDefaultSerialRxByte(byte);
        }

        if (n < buf.len) return;
    }
}

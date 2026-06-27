const std = @import("std");
const board_spec = @import("../../board/spec.zig");
const mcu_spec = @import("../../mcu/spec.zig");
const memory = @import("../memory/memory.zig");

pub const Gpio = struct {
    board: *const board_spec.BoardSpec,
    mcu: *const mcu_spec.McuSpec,
    data: *memory.DataMemory,
    cycles: *const u64,
    clock_hz: u64,

    pub fn init(
        board: *const board_spec.BoardSpec,
        data: *memory.DataMemory,
        cycles: *const u64,
    ) Gpio {
        return .{
            .board = board,
            .mcu = board.mcu,
            .data = data,
            .clock_hz = board.clock_hz,
            .cycles = cycles,
        };
    }

    pub fn handleIoWrite(
        self: *Gpio,
        address: usize,
        old: u8,
        new: u8,
    ) void {
        if (old == new) return;

        for (self.mcu.gpio_ports) |port| {
            if (address == port.ddr_io) {
                self.handleDdrWrite(port, old, new);
                return;
            }

            if (address == port.port_io) {
                self.handlePortWrite(port, old, new);
                return;
            }
        }
    }

    fn handleDdrWrite(
        self: *Gpio,
        port: mcu_spec.GpioPortSpec,
        old: u8,
        new: u8,
    ) void {
        const changed = old ^ new;

        for (0..8) |bit_usize| {
            const bit: u3 = @intCast(bit_usize);
            const mask = bitMask(bit);

            if ((changed & mask) == 0) continue;

            const digital_pin = self.findDigitalPin(port.id, bit) orelse continue;
            const is_output = (new & mask) != 0;

            const seconds =
                @as(f64, @floatFromInt(self.cycles.*)) /
                @as(f64, @floatFromInt(self.clock_hz));

            std.debug.print("[{d:.6}s] [pin] D{} mode = {s}\n", .{
                seconds,
                digital_pin,
                if (is_output) "OUTPUT" else "INPUT",
            });
        }
    }

    fn handlePortWrite(
        self: *Gpio,
        port: mcu_spec.GpioPortSpec,
        old: u8,
        new: u8,
    ) void {
        const ddr = self.data.readRawByte(port.ddr_data) catch 0;
        const changed = old ^ new;

        for (0..8) |bit_usize| {
            const bit: u3 = @intCast(bit_usize);
            const mask = bitMask(bit);

            if ((changed & mask) == 0) continue;
            if ((ddr & mask) == 0) continue;

            const digital_pin = self.findDigitalPin(port.id, bit) orelse continue;
            const is_high = (new & mask) != 0;

            const seconds =
                @as(f64, @floatFromInt(self.cycles.*)) /
                @as(f64, @floatFromInt(self.clock_hz));

            std.debug.print("[{d:.6}s] [pin] D{} = {s}\n", .{
                seconds,
                digital_pin,
                if (is_high) "HIGH" else "LOW",
            });
        }
    }

    pub fn findDigitalPin(
        self: *const Gpio,
        port: mcu_spec.PortId,
        bit: u3,
    ) ?usize {
        for (self.board.digital_pins, 0..) |pin, index| {
            if (pin.port == port and pin.bit == bit) {
                return index;
            }
        }

        return null;
    }

    pub fn bitMask(bit: u3) u8 {
        return @as(u8, 1) << bit;
    }
};

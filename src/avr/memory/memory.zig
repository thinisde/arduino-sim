const std = @import("std");
const constants = @import("../constants/constants.zig");
const mcu_spec = @import("../../mcu/spec.zig");
const usart_mod = @import("../usart/usart.zig");
const timer_mod = @import("../timer/timer.zig");

pub const Flash = struct {
    bytes: []u8,

    pub fn init(
        allocator: std.mem.Allocator,
        mcu: *const mcu_spec.McuSpec,
    ) !Flash {
        const bytes = try allocator.alloc(u8, mcu.flash.size);
        @memset(bytes, mcu.flash.erased_byte);

        return .{
            .bytes = bytes,
        };
    }

    pub fn deinit(self: *Flash, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
        self.bytes = &[_]u8{};
    }

    pub fn initTest(allocator: std.mem.Allocator, size: usize, erased_byte: u8) !Flash {
        const bytes = try allocator.alloc(u8, size);
        @memset(bytes, erased_byte);
        return .{ .bytes = bytes };
    }

    pub fn writeByte(self: *Flash, address: usize, value: u8) !void {
        if (address >= self.bytes.len) {
            return error.FlashAddressOutOfRange;
        }

        self.bytes[address] = value;
    }

    pub fn readByte(self: *const Flash, address: usize) !u8 {
        if (address >= self.bytes.len) {
            return error.FlashAddressOutOfRange;
        }

        return self.bytes[address];
    }

    pub fn readWord(self: *const Flash, word_address: usize) !u16 {
        const byte_address =
            word_address * constants.Instruction.word_size_bytes;

        const lo = try self.readByte(byte_address);
        const hi = try self.readByte(byte_address + 1);

        return @as(u16, lo) | (@as(u16, hi) << 8);
    }
};

pub const PeripheralBus = struct {
    usarts: []?*usart_mod.Usart,
    timers: []?*timer_mod.Timer,
};

pub const DataMemory = struct {
    bytes: []u8,
    mcu: *const mcu_spec.McuSpec,

    pub fn init(
        allocator: std.mem.Allocator,
        mcu: *const mcu_spec.McuSpec,
    ) !DataMemory {
        const bytes = try allocator.alloc(u8, mcu.data.size);
        @memset(bytes, 0);

        return .{
            .bytes = bytes,
            .mcu = mcu,
        };
    }

    pub fn deinit(self: *DataMemory, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
        self.bytes = &[_]u8{};
    }

    pub fn readRawByte(self: *const DataMemory, address: u16) !u8 {
        const index: usize = @intCast(address);

        if (index >= self.bytes.len) {
            return error.DataAddressOutOfRange;
        }

        return self.bytes[index];
    }

    pub fn writeRawByte(self: *DataMemory, address: u16, value: u8) !void {
        const index: usize = @intCast(address);

        if (index >= self.bytes.len) {
            return error.DataAddressOutOfRange;
        }

        self.bytes[index] = value;
    }

    pub fn readByte(
        self: *DataMemory,
        address: u16,
        cycles: u64,
        peripherals: ?*PeripheralBus,
    ) !u8 {
        const value = try self.readRawByte(address);

        if (peripherals) |bus| {
            for (bus.usarts) |maybe_usart| {
                if (maybe_usart) |usart| {
                    if (usart.handles(address)) {
                        return usart.read(address, value, cycles);
                    }
                }
            }

            for (bus.timers) |maybe_timer| {
                if (maybe_timer) |timer| {
                    if (timer.handles(address)) {
                        return timer.read(address, value, cycles);
                    }
                }
            }
        }

        return value;
    }

    pub fn writeByte(
        self: *DataMemory,
        address: u16,
        value: u8,
        cycles: u64,
        peripherals: ?*PeripheralBus,
    ) !void {
        if (peripherals) |bus| {
            for (bus.usarts) |maybe_usart| {
                if (maybe_usart) |usart| {
                    if (usart.handles(address)) {
                        if (usart.write(address, value, cycles)) {
                            return;
                        }
                    }
                }
            }

            for (bus.timers) |maybe_timer| {
                if (maybe_timer) |timer| {
                    if (timer.handles(address)) {
                        if (timer.write(address, value, cycles)) {
                            return;
                        }
                    }
                }
            }
        }

        try self.writeRawByte(address, value);
    }

    pub fn ioToDataAddress(self: *const DataMemory, io_address: u16) u16 {
        return self.mcu.data.io_offset + io_address;
    }

    pub fn readIoByte(
        self: *DataMemory,
        io_address: u16,
        cycles: u64,
        peripherals: ?*PeripheralBus,
    ) !u8 {
        return self.readByte(
            self.ioToDataAddress(io_address),
            cycles,
            peripherals,
        );
    }

    pub fn writeIoByte(
        self: *DataMemory,
        io_address: u16,
        value: u8,
        cycles: u64,
        peripherals: ?*PeripheralBus,
    ) !void {
        return self.writeByte(
            self.ioToDataAddress(io_address),
            value,
            cycles,
            peripherals,
        );
    }
};


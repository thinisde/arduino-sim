const std = @import("std");
const constants = @import("../constants/constants.zig");
const mcu_spec = @import("../../mcu/spec.zig");
const usart_mod = @import("../usart/usart.zig");

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
    usart0: ?*usart_mod.Usart = null,
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
        peripherals: ?*PeripheralBus,
    ) !u8 {
        var value = try self.readRawByte(address);

        if (peripherals) |bus| {
            if (bus.usart0) |usart0| {
                value = usart0.read(address, value);
            }
        }

        return value;
    }

    pub fn writeByte(
        self: *DataMemory,
        address: u16,
        value: u8,
        cycles: u64,
        clock_hz: u64,
        peripherals: ?*PeripheralBus,
    ) !void {
        try self.writeRawByte(address, value);

        if (peripherals) |bus| {
            if (bus.usart0) |usart0| {
                _ = usart0.write(address, value, cycles, clock_hz);
            }
        }
    }

    pub fn ioToDataAddress(self: *const DataMemory, io_address: u16) u16 {
        return self.mcu.data.io_offset + io_address;
    }

    pub fn readIoByte(
        self: *DataMemory,
        io_address: u16,
        peripherals: ?*PeripheralBus,
    ) !u8 {
        return self.readByte(self.ioToDataAddress(io_address), peripherals);
    }

    pub fn writeIoByte(
        self: *DataMemory,
        io_address: u16,
        value: u8,
        cycles: u64,
        clock_hz: u64,
        peripherals: ?*PeripheralBus,
    ) !void {
        return self.writeByte(
            self.ioToDataAddress(io_address),
            value,
            cycles,
            clock_hz,
            peripherals,
        );
    }
};

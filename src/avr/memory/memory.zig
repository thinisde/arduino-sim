const std = @import("std");
const constants = @import("../constants/constants.zig");
const mcu_spec = @import("../../mcu/spec.zig");

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

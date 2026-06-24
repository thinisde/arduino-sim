const constants = @import("constants.zig");

pub const FlashSize = constants.Flash.size;

pub const Flash = struct {
    bytes: [FlashSize]u8 =
        [_]u8{constants.Flash.erased_byte} ** FlashSize,

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
        const byte_address = word_address * constants.Instruction.word_size_bytes;

        const lo = try self.readByte(byte_address);
        const hi = try self.readByte(byte_address + 1);

        return @as(u16, lo) | (@as(u16, hi) << 8);
    }
};

const std = @import("std");
const mcu_spec = @import("../../mcu/spec.zig");

fn bit(bit_index: u3) u8 {
    return @as(u8, 1) << bit_index;
}

pub const Usart = struct {
    spec: mcu_spec.UsartSpec,

    pub fn init(spec: mcu_spec.UsartSpec) Usart {
        return .{ .spec = spec };
    }

    pub fn handles(self: *const Usart, addr: u16) bool {
        return addr == self.spec.udr or addr == self.spec.ucsra or addr == self.spec.ucsrc or addr == self.spec.ubrrl or addr == self.spec.ubrrh or addr == self.spec.ucsrb;
    }

    pub fn read(self: *Usart, addr: u16, backing_value: u8) u8 {
        if (addr == self.spec.ucsra) {
            return backing_value | bit(self.spec.udre_bit) | bit(self.spec.txc_bit);
        }

        return backing_value;
    }

    pub fn write(self: *Usart, addr: u16, value: u8, cycles: u64, clock_hz: u64) bool {
        if (addr == self.spec.udr) {
            self.writeData(value, cycles, clock_hz);
            return true;
        }

        return false;
    }

    fn writeData(_: *Usart, value: u8, _: u64, _: u64) void {
        if (value == '\r') return;
        if (value == '\n') {
            std.debug.print("\n", .{});
            return;
        }

        // const simulated_seconds = @as(f64, @floatFromInt(cycles)) / @as(f64, @floatFromInt(clock_hz));
        //
        // std.debug.print("[{d:.6}]s [serial0] {c}\n", .{
        //     simulated_seconds,
        //     value,
        // });
        //
        std.debug.print("{c}", .{
            value,
        });
    }

    pub fn dataRegisterEmptyInterruptEnabled(self: *const Usart, ucsrb_value: u8) bool {
        return (ucsrb_value & bit(self.spec.udrie_bit)) != 0;
    }

    pub fn dataRegisterEmpty(self: *const Usart) bool {
        _ = self;
        return true; // TX-only model: always ready
    }
};

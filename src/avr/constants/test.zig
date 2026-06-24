const constants = @import("constants.zig");
const testing = @import("std").testing;

test "flash size and erased byte" {
    try testing.expectEqual(@as(usize, 32 * 1024), constants.Flash.size);
    try testing.expectEqual(@as(u8, 0xff), constants.Flash.erased_byte);
}

test "sram size and end" {
    try testing.expectEqual(@as(usize, 0x0900), constants.Sram.size);
    try testing.expectEqual(@as(u16, 0x08ff), constants.Sram.end);
}

test "opcode masks are non-zero" {
    try testing.expect(constants.Opcode.ldi_mask != 0);
    try testing.expect(constants.Opcode.add_mask != 0);
    try testing.expect(constants.Opcode.rjmp_mask != 0);
    try testing.expect(constants.Opcode.brne_mask != 0);
}

test "opcode patterns don't collide with masks" {
    try testing.expectEqual(constants.Opcode.ldi_pattern, constants.Opcode.ldi_mask & constants.Opcode.ldi_pattern);
    try testing.expectEqual(constants.Opcode.add_pattern, constants.Opcode.add_mask & constants.Opcode.add_pattern);
    try testing.expectEqual(constants.Opcode.rjmp_pattern, constants.Opcode.rjmp_mask & constants.Opcode.rjmp_pattern);
}

test "sreg bit positions are distinct" {
    const bits = [_]u3{ constants.Sreg.c, constants.Sreg.z, constants.Sreg.n, constants.Sreg.v, constants.Sreg.s, constants.Sreg.h, constants.Sreg.t, constants.Sreg.i };
    for (bits, 0..) |a, i| {
        for (bits, 0..) |b, j| {
            if (i != j) {
                try testing.expect(a != b);
            }
        }
    }
}

test "io addresses are within size" {
    try testing.expect(constants.Io.pinb < constants.Io.size);
    try testing.expect(constants.Io.ddrb < constants.Io.size);
    try testing.expect(constants.Io.portb < constants.Io.size);
    try testing.expect(constants.Io.tifr0 < constants.Io.size);
    try testing.expect(constants.Io.tccr0a < constants.Io.size);
    try testing.expect(constants.Io.tccr0b < constants.Io.size);
    try testing.expect(constants.Io.tcnt0 < constants.Io.size);
    try testing.expect(constants.Io.sreg < constants.Io.size);
}

test "data addresses are within size" {
    try testing.expect(constants.Data.sreg < constants.Data.size);
    try testing.expect(constants.Data.timsk0 < constants.Data.size);
    try testing.expect(constants.Data.tifr0 < constants.Data.size);
}

test "cycle counts are positive" {
    try testing.expect(constants.Cycles.nop > 0);
    try testing.expect(constants.Cycles.jmp > 0);
    try testing.expect(constants.Cycles.call > 0);
    try testing.expect(constants.Cycles.ret > 0);
    try testing.expect(constants.Cycles.register > 0);
}

test "timer0 prescaler values are unique within cs_mask" {
    const prescalers = [_]u8{
        constants.Timer0.Tccr0b.stopped,
        constants.Timer0.Tccr0b.prescale_1,
        constants.Timer0.Tccr0b.prescale_8,
        constants.Timer0.Tccr0b.prescale_64,
        constants.Timer0.Tccr0b.prescale_256,
        constants.Timer0.Tccr0b.prescale_1024,
    };
    for (prescalers, 0..) |a, i| {
        for (prescalers, 0..) |b, j| {
            if (i != j) {
                try testing.expect(a != b);
            }
            try testing.expect(a <= constants.Timer0.Tccr0b.cs_mask);
        }
    }
}

test "interrupt vector timer0_ovf is word address" {
    try testing.expectEqual(@as(u16, 0x0020), constants.InterruptVector.timer0_ovf_word);
}

test "pb5_mask is bit 5" {
    try testing.expectEqual(@as(u8, 1 << 5), constants.Io.pb5_mask);
}

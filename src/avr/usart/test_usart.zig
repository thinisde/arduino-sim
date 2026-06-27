const std = @import("std");
const testing = std.testing;
const usart = @import("usart.zig");
const tspec = @import("../../mcu/atmega328p.zig").usart0;

fn bit(bit_index: u3) u8 {
    return @as(u8, 1) << bit_index;
}

test "bit helper" {
    try testing.expectEqual(@as(u8, 0x01), bit(0));
    try testing.expectEqual(@as(u8, 0x02), bit(1));
    try testing.expectEqual(@as(u8, 0x80), bit(7));
}

test "dataMask 5 bits" {
    try testing.expectEqual(@as(u16, 0x001f), usart.Usart.dataMask(5));
}

test "dataMask 8 bits" {
    try testing.expectEqual(@as(u16, 0x00ff), usart.Usart.dataMask(8));
}

test "dataMask 9 bits" {
    try testing.expectEqual(@as(u16, 0x01ff), usart.Usart.dataMask(9));
}

test "ubrrValue" {
    var u = usart.Usart.init(tspec, 16_000_000);
    u.ubrrl_shadow = 0x67;
    u.ubrrh_shadow = 0x00;
    try testing.expectEqual(@as(u16, 0x0067), u.ubrrValue());
}

test "bitCycles normal speed" {
    var u = usart.Usart.init(tspec, 16_000_000);
    u.ubrrl_shadow = 0x67;
    u.ubrrh_shadow = 0x00;
    u.ucsra_shadow = 0;
    try testing.expectEqual(@as(u64, 16 * (0x67 + 1)), u.bitCycles());
}

test "bitCycles double speed" {
    var u = usart.Usart.init(tspec, 16_000_000);
    u.ubrrl_shadow = 0x67;
    u.ubrrh_shadow = 0x00;
    u.ucsra_shadow = bit(usart.Usart.u2x_bit);
    try testing.expectEqual(@as(u64, 8 * (0x67 + 1)), u.bitCycles());
}

test "bitCycles zero divider" {
    var u = usart.Usart.init(tspec, 16_000_000);
    u.ubrrl_shadow = 0;
    u.ubrrh_shadow = 0;
    u.ucsra_shadow = 0;
    try testing.expectEqual(@as(u64, 16), u.bitCycles());
}

test "frameConfig 8N1" {
    var u = usart.Usart.init(tspec, 16_000_000);
    u.ucsrc_shadow = 0x06;
    u.ubrrl_shadow = 0x67;
    u.ubrrh_shadow = 0x00;
    const cfg = u.frameConfig();
    try testing.expectEqual(@as(u4, 8), cfg.data_bits);
    try testing.expectEqual(usart.Usart.Parity.none, cfg.parity);
    try testing.expectEqual(@as(u2, 1), cfg.stop_bits);
}

test "frameConfig 7E1" {
    var u = usart.Usart.init(tspec, 16_000_000);
    u.ucsrc_shadow = 0x24;
    u.ubrrl_shadow = 0x67;
    u.ubrrh_shadow = 0x00;
    const cfg = u.frameConfig();
    try testing.expectEqual(@as(u4, 7), cfg.data_bits);
    try testing.expectEqual(usart.Usart.Parity.even, cfg.parity);
    try testing.expectEqual(@as(u2, 1), cfg.stop_bits);
}

test "frameConfig 8O2" {
    var u = usart.Usart.init(tspec, 16_000_000);
    u.ucsrc_shadow = 0x3e;
    u.ubrrl_shadow = 0x67;
    u.ubrrh_shadow = 0x00;
    const cfg = u.frameConfig();
    try testing.expectEqual(@as(u4, 8), cfg.data_bits);
    try testing.expectEqual(usart.Usart.Parity.odd, cfg.parity);
    try testing.expectEqual(@as(u2, 2), cfg.stop_bits);
}

test "frameConfig 5N1" {
    var u = usart.Usart.init(tspec, 16_000_000);
    u.ucsrc_shadow = 0x00;
    u.ubrrl_shadow = 0x67;
    u.ubrrh_shadow = 0x00;
    const cfg = u.frameConfig();
    try testing.expectEqual(@as(u4, 5), cfg.data_bits);
}

test "frameConfig 9N1" {
    var u = usart.Usart.init(tspec, 16_000_000);
    u.ucsrc_shadow = 0x06;
    u.ucsrb_shadow = bit(usart.Usart.ucsz2_bit);
    u.ubrrl_shadow = 0x67;
    u.ubrrh_shadow = 0x00;
    const cfg = u.frameConfig();
    try testing.expectEqual(@as(u4, 9), cfg.data_bits);
}

test "rxEnabled" {
    var u = usart.Usart.init(tspec, 16_000_000);
    try testing.expect(!u.rxEnabled());
    u.ucsrb_shadow = bit(tspec.rxen_bit);
    try testing.expect(u.rxEnabled());
}

test "txEnabled" {
    var u = usart.Usart.init(tspec, 16_000_000);
    try testing.expect(!u.txEnabled());
    u.ucsrb_shadow = bit(tspec.txen_bit);
    try testing.expect(u.txEnabled());
}

test "init sets UDRE flag" {
    const u = usart.Usart.init(tspec, 16_000_000);
    try testing.expectEqual(@as(u8, bit(tspec.udre_bit)), u.ucsra_shadow);
}

test "tx write when disabled drops data" {
    var u = usart.Usart.init(tspec, 16_000_000);
    _ = u.write(tspec.udr, 0x55, 0);
    try testing.expectEqual(null, u.tx_udr);
}

test "tx write shifts to tx_shift immediately" {
    var u = usart.Usart.init(tspec, 16_000_000);
    u.ucsrb_shadow = bit(tspec.txen_bit);
    _ = u.write(tspec.udr, 0x55, 0);
    try testing.expect(u.tx_shift != null);
    try testing.expectEqual(@as(u8, 0x55), u.tx_shift.?.byte);
    try testing.expectEqual(null, u.tx_udr);
}

test "txc pending after shift completes" {
    var u = usart.Usart.init(tspec, 16_000_000);
    u.ucsrb_shadow = bit(tspec.txen_bit);
    u.ubrrl_shadow = 0x67;
    _ = u.write(tspec.udr, 0x41, 0);
    try testing.expect(!u.txc_pending);
    u.tick(u.tx_shift_complete_cycle);
    try testing.expect(u.txc_pending);
    try testing.expect(u.tx_shift == null);
}

test "rx inject when disabled drops" {
    var u = usart.Usart.init(tspec, 16_000_000);
    u.injectRxByte(0x41, 0);
    try testing.expectEqual(@as(usize, 0), u.rx_input_len);
}

test "rx inject shifts to rx_shift immediately" {
    var u = usart.Usart.init(tspec, 16_000_000);
    u.ucsrb_shadow = bit(tspec.rxen_bit);
    u.ubrrl_shadow = 0x67;
    u.injectRxByte(0x42, 0);
    try testing.expect(u.rx_shift != null);
    try testing.expectEqual(@as(usize, 0), u.rx_input_len);
}

test "rx shift completes" {
    var u = usart.Usart.init(tspec, 16_000_000);
    u.ucsrb_shadow = bit(tspec.rxen_bit);
    u.ubrrl_shadow = 0x67;
    u.injectRxByte(0x44, 0);
    const complete_cycle = u.rx_shift_complete_cycle;
    u.tick(complete_cycle);
    try testing.expectEqual(@as(usize, 1), u.rx_len);
    try testing.expectEqual(@as(u8, 0x44), u.read(tspec.udr, 0, complete_cycle));
}

test "rx flush on disable" {
    var u = usart.Usart.init(tspec, 16_000_000);
    u.ucsrb_shadow = bit(tspec.rxen_bit);
    u.ubrrl_shadow = 0x67;
    u.injectRxByte(0x45, 0);
    u.tick(u.rx_shift_complete_cycle);
    try testing.expectEqual(@as(usize, 1), u.rx_len);
    _ = u.write(tspec.ucsrb, 0, 0);
    try testing.expectEqual(@as(usize, 0), u.rx_len);
}

test "dynamicUcsrAMask covers all flags" {
    const mask = usart.Usart.dynamicUcsrAMask(tspec);
    try testing.expect((mask & bit(tspec.rxc_bit)) != 0);
    try testing.expect((mask & bit(tspec.txc_bit)) != 0);
    try testing.expect((mask & bit(tspec.udre_bit)) != 0);
}

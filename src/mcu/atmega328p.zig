const mcu = @import("spec.zig");

pub const spec = mcu.McuSpec{
    .kind = .atmega328p,
    .name = "ATmega328P",
    .flash = .{
        .size = 32 * 1024,
        .erased_byte = 0xff,
    },
    .sram = .{
        .size = 2 * 1024,
        .start = 0x0100,
        .end = 0x08ff,
    },
    .io = .{
        .size = 64,

        .pinb = 0x03,
        .ddrb = 0x04,
        .portb = 0x05,

        .tifr0 = 0x15,
        .tccr0a = 0x24,
        .tccr0b = 0x25,
        .tcnt0 = 0x26,
        .ocr0a = 0x27,
        .ocr0b = 0x28,

        .spl = 0x3d,
        .sph = 0x3e,
        .sreg = 0x3f,
    },
    .data = .{
        .size = 0x0900,
        .io_offset = 0x20,

        .spl = 0x0023,
        .sph = 0x0024,
        .sreg = 0x005f,

        .pinb = 0x0023,
        .ddrb = 0x0024,
        .portb = 0x0025,

        .tifr0 = 0x0035,
        .tccr0a = 0x0044,
        .tccr0b = 0x0045,
        .tcnt0 = 0x0046,
        .ocr0a = 0x0047,
        .ocr0b = 0x0048,
        .timsk0 = 0x006e,
    },
    .timer0 = .{
        .max = 0xff,

        .tov0_bit = 0,
        .ocf0a_bit = 1,
        .ocf0b_bit = 2,

        .toie0_bit = 0,
        .ocie0a_bit = 1,
        .ocie0b_bit = 2,

        .cs_mask = 0b0000_0111,

        .stopped = 0,
        .prescale_1 = 1,
        .prescale_8 = 2,
        .prescale_64 = 3,
        .prescale_256 = 4,
        .prescale_1024 = 5,
    },
    .vectors = .{
        .timer0_ovf_index = 16,
        .timer0_ovf_word_addr = 0x0020,
        .timer0_ovf_byte_addr = 0x0040,

        .usart_udre_index = 19,
        .usart_udre_word_addr = 0x0026,
        .usart_udre_byte_addr = 0x004c,
    },
    .gpio_ports = &gpio_ports,
    .usart0 = .{
        .ucsra = 0x00c0,
        .ucsrb = 0x00c1,
        .ucsrc = 0x00c2,
        .ubrrl = 0x00c4,
        .ubrrh = 0x00c5,
        .udr = 0x00c6,

        .rxc_bit = 7,
        .txc_bit = 6,
        .udre_bit = 5,
        .u2x_bit = 1,

        .rxen_bit = 4,
        .txen_bit = 3,
        .udrie_bit = 5,
    },
};

pub const gpio_ports = [_]mcu.GpioPortSpec{
    .{
        .id = .B,
        .pin_io = 0x03,
        .ddr_io = 0x04,
        .port_io = 0x05,

        .pin_data = 0x0023,
        .ddr_data = 0x0024,
        .port_data = 0x0025,
    },
    .{
        .id = .C,
        .pin_io = 0x06,
        .ddr_io = 0x07,
        .port_io = 0x08,

        .pin_data = 0x0026,
        .ddr_data = 0x0027,
        .port_data = 0x0028,
    },
    .{
        .id = .D,
        .pin_io = 0x09,
        .ddr_io = 0x0a,
        .port_io = 0x0b,

        .pin_data = 0x0029,
        .ddr_data = 0x002a,
        .port_data = 0x002b,
    },
};

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

        .spl = 0x3d,
        .sph = 0x3e,
        .sreg = 0x3f,
    },
    .data = data,
    .timers = &.{
        timer0,
        timer1,
    },
    .gpio_ports = &gpio_ports,
    .usarts = &.{usart0},
};

pub const data = mcu.DataSpec{
    .size = 0x0900,
    .io_offset = 0x20,

    .spl = 0x005d,
    .sph = 0x005e,
    .sreg = 0x005f,

    .pinb = 0x0023,
    .ddrb = 0x0024,
    .portb = 0x0025,
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

pub const usart0 = mcu.UsartSpec{
    .index = 0,

    .udr = 0x00c6,
    .ucsra = 0x00c0,
    .ucsrb = 0x00c1,
    .ucsrc = 0x00c2,
    .ubrrl = 0x00c4,
    .ubrrh = 0x00c5,

    .rxc_bit = 7,
    .txc_bit = 6,
    .udre_bit = 5,

    .rxcie_bit = 7,
    .txcie_bit = 6,
    .udrie_bit = 5,
    .rxen_bit = 4,
    .txen_bit = 3,

    .rx_vector_word_addr = 0x0024,
    .udre_vector_word_addr = 0x0026,
    .tx_vector_word_addr = 0x0028,
};

pub const timer0 = mcu.TimerSpec{
    .name = "TIMER0",
    .width = .bits8,

    .tifr = 0x0035,
    .tccra = 0x0044,
    .tccrb = 0x0045,
    .tcntl = 0x0046,
    .ocral = 0x0047,
    .ocrbl = 0x0048,
    .timsk = 0x006e,

    .cs_mask = 0b0000_0111,
    .stopped = 0b0000_0000,

    .prescale_1 = 0b0000_0001,
    .prescale_8 = 0b0000_0010,
    .prescale_64 = 0b0000_0011,
    .prescale_256 = 0b0000_0100,
    .prescale_1024 = 0b0000_0101,

    .max = 0xff,

    .tov_bit = 0,
    .toie_bit = 0,

    .ocf_a_bit = 1,
    .ocie_a_bit = 1,

    .ocf_b_bit = 2,
    .ocie_b_bit = 2,

    .ovf_vector_word_addr = 0x0020,
};

pub const timer1 = mcu.TimerSpec{
    .name = "TIMER1",
    .width = .bits16,

    .tccra = 0x0080,
    .tccrb = 0x0081,
    .tccrc = 0x0082,

    .tcntl = 0x0084,
    .tcnth = 0x0085,

    .icrl = 0x0086,
    .icrh = 0x0087,

    .ocral = 0x0088,
    .ocrah = 0x0089,

    .ocrbl = 0x008a,
    .ocrbh = 0x008b,

    .timsk = 0x006f,
    .tifr = 0x0036,

    .cs_mask = 0b0000_0111,
    .stopped = 0b0000_0000,

    .prescale_1 = 0b0000_0001,
    .prescale_8 = 0b0000_0010,
    .prescale_64 = 0b0000_0011,
    .prescale_256 = 0b0000_0100,
    .prescale_1024 = 0b0000_0101,

    .max = 0xffff,

    .tov_bit = 0,
    .toie_bit = 0,

    .ocf_a_bit = 1,
    .ocie_a_bit = 1,

    .ocf_b_bit = 2,
    .ocie_b_bit = 2,

    .icf_bit = 5,
    .icie_bit = 5,

    .ovf_vector_word_addr = 0x001a,
};

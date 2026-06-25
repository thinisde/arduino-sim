pub const McuKind = enum {
    atmega328p,
};

pub const FlashSpec = struct {
    size: usize,
    erased_byte: u8,
};

pub const SramSpec = struct {
    size: usize,
    start: u16,
    end: u16,
};

pub const IoSpec = struct {
    size: usize,

    pinb: usize,
    ddrb: usize,
    portb: usize,

    tifr0: usize,
    tccr0a: usize,
    tccr0b: usize,
    tcnt0: usize,
    ocr0a: usize,
    ocr0b: usize,

    spl: usize,
    sph: usize,
    sreg: usize,
};

pub const DataSpec = struct {
    size: usize,
    io_offset: u16,

    spl: u16,
    sph: u16,
    sreg: u16,

    pinb: u16,
    ddrb: u16,
    portb: u16,

    tifr0: u16,
    tccr0a: u16,
    tccr0b: u16,
    tcnt0: u16,
    ocr0a: u16,
    ocr0b: u16,
    timsk0: u16,
};

pub const Timer0Spec = struct {
    max: u8,

    tov0_bit: u3,
    ocf0a_bit: u3,
    ocf0b_bit: u3,

    toie0_bit: u3,
    ocie0a_bit: u3,
    ocie0b_bit: u3,

    cs_mask: u8,

    stopped: u8,
    prescale_1: u8,
    prescale_8: u8,
    prescale_64: u8,
    prescale_256: u8,
    prescale_1024: u8,
};

pub const VectorSpec = struct {
    timer0_ovf_index: u16,
    timer0_ovf_word_addr: u16,
    timer0_ovf_byte_addr: u16,

    usart_udre_index: u8,
    usart_udre_word_addr: u16,
    usart_udre_byte_addr: u16,
};

pub const UsartSpec = struct {
    udr: u16,
    ucsra: u16,
    ucsrb: u16,
    ucsrc: u16,
    ubrrl: u16,
    ubrrh: u16,

    rxen_bit: u3,
    txen_bit: u3,
    udrie_bit: u3,

    rxc_bit: u3,
    txc_bit: u3,
    udre_bit: u3,
    u2x_bit: u3,
};

pub const McuSpec = struct {
    kind: McuKind,
    name: []const u8,
    flash: FlashSpec,
    sram: SramSpec,
    io: IoSpec,
    data: DataSpec,
    timer0: Timer0Spec,
    vectors: VectorSpec,
    gpio_ports: []const GpioPortSpec,
    usart0: ?UsartSpec,
};

pub const PortId = enum {
    B,
    C,
    D,
};

pub const GpioPortSpec = struct {
    id: PortId,

    pin_io: usize,
    ddr_io: usize,
    port_io: usize,

    pin_data: u16,
    ddr_data: u16,
    port_data: u16,
};

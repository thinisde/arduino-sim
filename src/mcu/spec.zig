pub const MaxUsarts = 4;
pub const MaxTimers = 2;

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
};

pub const TimerWidth = enum {
    bits8,
    bits16,
};

pub const TimerSpec = struct {
    name: []const u8,
    width: TimerWidth,

    // Data-space register addresses
    tccra: ?u16 = null,
    tccrb: ?u16 = null,
    tccrc: ?u16 = null,

    tcntl: ?u16 = null,
    tcnth: ?u16 = null,

    ocral: ?u16 = null,
    ocrah: ?u16 = null,

    ocrbl: ?u16 = null,
    ocrbh: ?u16 = null,

    icrl: ?u16 = null,
    icrh: ?u16 = null,

    timsk: ?u16 = null,
    tifr: ?u16 = null,

    // Clock select / prescaler config
    cs_mask: u8,
    stopped: u8,

    prescale_1: ?u8 = null,
    prescale_8: ?u8 = null,
    prescale_32: ?u8 = null,
    prescale_64: ?u8 = null,
    prescale_128: ?u8 = null,
    prescale_256: ?u8 = null,
    prescale_1024: ?u8 = null,

    // Counter range
    max: u16,

    // Overflow interrupt bits
    tov_bit: u3,
    toie_bit: u3,

    // Optional compare interrupt bits
    ocf_a_bit: ?u3 = null,
    ocie_a_bit: ?u3 = null,

    ocf_b_bit: ?u3 = null,
    ocie_b_bit: ?u3 = null,

    icf_bit: ?u3 = null,
    icie_bit: ?u3 = null,

    ovf_vector_word_addr: u16,
};

pub const UsartSpec = struct {
    index: usize,

    udr: u16,
    ucsra: u16,
    ucsrb: u16,
    ucsrc: u16,
    ubrrl: u16,
    ubrrh: u16,

    rxc_bit: u3,
    txc_bit: u3,
    udre_bit: u3,

    rxcie_bit: u3,
    txcie_bit: u3,
    udrie_bit: u3,
    rxen_bit: u3,
    txen_bit: u3,

    rx_vector_word_addr: u16,
    udre_vector_word_addr: u16,
    tx_vector_word_addr: u16,
};

pub const McuSpec = struct {
    kind: McuKind,
    name: []const u8,
    flash: FlashSpec,
    sram: SramSpec,
    io: IoSpec,
    data: DataSpec,
    timers: []const TimerSpec,
    gpio_ports: []const GpioPortSpec,
    usarts: []const UsartSpec,
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

pub const Flash = struct {
    pub const size = 32 * 1024;
    pub const erased_byte: u8 = 0xff;
};

pub const Sram = struct {
    // ATmega328P SRAM ends at 0x08ff.
    // The stack starts here and grows downward.
    pub const end: u16 = 0x08ff;
};

pub const Instruction = struct {
    pub const word_size_bytes = 2;
};

pub const Cycles = struct {
    pub const nop = 1;
    pub const rjmp = 2;
    pub const jmp = 3;
};

pub const Opcode = struct {
    pub const nop: u16 = 0x0000;

    pub const jmp_mask: u16 = 0xfe0e;
    pub const jmp_pattern: u16 = 0x940c;

    pub const rjmp_mask: u16 = 0xf000;
    pub const rjmp_pattern: u16 = 0xc000;

    pub const ldi_mask: u16 = 0xf000;
    pub const ldi_pattern: u16 = 0xe000;
};

pub const Jmp = struct {
    pub const high_bits_mask: u16 = 0x01f0;
    pub const low_high_bit_mask: u16 = 0x0001;

    pub const high_bits_shift = 13;
    pub const low_high_bit_shift = 16;
};

pub const Rjmp = struct {
    pub const offset_mask: u16 = 0x0fff;
    pub const sign_bit: u16 = 0x0800;
    pub const sign_extend_subtract: i32 = 0x1000;
};

pub const Ldi = struct {
    pub const register_base: usize = 16;
    pub const register_mask: u16 = 0x00f0;
    pub const register_shift = 4;

    pub const imm_low_mask: u16 = 0x000f;
    pub const imm_high_mask: u16 = 0x0f00;
    pub const imm_high_shift = 4;

    pub const cycles = 1;
};

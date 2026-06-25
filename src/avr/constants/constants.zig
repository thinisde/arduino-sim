pub const Instruction = struct {
    pub const word_size_bytes = 2;
};

pub const Cycles = struct {
    pub const nop = 1;
    pub const rjmp = 2;
    pub const jmp = 3;
    pub const call = 4;
    pub const rcall = 3;
    pub const ret = 4;
    pub const reti = 4;
    pub const interrupt_entry = 4;

    pub const branch_taken = 2;
    pub const branch_not_taken = 1;
    pub const out = 1;
    pub const in = 1;
    pub const sbi = 2;
    pub const cbi = 2;
    pub const register = 1;
    pub const push = 2;
    pub const pop = 2;
    pub const skip_not_taken = 1;
    pub const lds = 2;
    pub const sts = 2;
    pub const ld = 2;
    pub const st = 2;
    pub const lpm = 3;
    pub const skip_one_word = 2;
    pub const skip_two_word = 3;
};

pub const Opcode = struct {
    pub const nop: u16 = 0x0000;

    pub const jmp_mask: u16 = 0xfe0e;
    pub const jmp_pattern: u16 = 0x940c;

    pub const rjmp_mask: u16 = 0xf000;
    pub const rjmp_pattern: u16 = 0xc000;

    pub const ldi_mask: u16 = 0xf000;
    pub const ldi_pattern: u16 = 0xe000;

    pub const out_mask: u16 = 0xf800;
    pub const out_pattern: u16 = 0xb800;

    pub const in_mask: u16 = 0xf800;
    pub const in_pattern: u16 = 0xb000;

    pub const sbi_mask: u16 = 0xff00;
    pub const sbi_pattern: u16 = 0x9a00;

    pub const cbi_mask: u16 = 0xff00;
    pub const cbi_pattern: u16 = 0x9800;

    pub const mov_mask: u16 = 0xfc00;
    pub const mov_pattern: u16 = 0x2c00;

    pub const eor_mask: u16 = 0xfc00;
    pub const eor_pattern: u16 = 0x2400;

    pub const ori_mask: u16 = 0xf000;
    pub const ori_pattern: u16 = 0x6000;

    pub const andi_mask: u16 = 0xf000;
    pub const andi_pattern: u16 = 0x7000;

    pub const inc_mask: u16 = 0xfe0f;
    pub const inc_pattern: u16 = 0x9403;

    pub const dec_mask: u16 = 0xfe0f;
    pub const dec_pattern: u16 = 0x940a;

    pub const cpi_mask: u16 = 0xf000;
    pub const cpi_pattern: u16 = 0x3000;

    pub const cp_mask: u16 = 0xfc00;
    pub const cp_pattern: u16 = 0x1400;

    pub const brne_mask: u16 = 0xfc07;
    pub const brne_pattern: u16 = 0xf401;

    pub const breq_mask: u16 = 0xfc07;
    pub const breq_pattern: u16 = 0xf001;

    pub const call_mask: u16 = 0xfe0e;
    pub const call_pattern: u16 = 0x940e;

    pub const rcall_mask: u16 = 0xf000;
    pub const rcall_pattern: u16 = 0xd000;

    pub const ret: u16 = 0x9508;

    pub const push_mask: u16 = 0xfe0f;
    pub const push_pattern: u16 = 0x920f;

    pub const pop_mask: u16 = 0xfe0f;
    pub const pop_pattern: u16 = 0x900f;

    pub const add_mask: u16 = 0xfc00;
    pub const add_pattern: u16 = 0x0c00;

    pub const adc_mask: u16 = 0xfc00;
    pub const adc_pattern: u16 = 0x1c00;

    pub const sub_mask: u16 = 0xfc00;
    pub const sub_pattern: u16 = 0x1800;

    pub const sbc_mask: u16 = 0xfc00;
    pub const sbc_pattern: u16 = 0x0800;

    pub const cpc_mask: u16 = 0xfc00;
    pub const cpc_pattern: u16 = 0x0400;

    pub const cpse_mask: u16 = 0xfc00;
    pub const cpse_pattern: u16 = 0x1000;

    pub const and_mask: u16 = 0xfc00;
    pub const and_pattern: u16 = 0x2000;

    pub const or_mask: u16 = 0xfc00;
    pub const or_pattern: u16 = 0x2800;

    pub const subi_mask: u16 = 0xf000;
    pub const subi_pattern: u16 = 0x5000;

    pub const sbci_mask: u16 = 0xf000;
    pub const sbci_pattern: u16 = 0x4000;

    pub const adiw_mask: u16 = 0xff00;
    pub const adiw_pattern: u16 = 0x9600;

    pub const sbiw_mask: u16 = 0xff00;
    pub const sbiw_pattern: u16 = 0x9700;

    pub const brcc_mask: u16 = 0xfc07;
    pub const brcc_pattern: u16 = 0xf400;

    pub const brcs_mask: u16 = 0xfc07;
    pub const brcs_pattern: u16 = 0xf000;

    pub const cli: u16 = 0x94f8;
    pub const sei: u16 = 0x9478;
    pub const reti: u16 = 0x9518;

    pub const com_mask: u16 = 0xfe0f;
    pub const com_pattern: u16 = 0x9400;

    pub const movw_mask: u16 = 0xff00;
    pub const movw_pattern: u16 = 0x0100;

    pub const lds_mask: u16 = 0xfe0f;
    pub const lds_pattern: u16 = 0x9000;

    pub const sts_mask: u16 = 0xfe0f;
    pub const sts_pattern: u16 = 0x9200;

    pub const sbis_mask: u16 = 0xff00;
    pub const sbis_pattern: u16 = 0x9b00;

    pub const lpm: u16 = 0x95c8;
    pub const lpm_z_mask: u16 = 0xfe0e;
    pub const lpm_z_pattern: u16 = 0x9004;

    pub const ld_x_mask: u16 = 0xfe0f;
    pub const ld_x_pattern: u16 = 0x900c;
    pub const ld_x_postincrement_mask: u16 = 0xfe0f;
    pub const ld_x_postincrement_pattern: u16 = 0x900d;
    pub const ld_x_predecrement_mask: u16 = 0xfe0f;
    pub const ld_x_predecrement_pattern: u16 = 0x900e;
    pub const ld_z_mask: u16 = 0xd208;
    pub const ld_z_pattern: u16 = 0x8000;
    pub const ld_y_mask: u16 = 0xd208;
    pub const ld_y_pattern: u16 = 0x8008;

    pub const ldd_std_mask: u16 = 0xd208;

    pub const ldd_z_pattern: u16 = 0x8000;
    pub const ldd_y_pattern: u16 = 0x8008;

    pub const std_z_pattern: u16 = 0x8200;
    pub const std_y_pattern: u16 = 0x8208;

    pub const st_x_mask: u16 = 0xfe0f;
    pub const st_x_pattern: u16 = 0x920c;
    pub const st_x_postincrement_mask: u16 = 0xfe0f;
    pub const st_x_postincrement_pattern: u16 = 0x920d;
    pub const st_x_predecrement_mask: u16 = 0xfe0f;
    pub const st_x_predecrement_pattern: u16 = 0x920e;
    pub const st_z_mask: u16 = 0xd208;
    pub const st_z_pattern: u16 = 0x8200;
    pub const st_y_mask: u16 = 0xd208;
    pub const st_y_pattern: u16 = 0x8208;

    pub const ld_z_postincrement_mask: u16 = 0xfe0f;
    pub const ld_z_postincrement_pattern: u16 = 0x9001;
    pub const ld_z_predecrement_mask: u16 = 0xfe0f;
    pub const ld_z_predecrement_pattern: u16 = 0x9002;
    pub const ld_y_postincrement_mask: u16 = 0xfe0f;
    pub const ld_y_postincrement_pattern: u16 = 0x9009;
    pub const ld_y_predecrement_mask: u16 = 0xfe0f;
    pub const ld_y_predecrement_pattern: u16 = 0x900a;

    pub const st_z_postincrement_mask: u16 = 0xfe0f;
    pub const st_z_postincrement_pattern: u16 = 0x9201;
    pub const st_z_predecrement_mask: u16 = 0xfe0f;
    pub const st_z_predecrement_pattern: u16 = 0x9202;
    pub const st_y_postincrement_mask: u16 = 0xfe0f;
    pub const st_y_postincrement_pattern: u16 = 0x9209;
    pub const st_y_predecrement_mask: u16 = 0xfe0f;
    pub const st_y_predecrement_pattern: u16 = 0x920a;

    pub const bset_mask: u16 = 0xff8f;
    pub const bset_pattern: u16 = 0x9408;
    pub const bclr_mask: u16 = 0xff8f;
    pub const bclr_pattern: u16 = 0x9488;

    pub const sbrc_mask: u16 = 0xfe08;
    pub const sbrc_pattern: u16 = 0xfc00;
    pub const sbrs_mask: u16 = 0xfe08;
    pub const sbrs_pattern: u16 = 0xfe00;

    pub const sbic_mask: u16 = 0xff00;
    pub const sbic_pattern: u16 = 0x9900;

    pub const bst_mask: u16 = 0xfe08;
    pub const bst_pattern: u16 = 0xfa00;
    pub const bld_mask: u16 = 0xfe08;
    pub const bld_pattern: u16 = 0xf800;

    pub const mul_mask: u16 = 0xfc00;
    pub const mul_pattern: u16 = 0x9c00;
    pub const muls_mask: u16 = 0xff00;
    pub const muls_pattern: u16 = 0x0200;
    pub const mul_su_fm_variants_mask: u16 = 0xff88;
    pub const mulsu_pattern: u16 = 0x0300;
    pub const fmul_pattern: u16 = 0x0308;
    pub const fmuls_pattern: u16 = 0x0380;
    pub const fmulsu_pattern: u16 = 0x0388;

    pub const lsr_mask: u16 = 0xfe0f;
    pub const lsr_pattern: u16 = 0x9406;
    pub const ror_mask: u16 = 0xfe0f;
    pub const ror_pattern: u16 = 0x9407;
    pub const asr_mask: u16 = 0xfe0f;
    pub const asr_pattern: u16 = 0x9405;
    pub const swap_mask: u16 = 0xfe0f;
    pub const swap_pattern: u16 = 0x9402;
    pub const neg_mask: u16 = 0xfe0f;
    pub const neg_pattern: u16 = 0x9401;

    pub const sleep: u16 = 0x9588;
    pub const wdr: u16 = 0x95a8;
    pub const break_opcode: u16 = 0x9598;

    pub const des_mask: u16 = 0xff0f;
    pub const des_pattern: u16 = 0x940b;

    pub const xch_mask: u16 = 0xfe0f;
    pub const xch_pattern: u16 = 0x9204;
    pub const las_mask: u16 = 0xfe0f;
    pub const las_pattern: u16 = 0x9205;
    pub const lac_mask: u16 = 0xfe0f;
    pub const lac_pattern: u16 = 0x9206;
    pub const lat_mask: u16 = 0xfe0f;
    pub const lat_pattern: u16 = 0x9207;

    pub const icall: u16 = 0x9509;
    pub const ijmp: u16 = 0x9409;
    pub const eicall: u16 = 0x9519;
    pub const eijmp: u16 = 0x9419;

    pub const elpm_implicit: u16 = 0x95d8;
    pub const elpm_z_mask: u16 = 0xfe0f;
    pub const elpm_z_pattern: u16 = 0x9006;
    pub const elpm_z_postincrement_mask: u16 = 0xfe0f;
    pub const elpm_z_postincrement_pattern: u16 = 0x9007;

    pub const spm: u16 = 0x95e8;
    pub const spm_z_plus: u16 = 0x95f8;

    pub const branch_mask: u16 = 0xfc07;
};

pub const Jmp = struct {
    pub const high_bits_mask: u16 = 0x01f0;
    pub const low_high_bit_mask: u16 = 0x0001;

    pub const high_bits_shift = 13;
    pub const low_high_bit_shift = 16;
};

pub const Call = Jmp;

pub const Rjmp = struct {
    pub const offset_mask: u16 = 0x0fff;
    pub const sign_bit: u16 = 0x0800;
    pub const sign_extend_subtract: i32 = 0x1000;
};

pub const Rcall = Rjmp;

pub const Ldi = struct {
    pub const register_base: usize = 16;
    pub const register_mask: u16 = 0x00f0;
    pub const register_shift = 4;

    pub const imm_low_mask: u16 = 0x000f;
    pub const imm_high_mask: u16 = 0x0f00;
    pub const imm_high_shift = 4;

    pub const cycles = 1;
};

pub const Immediate = Ldi;

pub const Out = struct {
    pub const io_low_mask: u16 = 0x000f;
    pub const io_high_mask: u16 = 0x0600;
    pub const io_high_shift = 5;

    pub const register_mask: u16 = 0x01f0;
    pub const register_shift = 4;
};

pub const In = Out;

pub const RegisterPair = struct {
    pub const destination_mask: u16 = 0x01f0;
    pub const destination_shift = 4;

    pub const source_low_mask: u16 = 0x000f;
    pub const source_high_mask: u16 = 0x0200;
    pub const source_high_shift = 5;
};

pub const SingleRegister = struct {
    pub const register_mask: u16 = 0x01f0;
    pub const register_shift = 4;
};

pub const BitIo = struct {
    pub const io_mask: u16 = 0x00f8;
    pub const io_shift = 3;

    pub const bit_mask: u16 = 0x0007;
};

pub const Branch = struct {
    pub const offset_mask: u16 = 0x03f8;
    pub const offset_shift = 3;
    pub const sign_bit: u16 = 0x0040;
    pub const sign_extend_subtract: i32 = 0x0080;
};

pub const WordImmediate = struct {
    pub const register_base: usize = 24;
    pub const register_mask: u16 = 0x0030;
    pub const register_shift = 3;

    pub const imm_low_mask: u16 = 0x000f;
    pub const imm_high_mask: u16 = 0x00c0;
    pub const imm_high_shift = 2;
};

pub const RegisterPairMove = struct {
    pub const destination_mask: u16 = 0x00f0;
    pub const destination_shift = 3;

    pub const source_mask: u16 = 0x000f;
    pub const source_shift = 1;
};

pub const Sreg = struct {
    pub const c: u3 = 0;
    pub const z: u3 = 1;
    pub const n: u3 = 2;
    pub const v: u3 = 3;
    pub const s: u3 = 4;
    pub const h: u3 = 5;
    pub const t: u3 = 6;
    pub const i: u3 = 7;
};

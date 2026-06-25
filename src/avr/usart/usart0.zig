pub const Usart0 = struct {
    const RXC0: u8 = 1 << 7;
    const TXC0: u8 = 1 << 6;
    const UDRE0: u8 = 1 << 5;
    const DOR0: u8 = 1 << 3;
    const U2X0: u8 = 1 << 1;
    const MPCM0: u8 = 1 << 0;

    const RXCIE0: u8 = 1 << 7;
    const RXEN0: u8 = 1 << 4;
    const TXEN0: u8 = 1 << 3;

    ucsr0a: u8 = UDRE0,
    ucsr0b: u8 = 0,
    ucsr0c: u8 = 0,
    ubrr0: u16 = 0,

    rx_buf: [128]u8 = undefined,
    rx_head: usize = 0,
    rx_tail: usize = 0,
    rx_len: usize = 0,

    pub fn readData(self: *Usart0, addr: u16) ?u8 {
        return switch (addr) {
            0x00c0 => self.readUcsr0a(),
            0x00c1 => self.ucsr0b,
            0x00c2 => self.ucsr0c,
            0x00c4 => @truncate(self.ubrr0),
            0x00c5 => @truncate(self.ubrr0 >> 8),
            0x00c6 => self.readUdr0(),
            else => null,
        };
    }

    pub fn writeData(self: *Usart0, addr: u16, value: u8, writer: anytype) !bool {
        switch (addr) {
            0x00c0 => {
                // TXC0 is cleared by writing 1. Keep UDRE0 managed by simulator.
                if ((value & TXC0) != 0) self.ucsr0a &= ~TXC0;

                const writable = U2X0 | MPCM0;
                self.ucsr0a = (self.ucsr0a & ~writable) | (value & writable);
                self.refreshRxFlag();
                self.ucsr0a |= UDRE0;
                return true;
            },
            0x00c1 => {
                const was_rx_enabled = (self.ucsr0b & RXEN0) != 0;
                self.ucsr0b = value;

                if (was_rx_enabled and (value & RXEN0) == 0) {
                    self.clearRx();
                }

                self.refreshRxFlag();
                return true;
            },
            0x00c2 => {
                self.ucsr0c = value;
                return true;
            },
            0x00c4 => {
                self.ubrr0 = (self.ubrr0 & 0xff00) | value;
                return true;
            },
            0x00c5 => {
                self.ubrr0 = (self.ubrr0 & 0x00ff) | (@as(u16, value) << 8);
                return true;
            },
            0x00c6 => {
                try self.writeUdr0(value, writer);
                return true;
            },
            else => return false,
        }
    }

    pub fn injectRxByte(self: *Usart0, value: u8) void {
        // Real-ish behavior: receiver disabled means incoming data is ignored.
        if ((self.ucsr0b & RXEN0) == 0) return;

        if (self.rx_len == self.rx_buf.len) {
            self.ucsr0a |= DOR0;
            return;
        }

        self.rx_buf[self.rx_tail] = value;
        self.rx_tail = (self.rx_tail + 1) % self.rx_buf.len;
        self.rx_len += 1;
        self.refreshRxFlag();
    }

    pub fn hasRxInterrupt(self: *const Usart0) bool {
        return (self.ucsr0a & RXC0) != 0 and
            (self.ucsr0b & RXCIE0) != 0;
    }

    fn readUcsr0a(self: *Usart0) u8 {
        self.refreshRxFlag();
        self.ucsr0a |= UDRE0;
        return self.ucsr0a;
    }

    fn readUdr0(self: *Usart0) u8 {
        if (self.rx_len == 0) {
            self.refreshRxFlag();
            return 0;
        }

        const value = self.rx_buf[self.rx_head];
        self.rx_head = (self.rx_head + 1) % self.rx_buf.len;
        self.rx_len -= 1;

        // Clear error bits after data is consumed for a simple first model.
        if (self.rx_len == 0) {
            self.ucsr0a &= ~DOR0;
        }

        self.refreshRxFlag();
        return value;
    }

    fn writeUdr0(self: *Usart0, value: u8, writer: anytype) !void {
        if ((self.ucsr0b & TXEN0) != 0) {
            try writer.writeByte(value);
        }

        // Simplified immediate transmit completion.
        self.ucsr0a |= UDRE0;
        self.ucsr0a |= TXC0;
    }

    fn refreshRxFlag(self: *Usart0) void {
        if ((self.ucsr0b & RXEN0) != 0 and self.rx_len > 0) {
            self.ucsr0a |= RXC0;
        } else {
            self.ucsr0a &= ~RXC0;
        }
    }

    fn clearRx(self: *Usart0) void {
        self.rx_head = 0;
        self.rx_tail = 0;
        self.rx_len = 0;
        self.ucsr0a &= ~(RXC0 | DOR0);
    }
};

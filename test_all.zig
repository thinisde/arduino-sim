test {
    _ = @import("src/loader/test_hex.zig");
    _ = @import("src/avr/cpu/test_decode.zig");
    _ = @import("src/avr/usart/test_usart.zig");
    _ = @import("src/avr/timer/test_timer.zig");
    _ = @import("src/avr/memory/test_memory.zig");
    _ = @import("src/avr/gpio/test_gpio.zig");
    _ = @import("src/board/test_registry.zig");
}

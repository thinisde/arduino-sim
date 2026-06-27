# Arduino Simulator

A Zig-based simulator for Arduino Uno and AVR programs.

The project aims to run Arduino sketches, AVR C/C++ programs, and compiled AVR HEX/ELF output without physical hardware. It currently focuses on the Arduino Uno / ATmega328P platform while moving toward a data-driven architecture that can support multiple boards and MCUs.

## Features

- AVR instruction execution
- Intel HEX loading
- Arduino Uno / ATmega328P board model
- GPIO output simulation
- Timer0 overflow interrupt support
- Arduino `pinMode`, `digitalWrite`, and `delay` support
- Cycle-counted simulated time
- Optional real-time throttling
- Dynamic board and MCU specification structure

## Project Status

The simulator can currently run Arduino Uno / ATmega328P sketches that use Arduino startup, digital output, Timer0-based delays, interrupts, and basic serial I/O.

Supported or partially supported:

* AVR CPU core
* Flash memory loading from Intel HEX
* SRAM and data/I/O memory access
* Stack pointer handling
* Global interrupt handling
* `RET` / `RETI`
* Timer0 ticking
* Timer0 overflow interrupt dispatch
* Arduino `delay()`, `micros()`, and Timer0 ISR behavior
* Basic GPIO side effects
* Arduino Uno digital pin mapping, including D13 / PB5
* USART/UART transmit output through simulated `UDR`
* USART/UART receive input through simulated RX queue
* USART RX complete interrupt dispatch
* Arduino `Serial.print`, `Serial.write`, `Serial.available`, and `Serial.read` for simple echo-style sketches
* Host terminal input polling into the simulated default serial USART
* MCU/board spec structure for multiple USART interfaces

Known limitations or incomplete areas:

* USART line-level waveform/noise behavior is still simplified
* ADC
* PWM
* Timer1
* Timer2
* SPI
* I2C / TWI
* EEPROM
* External interrupts
* Pin-change interrupts
* Watchdog
* Sleep modes
* Analog comparator
* More complete AVR opcode coverage as required by compiled sketches

## Requirements

- Zig
- Arduino CLI
- AVR toolchain, including tools such as `avr-objdump` and `avr-nm`

## Building

```bash
zig build
```

Run tests:

```bash
zig build test
```

Format source files:

```bash
zig fmt src
```

## Compiling an Arduino Sketch

Example using Arduino CLI:

```bash
arduino-cli compile \
  -b arduino:avr:uno \
  --export-binaries \
  examples/arduino/d13_with_delay_fast
```

This produces a HEX file under the sketch build directory, for example:

```text
examples/arduino/d13_with_delay_fast/build/arduino.avr.uno/d13_with_delay_fast.ino.hex
```

## Running the Simulator

Run a compiled Arduino HEX file:

```bash
zig build run -- \
  examples/arduino/d13_with_delay_fast/build/arduino.avr.uno/d13_with_delay_fast.ino.hex \
  --steps 1000000
```

Run with an explicit board:

```bash
zig build run -- \
  --board arduino-uno \
  examples/arduino/d13_with_delay_fast/build/arduino.avr.uno/d13_with_delay_fast.ino.hex \
  --steps 1000000
```

Run with real-time throttling:

```bash
zig build run -- \
  --board arduino-uno \
  --real-time \
  examples/arduino/d13_with_delay_fast/build/arduino.avr.uno/d13_with_delay_fast.ino.hex \
  --steps 1000000
```

Run indefinitely:

```bash
zig build run -- \
  --board arduino-uno \
  --run-forever \
  examples/arduino/d13_with_delay_fast/build/arduino.avr.uno/d13_with_delay_fast.ino.hex
```

Stop a long-running simulation with `Ctrl+C`.

## Example Output

For a sketch that toggles the built-in LED on pin 13:

```text
[0.000011s] [pin] D13 mode = OUTPUT
[0.000014s] [pin] D13 = HIGH
[1.000023s] [pin] D13 = LOW
[2.000033s] [pin] D13 = HIGH
[3.000042s] [pin] D13 = LOW
```

## Command-Line Options

Common options:

```text
--board <name>       Select the target board
--steps <count>      Run for a fixed number of CPU steps
--run-forever        Run until interrupted
--real-time          Throttle execution to simulated wall-clock time
--quiet              Suppress normal output
--trace              Print instruction trace output
```

Available boards currently include:

```text
arduino-uno
```

## Architecture

The simulator is organized around three layers:

```text
AVR CPU core
  Generic instruction decoding and execution

MCU model
  Register layout, memory map, timers, interrupt vectors, and peripherals

Board model
  Clock speed, digital pin mapping, built-in LED, and selected MCU
```

The goal is to keep the CPU core generic. Board-specific and MCU-specific details should live in board and MCU specifications rather than being hardcoded inside CPU instruction execution.

## Source Layout

```text
src
├── avr
│   ├── constants
│   ├── cpu
│   ├── gpio
│   ├── memory
│   └── timer
├── board
├── loader
├── mcu
├── main.zig
└── root.zig
```

Important areas:

- `src/avr/cpu` — AVR instruction decoding and execution
- `src/avr/timer` — Timer peripherals
- `src/avr/gpio` — GPIO side effects and board pin output
- `src/avr/memory` — Flash and memory access
- `src/board` — Board definitions such as Arduino Uno
- `src/mcu` — MCU definitions such as ATmega328P
- `src/loader` — HEX loading

## Inspecting Compiled AVR Output

List symbols:

```bash
avr-nm -n path/to/sketch.ino.elf
```

Disassemble:

```bash
avr-objdump -d -C path/to/sketch.ino.elf
```

List emitted AVR instructions:

```bash
./scripts/list-avr-instructions.sh path/to/sketch.ino.elf
```

The simulator program counter is word-addressed, while `avr-objdump` addresses are byte-addressed:

```text
byte address = word address * 2
```

## Adding a Board

A board specification should define:

- Board name
- MCU reference
- Clock speed
- Digital pin mapping
- Built-in LED pin, if available

Example responsibilities:

```text
Arduino Uno
  MCU: ATmega328P
  Clock: 16 MHz
  Digital pins: D0-D13
  Built-in LED: D13
```

## Adding an MCU

An MCU specification should define:

- Flash size
- SRAM range
- I/O register addresses
- Data-space register addresses
- Timer register layout
- Interrupt vectors
- GPIO port mappings

Instruction opcode masks and generic AVR CPU constants should remain in the AVR constants module, not in MCU definitions.

## Development Notes

Useful commands:

```bash
zig fmt src
zig build
zig build test
```

Run the main Arduino Uno regression sketch:

```bash
zig build run -- \
  --board arduino-uno \
  examples/arduino/d13_with_delay_fast/build/arduino.avr.uno/d13_with_delay_fast.ino.hex \
  --steps 1000000
```

Expected output includes pin mode and pin state changes for D13.

## License

Add a license for this project before publishing.

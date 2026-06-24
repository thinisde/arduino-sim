#!/usr/bin/env bash
set -euo pipefail

name="$1"

mkdir -p build

avr-gcc -mmcu=atmega328p -Os -DF_CPU=16000000UL \
  -o "build/${name}.elf" \
  "examples/bare/${name}.c"

avr-objcopy -O ihex -R .eeprom \
  "build/${name}.elf" \
  "build/${name}.hex"

avr-objdump -d "build/${name}.elf" > "build/${name}.asm"

echo "Generated build/${name}.hex"

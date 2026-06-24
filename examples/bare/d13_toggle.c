#include <avr/io.h>

int main(void) {
  DDRB |= (1 << 5);

  while (1) {
    PORTB ^= (1 << 5);
  }
}

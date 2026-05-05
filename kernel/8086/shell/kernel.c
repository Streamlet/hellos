#include "hal.h"
#include "int.h"

void print_string(const char *s) {
  for (const char *p = s; *p != '\0'; p++) {
    vga_text_putc(*p);
  }
}

void _kernel_main() {
  enable_irq(1);
  char *message = "\r\nHello, Kernel!\r\n";
  print_string(message);
}

void _isr_entry(unsigned short int_num) {
  handle_interrupt(int_num);
}

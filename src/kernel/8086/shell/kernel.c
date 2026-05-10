#include "hal.h"
#include "int.h"

void _kernel_main() {
  setup_irq();

  char *message = "\r\nHello, Kernel!\r\n";
  vga_text_puts(message, VGA_TEXT_ATTR_WHITE | VGA_TEXT_ATTR_BG_BLACK);
}

void _interrupt_entry(unsigned short int_num) {
  handle_interrupt(int_num);
}

#include "bootstrap.h"
#include "keyboard.h"
#include "vga.h"

void panic(const char *s) {
  const unsigned char PANIC_CHAR_ATTR = VGA_TEXT_ATTR_WHITE | VGA_TEXT_ATTR_BG_BLUE;
  // Print the panic message
  int pos = 0;
  for (; s[pos] != '\0'; pos++) {
    vga_text_putc_at(pos, s[pos], PANIC_CHAR_ATTR, 0);
  }
  vga_cursor_set_flat_pos(pos);
  // Clear the rest of the screen
  for (; pos < SCREEN_WIDTH * SCREEN_HEIGHT; pos++) {
    vga_text_putc_at(pos, ' ', PANIC_CHAR_ATTR, 0);
  }
  // Halt the CPU
  _disable(); // Disable interrupts to avoid timer interrupts during halt
  _halt();    // Halt the CPU forever
}

void process_incoming_scancode(unsigned char scancode);
void irq_keyboard() {
  if (!(_inb(0x64) & 1)) {
    return;
  }
  unsigned char scancode = _inb(0x60);
  keyboard_interrupt_handler(scancode);
}

void irq_empty() {
  // empty, invoker isr will send EOI to PIC after this handler returns
}

void handle_irq(unsigned char irq_num) {
  if (irq_num == 0) {
    return;
  }
  typedef void (*irq_handler_t)();
  irq_handler_t irq_handlers[] = {
      /* IRQ00 */ irq_empty,
      /* IRQ01 */ irq_keyboard,
      /* IRQ02 */ irq_empty,
      /* IRQ03 */ 0,
      /* IRQ04 */ 0,
      /* IRQ05 */ 0,
      /* IRQ06 */ 0,
      /* IRQ07 */ 0,
  };
  const char *messages[] = {
      /* IRQ00 */ "Error#20: Unhandled System Timer Interrupt",
      /* IRQ01 */ "Error#21: Unhandled Keyboard Interrupt",
      /* IRQ02 */ "Error#22: Unhandled Cascade (Slave PIC) Interrupt",
      /* IRQ03 */ "Error#23: Unhandled COM2/COM4 Interrupt",
      /* IRQ04 */ "Error#24: Unhandled COM1/COM3 Interrupt",
      /* IRQ05 */ "Error#25: Unhandled LPT2/Sound Interrupt",
      /* IRQ06 */ "Error#26: Unhandled Floppy Disk Interrupt",
      /* IRQ07 */ "Error#27: Unhandled LPT1 Interrupt",
  };
  if (irq_num < sizeof(irq_handlers) / sizeof(irq_handlers[0]) && irq_handlers[irq_num]) {
    irq_handlers[irq_num]();
  } else {
    panic(messages[irq_num]);
  }
}

void handle_cpu_exception(unsigned char int_num) {
  const char *messages[] = {
      "Error#00: Divided By Zero",    "Error#01: Debug Exception",    "Error#02: Non-maskable Interrupt",
      "Error#03: Breakpoint",         "Error#04: Overflow",           "Error#05: Reserved Exception",
      "Error#06: Reserved Exception", "Error#07: Reserved Exception", "Error#08: Reserved Exception",
      "Error#09: Reserved Exception", "Error#0A: Reserved Exception", "Error#0B: Reserved Exception",
      "Error#0C: Reserved Exception", "Error#0D: Reserved Exception", "Error#0E: Reserved Exception",
      "Error#0F: Reserved Exception", "Error#10: Reserved Exception", "Error#11: Reserved Exception",
      "Error#12: Reserved Exception", "Error#13: Reserved Exception", "Error#14: Reserved Exception",
      "Error#15: Reserved Exception", "Error#16: Reserved Exception", "Error#17: Reserved Exception",
      "Error#18: Reserved Exception", "Error#19: Reserved Exception", "Error#1A: Reserved Exception",
      "Error#1B: Reserved Exception", "Error#1C: Reserved Exception", "Error#1D: Reserved Exception",
      "Error#1E: Reserved Exception", "Error#1F: Reserved Exception",
  };
  panic(messages[int_num]);
}

void int_handler(unsigned char int_num) {
  if (int_num >= 0x08 && int_num < 0x10) {
    handle_irq(int_num - 0x08);
  } else if (int_num < 0x20) {
    handle_cpu_exception(int_num);
  } else {
    panic("Unknown interrupt");
  }
}

void setup_pit() {
  // Set PIT channel 0 to mode 3 (square wave generator) with a frequency of 100Hz
  _outb(0x43, 0x36); // Control word: channel 0, access mode lobyte/hibyte, mode 3, binary
  _outb(0x40, 0);    // Divisor low byte (1193180 / 65536 ≈ 18.2Hz)
  _outb(0x40, 0);    // Divisor high byte (0 for 65536)
}

void int_init() {
  _disable();
  _reset_ivt();
  setup_pit();
  _enable();
}

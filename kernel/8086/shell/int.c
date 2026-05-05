#include "int.h"

#include "bootstrap.h"

void panic(const char *s) {
  char __far *const VIDEO_MEMORY = (char __far *)0xB8000000L;
  const int SCREEN_WIDTH = 80;
  const int SCREEN_HEIGHT = 25;
  const unsigned char PANIC_CHAR_ATTR = 0x1F; // White on blue
  int cursor_pos = 0;

  // Print the message to the screen
  for (int i = 0; s[i] != '\0'; i++) {
    if (s[i] == '\r') {
      cursor_pos -= cursor_pos % SCREEN_WIDTH;
    } else if (s[i] == '\n') {
      cursor_pos += SCREEN_WIDTH - cursor_pos % SCREEN_WIDTH;
    } else if (s[i] == '\b') {
      if (cursor_pos > 0) {
        cursor_pos--;
        VIDEO_MEMORY[cursor_pos * 2] = ' ';
        VIDEO_MEMORY[cursor_pos * 2 + 1] = PANIC_CHAR_ATTR;
      }
    } else {
      VIDEO_MEMORY[cursor_pos * 2] = s[i];
      VIDEO_MEMORY[cursor_pos * 2 + 1] = PANIC_CHAR_ATTR;
      cursor_pos++;
      if (cursor_pos >= SCREEN_WIDTH * SCREEN_HEIGHT) {
        // Scroll up
        for (int i = 0; i < (SCREEN_WIDTH * (SCREEN_HEIGHT - 1)) * 2; i++) {
          VIDEO_MEMORY[i] = VIDEO_MEMORY[i + SCREEN_WIDTH * 2];
        }
        cursor_pos -= SCREEN_WIDTH;
      }
    }
  }

  // Clear the rest of the screen
  for (int i = cursor_pos; i < SCREEN_WIDTH * SCREEN_HEIGHT; i++) {
    VIDEO_MEMORY[i * 2] = ' ';
    VIDEO_MEMORY[i * 2 + 1] = PANIC_CHAR_ATTR;
  }

  // Move cursor to the end of the message
  _outb(0x3D4, 0x0F);
  _outb(0x3D5, cursor_pos & 0xFF);
  _outb(0x3D4, 0x0E);
  _outb(0x3D5, (cursor_pos >> 8) & 0xFF);

  // Halt the CPU
  _halt();
}

void handle_cpu_exception(unsigned char int_num) {
  const char *messages[] = {
      "Error#00: Divided By Zero",
      "Error#01: Debug Exception",
      "Error#02: Non-maskable Interrupt",
      "Error#03: Breakpoint",
      "Error#04: Overflow",
      "Error#05: BOUND Range Exceeded",
      "Error#06: Invalid Opcode",
      "Error#07: FPU Not Available",
      "Error#08: Double Fault",
      "Error#09: Coprocessor Segment Overrun",
      "Error#0A: Invalid TSS",
      "Error#0B: Segment Not Present",
      "Error#0C: Stack Segment Fault",
      "Error#0D: General Protection Fault",
      "Error#0E: Page Fault",
      "Error#0F: Reserved Exception",
      "Error#10: FPU Floating-Point Error",
      "Error#11: Alignment Check",
      "Error#12: Machine Check",
      "Error#13: SIMD FP Exception",
      "Error#14: Reserved Exception",
      "Error#15: Reserved Exception",
      "Error#16: Reserved Exception",
      "Error#17: Reserved Exception",
      "Error#18: Reserved Exception",
      "Error#19: Reserved Exception",
      "Error#1A: Reserved Exception",
      "Error#1B: Reserved Exception",
      "Error#1C: Reserved Exception",
      "Error#1D: Reserved Exception",
      "Error#1E: Reserved Exception",
      "Error#1F: Reserved Exception",
  };
  panic(messages[int_num]);
}

void handle_irq(unsigned char irq_num) {
  const char *messages[] = {
      "IRQ#00: Unhandled System Timer Interrupt",        "IRQ#01: Unhandled Keyboard Interrupt",
      "IRQ#02: Unhandled Cascade (Slave PIC) Interrupt", "IRQ#03: Unhandled COM2/COM4 Interrupt",
      "IRQ#04: Unhandled COM1/COM3 Interrupt",           "IRQ#05: Unhandled LPT2/Sound Interrupt",
      "IRQ#06: Unhandled Floppy Disk Interrupt",         "IRQ#07: Unhandled LPT1 Interrupt",
      "IRQ#08: Unhandled Real-Time Clock Interrupt",     "IRQ#09: Unhandled Redirect to IRQ2 Interrupt",
      "IRQ#0A: Unhandled Reserved/Free Interrupt",       "IRQ#0B: Unhandled Reserved/Free Interrupt",
      "IRQ#0C: Unhandled PS/2 Mouse Interrupt",          "IRQ#0D: Unhandled FPU Error Interrupt",
      "IRQ#0E: Unhandled Primary IDE Channel Interrupt", "IRQ#0F: Unhandled Secondary IDE Channel Interrupt",
  };
  panic(messages[irq_num]);
}

void enable_irq(unsigned char irq_num) {
  if (irq_num < 8) {
    _outb(0x21, _inb(0x21) & ~(1 << irq_num));
  } else {
    _outb(0xA1, _inb(0xA1) & ~(1 << (irq_num - 8)));
  }
}

void disable_irq(unsigned char irq_num) {
  if (irq_num < 8) {
    _outb(0x21, _inb(0x21) | (1 << irq_num));
  } else {
    _outb(0xA1, _inb(0xA1) | (1 << (irq_num - 8)));
  }
}

void handle_interrupt(unsigned char int_num) {
  if (int_num < 0x20) {
    handle_cpu_exception(int_num);
  } else if (int_num < 0x30) {
    handle_irq(int_num - 0x20);
  } else {
    panic("Unknown interrupt");
  }
}

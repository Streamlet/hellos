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
      "#00: Divided by zero",
      "#01: Debug exception",
      "#02: Non-maskable interrupt",
      "#03: Breakpoint",
      "#04: Overflow",
      "#05: BOUND range exceeded",
      "#06: Invalid opcode",
      "#07: FPU not available",
      "#08: Double fault",
      "#09: Coprocessor segment overrun",
      "#0A: Invalid TSS",
      "#0B: Segment not present",
      "#0C: Stack segment fault",
      "#0D: General protection fault",
      "#0E: Page fault",
      "#0F: Reserved exception",
      "#10: FPU floating-point error",
      "#11: Alignment check",
      "#12: Machine check",
      "#13: SIMD FP exception",
      "#14: Reserved exception",
      "#15: Reserved exception",
      "#16: Reserved exception",
      "#17: Reserved exception",
      "#18: Reserved exception",
      "#19: Reserved exception",
      "#1A: Reserved exception",
      "#1B: Reserved exception",
      "#1C: Reserved exception",
      "#1D: Reserved exception",
      "#1E: Reserved exception",
      "#1F: Reserved exception",
  };
  panic(messages[int_num]);
}

void handle_irq(unsigned char irq_num) {
  const char *messages[] = {
      "#IRQ 0: System Timer",
      "#IRQ 1: Keyboard",
      "#IRQ 2: Cascade (Slave PIC)",
      "#IRQ 3: COM2/COM4",
      "#IRQ 4: COM1/COM3",
      "#IRQ 5: LPT2/Sound",
      "#IRQ 6: Floppy Disk",
      "#IRQ 7: LPT1",
      "#IRQ 8: Real-Time Clock",
      "#IRQ 9: Redirect to IRQ2",
      "#IRQ 10: Reserved/Free",
      "#IRQ 11: Reserved/Free",
      "#IRQ 12: PS/2 Mouse",
      "#IRQ 13: FPU Error",
      "#IRQ 14: Primary IDE Channel",
      "#IRQ 15: Secondary IDE Channel",
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

void remap_pic() {
  // Remap PIC: IRQ0-7 to INT 0x20-0x27, IRQ8-15 to INT 0x28-0x2f
  // Master PIC
  _outb(0x20, 0x11); // Start initialization in cascade mode
  _outb(0x21, 0x20); // Master PIC vector offset
  _outb(0x21, 0x04); // Tell Master PIC that there is a slave PIC at IRQ2
  _outb(0x21, 0x01); // Set Master PIC to 8086 mode
  _outb(0x21, 0xFF); // Disable all IRQs on Master PIC
  // Slave PIC
  _outb(0xA0, 0x11); // Start initialization in cascade mode
  _outb(0xA1, 0x28); // Slave PIC vector offset
  _outb(0xA1, 0x02); // Tell Slave PIC its cascade identity
  _outb(0xA1, 0x01); // Set Slave PIC to 8086 mode
  _outb(0xA1, 0xFF); // Disable all IRQs on Slave PIC
}

void init_ivt() {
  _clr_int();
  remap_pic();
  _rst_ivt();
  enable_irq(1);
  _set_int();
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

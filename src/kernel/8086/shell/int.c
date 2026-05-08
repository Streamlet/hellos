#include "int.h"
#include "bootstrap.h"
#include "hal.h"

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

void irq_timer() {
  // empty, invoker isr will send EOI to PIC after this handler returns
}

const char SCANCODE_ASCII_MAP[2][128] = {
    // clang-format off
    {
        0,                                                                                  // 0x00: scancode 0 is not used
        '\x1b', '1',  '2', '3', '4', '5', '6', '7', '8', '9', '0', '-',  '=', '\b',         // 0x01-0x0E: ESC
        '\t',   'q',  'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[',  ']', '\n',         // 0x0F-0x1C: Tab
        0,      'a',  's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',               // 0x1D-0x29: Left Ctrl
        0,      '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/',  0,                 // 0x2A-0x36: Left Shift ... Right Shift
        '*',    0,    ' ', 0,                                                               // 0x37-0x3A: ... Left Alt ... Caps Lock
        0,      0,    0,   0,   0,   0,   0,   0,   0,   0,                                 // 0x3B-0x44, F1-F10
        0,      0,                                                                          // 0x45-0x46: Num Lock, Scroll Lock
        '7',    '8',  '9', '-', '4', '5', '6', '+', '1', '2', '3', '0',  '.',               // 0x47-0x53: NumPad
        0,      0,    0,   0,   0,                                                          // 0x54-0x58: Reserved ... F11, F12
        0,      0,    0,   0,   0,   0,   0,                                                // 0x59-0x5F: F13-F19
        0,      0,    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,    0,   0,    0, 0,   // 0x60-0x6F: Reserved
        0,      0,    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,    0,   0,    0, 0,   // 0x70-0x7F: Reserved
    },
    {
        0,                                                                                  // 0x00: scancode 0 is not used
        '\x1b', '!',  '@', '#', '$', '%', '^', '&', '*', '(', ')', '_',  '+', '\b',         // 0x01-0x0E: ESC
        '\t',   'Q',  'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{',  '}', '\n',         // 0x0F-0x1C: Tab
        0,      'A',  'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~',                // 0x1D-0x29: Left Ctrl
        0,      '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?',  0,                  // 0x2A-0x36: Left Shift ... Right Shift
        '*',    0,    ' ', 0,                                                               // 0x37-0x3A: ... Left Alt ... Caps Lock
        0,      0,    0,   0,   0,   0,   0,   0,   0,   0,                                 // 0x3B-0x44, F1-F10
        0,      0,                                                                          // 0x45-0x46: Num Lock, Scroll Lock
        '7',    '8',  '9', '-', '4', '5', '6', '+', '1', '2', '3', '0',  '.',               // 0x47-0x53: NumPad
        0,      0,    0,   0,   0,                                                          // 0x54-0x58: Reserved ... F11, F12
        0,      0,    0,   0,   0,   0,   0,                                                // 0x59-0x5F: F13-F19
        0,      0,    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,    0,   0,    0, 0,   // 0x60-0x6F: Reserved
        0,      0,    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,    0,   0,    0, 0,   // 0x70-0x7F: Reserved
    },
    // clang-format on
};

char scancode_buffer[8] = {0}; // Buffer for scancodes
int scancode_length = 0;       // Number of scancodes in the buffer
int shift_pressed = 0;         // Shift key state
int alt_pressed = 0;           // Alt key state
int ctrl_pressed = 0;          // Ctrl key state
int caps_lock_on = 0;          // Caps Lock state
int num_lock_on = 0;           // Num Lock state
int scroll_lock_on = 0;        // Scroll Lock state
void irq_keyboard() {
  if (!(_inb(0x64) & 1)) {
    return;
  }
  unsigned char scancode = _inb(0x60);
  if (scancode_length != 0) {
    scancode_buffer[scancode_length++] = scancode;
    // Judge if the scancode sequence is complete
    if (scancode_buffer[0] == 0xE0 && scancode_length == 2) {
      scancode_length = 0;
      // Process the two-byte scancode
      unsigned char is_release = scancode_buffer[1] & 0x80;
      unsigned char keycode = scancode_buffer[1] & 0x7F;
      if (keycode == 0x1D) { // Ctrl
        ctrl_pressed = !is_release;
      }
    } else if (scancode_buffer[0] == 0xE1 && scancode_length == 3) {
      scancode_length = 0;
      // Process the three-byte scancode (e.g., Pause/Break)
    } else if (scancode_length >= sizeof(scancode_buffer)) {
      scancode_length = 0;
      // Invalid scancode sequence, reset buffer
    }
  } else {
    if (scancode == 0xE0 || scancode == 0xE1) {
      scancode_buffer[scancode_length++] = scancode;
    } else {
      // Process the single-byte scancode immediately
      unsigned char is_release = scancode & 0x80;
      unsigned char keycode = scancode & 0x7F;
      if (keycode == 0x2A || keycode == 0x36) { // Shift
        shift_pressed = !is_release;
      } else if (keycode == 0x38) { // Alt
        alt_pressed = !is_release;
      } else if (keycode == 0x1D) { // Ctrl
        ctrl_pressed = !is_release;
      } else if (keycode == 0x3A && !is_release) { // Caps Lock
        caps_lock_on = !caps_lock_on;
      } else if (keycode == 0x45 && !is_release) { // Num Lock
        num_lock_on = !num_lock_on;
      } else if (keycode == 0x46 && !is_release) { // Scroll Lock
        scroll_lock_on = !scroll_lock_on;
      }
      char ascii = SCANCODE_ASCII_MAP[(shift_pressed + caps_lock_on) % 2][keycode];
      if (ascii && !is_release) {
        vga_text_putc(ascii, VGA_TEXT_ATTR_WHITE | VGA_TEXT_ATTR_BG_BLACK);
      }
    }
  }
}

void irq_cascade() {
  // empty, invoker isr will send EOI to PIC after this handler returns
}

void handle_irq(unsigned char irq_num) {
  typedef void (*irq_handler_t)();
  irq_handler_t irq_handlers[] = {
      /* IRQ00 */ irq_timer,
      /* IRQ01 */ irq_keyboard,
      /* IRQ02 */ irq_cascade,
      /* IRQ03 */ 0,
      /* IRQ04 */ 0,
      /* IRQ05 */ 0,
      /* IRQ06 */ 0,
      /* IRQ07 */ 0,
      /* IRQ08 */ 0,
      /* IRQ09 */ 0,
      /* IRQ0A */ 0,
      /* IRQ0B */ 0,
      /* IRQ0C */ 0,
      /* IRQ0D */ 0,
      /* IRQ0E */ 0,
      /* IRQ0F */ 0,
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
      /* IRQ08 */ "Error#28: Unhandled Real-Time Clock Interrupt",
      /* IRQ09 */ "Error#29: Unhandled Redirect to IRQ2 Interrupt",
      /* IRQ0A */ "Error#2A: Unhandled Reserved/Free Interrupt",
      /* IRQ0B */ "Error#2B: Unhandled Reserved/Free Interrupt",
      /* IRQ0C */ "Error#2C: Unhandled PS/2 Mouse Interrupt",
      /* IRQ0D */ "Error#2D: Unhandled FPU Error Interrupt",
      /* IRQ0E */ "Error#2E: Unhandled Primary IDE Channel Interrupt",
      /* IRQ0F */ "Error#2F: Unhandled Secondary IDE Channel Interrupt",
  };
  if (irq_num < sizeof(irq_handlers) / sizeof(irq_handlers[0]) && irq_handlers[irq_num]) {
    irq_handlers[irq_num]();
  } else {
    panic(messages[irq_num]);
  }
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

void setup_irq() {
  enable_irq(0); // Enable system timer interrupt
  enable_irq(1); // Enable keyboard interrupt
  enable_irq(2); // Enable cascade (slave PIC) interrupt
}

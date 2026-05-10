#include "hal.h"

#include "bootstrap.h"

unsigned short vga_cursor_get_flat_pos() {
  _outb(0x3D4, 0x0F);
  unsigned char low = _inb(0x3D5);
  _outb(0x3D4, 0x0E);
  unsigned char high = _inb(0x3D5);
  return ((unsigned short)high << 8) | low;
}

void vga_cursor_set_flat_pos(unsigned short pos) {
  _outb(0x3D4, 0x0F);
  _outb(0x3D5, pos & 0xFF);
  _outb(0x3D4, 0x0E);
  _outb(0x3D5, (pos >> 8) & 0xFF);
}

void vga_cursor_get_pos(int *x, int *y) {
  unsigned short pos = vga_cursor_get_flat_pos();
  *x = pos % SCREEN_WIDTH;
  *y = pos / SCREEN_WIDTH;
}

void vga_cursor_set_pos(int x, int y) {
  unsigned short pos = y * SCREEN_WIDTH + x;
  vga_cursor_set_flat_pos(pos);
}

unsigned short vga_text_putc_at(unsigned short pos, char c, unsigned char attr, unsigned char auto_scroll) {
  char __far *const VIDEO_MEMORY = (char __far *)0xB8000000L;
  if (c == '\r') {
    pos -= pos % SCREEN_WIDTH;
  } else if (c == '\n') {
    pos += SCREEN_WIDTH - pos % SCREEN_WIDTH;
  } else if (c == '\b') {
    if (pos > 0) {
      pos--;
      VIDEO_MEMORY[pos * 2] = ' ';
      VIDEO_MEMORY[pos * 2 + 1] = attr;
    }
  } else {
    VIDEO_MEMORY[pos * 2] = c;
    VIDEO_MEMORY[pos * 2 + 1] = attr;
    pos++;
  }
  if (pos >= SCREEN_WIDTH * SCREEN_HEIGHT && auto_scroll) {
    // Scroll up
    for (int i = 0; i < (SCREEN_WIDTH * (SCREEN_HEIGHT - 1)) * 2; i++) {
      VIDEO_MEMORY[i] = VIDEO_MEMORY[i + SCREEN_WIDTH * 2];
    }
    // Clear last line
    for (int i = (SCREEN_WIDTH * (SCREEN_HEIGHT - 1)) * 2; i < SCREEN_WIDTH * SCREEN_HEIGHT * 2; i += 2) {
      VIDEO_MEMORY[i] = ' ';
      VIDEO_MEMORY[i + 1] = attr;
    }
    pos -= SCREEN_WIDTH;
  }
  return pos;
}

void vga_text_putc(char c, unsigned char attr) {
  unsigned short cursor_pos = vga_cursor_get_flat_pos();
  cursor_pos = vga_text_putc_at(cursor_pos, c, attr, 1);
  vga_cursor_set_flat_pos(cursor_pos);
}

void vga_text_puts(const char *s, unsigned char attr) {
  unsigned short cursor_pos = vga_cursor_get_flat_pos();
  while (*s) {
    cursor_pos = vga_text_putc_at(cursor_pos, *s++, attr, 1);
  }
  vga_cursor_set_flat_pos(cursor_pos);
}

void timer_wait(unsigned long milliseconds) {
// Convert milliseconds to PIT ticks
// PIT frequency 1193180 / 65536 = ~18.2 Hz
// 1 tick is about 65536 / 1193180 = 54.925493219799192074959352319013 ms
#define TICK_MS 54                     // interger part of milliseconds per tick
#define TICK_MS_FRAC 925493220UL       // fractional part of milliseconds per tick, scaled by TICK_MS_FRAC_BASE
#define TICK_MS_FRAC_BASE 1000000000UL // fractional part base (1 nanosecond)
  unsigned long time_elapsed = 0, time_elapsed_frac = 0, time_delta = 0;
  while (time_elapsed < milliseconds) {
    _halt();
    time_elapsed_frac += TICK_MS_FRAC;
    time_delta = TICK_MS;
    while (time_elapsed_frac >= TICK_MS_FRAC_BASE) {
      time_elapsed_frac -= TICK_MS_FRAC_BASE;
      ++time_delta;
    }
    if (time_elapsed + time_delta < time_elapsed) {
      // Overflow
      break;
    }
    time_elapsed += time_delta;
  }
}

//
// 0x417 Keyboard Control Byte
//   Bit 7 Insert Locked
//   Bit 6 Caps Lock Locked
//   Bit 5 Num Lock Locked
//   Bit 4 Scroll Lock Locked
//   Bit 3 Alt Key Pressed
//   Bit 2 Ctrl Key Pressed
//   Bit 1 Left Shift Key Pressed
//   Bit 0 Right Shift Key Pressed
// 0x418 Keyboard Control Byte
//   Bit 7 Insert Key Pressed
//   Bit 6 Caps Lock Key Pressed
//   Bit 5 Num Lock Key Pressed
//   Bit 4 Scroll Lock Key Pressed
//   Bit 3 Pause Locked
//   Bit 2 System Request Key Pressed
//   Bit 1 Left Alt Key Pressed
//   Bit 0 Left Ctrl Key Pressed
//
enum {
  KEY_STATE_RSHIFT_PRESSED = (1 << 0),
  KEY_STATE_LSHIFT_PRESSED = (1 << 1),
  KEY_STATE_CTRL_PRESSED = (1 << 2),
  KEY_STATE_ALT_PRESSED = (1 << 3),
  KEY_STATE_SCROLL_LOCK_ON = (1 << 4),
  KEY_STATE_NUM_LOCK_ON = (1 << 5),
  KEY_STATE_CAPS_LOCK_ON = (1 << 6),
  KEY_STATE_INSERT_LOCKED = (1 << 7),
  KEY_STATE_LCTRL_PRESSED = (1 << 8),
  KEY_STATE_LALT_PRESSED = (1 << 9),
  KEY_STATE_SYSRQ_PRESSED = (1 << 10),
  KEY_STATE_PAUSE_LOCKED = (1 << 11),
  KEY_STATE_SCROLL_LOCK_PRESSED = (1 << 12),
  KEY_STATE_NUM_LOCK_PRESSED = (1 << 13),
  KEY_STATE_CAPS_LOCK_PRESSED = (1 << 14),
  KEY_STATE_INSERT_PRESSED = (1 << 15),
};
unsigned short key_state_ = 0;
enum {
  KEY_STATE_EX_RCTRL_PRESSED = (1 << 0),
  KEY_STATE_EX_RALT_PRESSED = (1 << 1),
};
unsigned char key_state_ex_ = 0;

#define CHAR_BUFFER_LENGTH 16
unsigned short
    char_buffer_[CHAR_BUFFER_LENGTH]; // Buffer for printable characters, byte 0 is character, byte 1 is scancode
unsigned char char_buffer_head_ = 0;  // Index of the head of the character buffer
unsigned char char_buffer_tail_ = 0;  // Index of the tail of the character buffer

unsigned short keyboard_read() {
  _disable();
  char_buffer_head_ = char_buffer_tail_; // Clear the buffer
  _enable();
  while (char_buffer_head_ == char_buffer_tail_) {
    _halt(); // Wait for the next character to be put into the buffer
  }
  _disable();
  unsigned short key = char_buffer_[char_buffer_tail_];
  char_buffer_tail_ = (char_buffer_tail_ + 1) % CHAR_BUFFER_LENGTH;
  _enable();
  return key;
}

// Scancode Definition:
//   https://osdev.wiki/wiki/PS/2_Keyboard

const char SCANCODE_ASCII_MAP[3][128] = {
    // clang-format off
    {
        0,                                                                                  // 0x00: scancode 0 is not used
        '\x1b', '1',  '2', '3', '4', '5', '6', '7', '8', '9', '0', '-',  '=', '\b',         // 0x01-0x0E: ESC
        '\t',   'q',  'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[',  ']', '\r',         // 0x0F-0x1C: Tab
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
        '\t',   'Q',  'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{',  '}', '\r',         // 0x0F-0x1C: Tab
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

enum {
  KEY_CTRL = 0x1D, // Right Ctrl: 0xE0, 0x1D
  KEY_ALT = 0x38,  // Right Alt: 0xE0, 0x38
  KEY_LSHIFT = 0x2A,
  KEY_RSHIFT = 0x36,
  KEY_CAPS_LOCK = 0x3A,
  KEY_NUM_LOCK = 0x45,
  KEY_SCROLL_LOCK = 0x46,

  KEY_NUMPAD_CHAR_START = 0x47,
  KEY_NUMPAD_CHAR_END = 0x53,
};

void process_character(unsigned char scancode) {
  char c = SCANCODE_ASCII_MAP[(key_state_ & (KEY_STATE_LSHIFT_PRESSED | KEY_STATE_RSHIFT_PRESSED)) ? 1 : 0][scancode];
  if ((c >= KEY_NUMPAD_CHAR_START && c <= KEY_NUMPAD_CHAR_END && (key_state_ & KEY_STATE_NUM_LOCK_ON) == 0)) {
    c = 0;
  }
  char_buffer_[char_buffer_head_] = c | (((unsigned short)scancode) << 8);
  char_buffer_head_ = (char_buffer_head_ + 1) % CHAR_BUFFER_LENGTH;
  // If buffer is full, move tail to overwrite the oldest character
  if (char_buffer_head_ == char_buffer_tail_) {
    char_buffer_tail_ = (char_buffer_tail_ + 1) % CHAR_BUFFER_LENGTH;
  }
}

void process_single_scancode(unsigned char scancode) {
  if ((scancode & 0x80) == 0) { // Key press
    switch (scancode & 0x7F) {
    case KEY_CTRL:
      key_state_ |= KEY_STATE_CTRL_PRESSED;
      if ((key_state_ & KEY_STATE_LCTRL_PRESSED) != 0 || (key_state_ex_ & KEY_STATE_EX_RCTRL_PRESSED) != 0) {
        key_state_ |= KEY_STATE_CTRL_PRESSED;
      }
      break;
    case KEY_ALT:
      key_state_ |= KEY_STATE_ALT_PRESSED;
      if ((key_state_ & KEY_STATE_LALT_PRESSED) != 0 || (key_state_ex_ & KEY_STATE_EX_RALT_PRESSED) != 0) {
        key_state_ |= KEY_STATE_ALT_PRESSED;
      }
      break;
    case KEY_LSHIFT:
      key_state_ |= KEY_STATE_LSHIFT_PRESSED;
      break;
    case KEY_RSHIFT:
      key_state_ |= KEY_STATE_RSHIFT_PRESSED;
      break;
    case KEY_CAPS_LOCK:
      key_state_ |= KEY_STATE_CAPS_LOCK_PRESSED;
      key_state_ ^= KEY_STATE_CAPS_LOCK_ON; // Toggle Caps Lock state
      break;
    case KEY_NUM_LOCK:
      key_state_ |= KEY_STATE_NUM_LOCK_PRESSED;
      key_state_ ^= KEY_STATE_NUM_LOCK_ON; // Toggle Num Lock state
      break;
    case KEY_SCROLL_LOCK:
      key_state_ |= KEY_STATE_SCROLL_LOCK_PRESSED;
      key_state_ ^= KEY_STATE_SCROLL_LOCK_ON; // Toggle Scroll Lock state
      break;
    default:
      process_character(scancode);
      break;
    }
  } else { // Key release
    switch (scancode & 0x7F) {
    case KEY_CTRL:
      key_state_ &= ~KEY_STATE_CTRL_PRESSED;
      if ((key_state_ & KEY_STATE_LCTRL_PRESSED) == 0 && (key_state_ex_ & KEY_STATE_EX_RCTRL_PRESSED) == 0) {
        key_state_ &= ~KEY_STATE_CTRL_PRESSED;
      }
      break;
    case KEY_ALT:
      key_state_ &= ~KEY_STATE_ALT_PRESSED;
      if ((key_state_ & KEY_STATE_LALT_PRESSED) == 0 && (key_state_ex_ & KEY_STATE_EX_RALT_PRESSED) == 0) {
        key_state_ &= ~KEY_STATE_ALT_PRESSED;
      }
      break;
    case KEY_LSHIFT:
      key_state_ &= ~KEY_STATE_LSHIFT_PRESSED;
      break;
    case KEY_RSHIFT:
      key_state_ &= ~KEY_STATE_RSHIFT_PRESSED;
      break;
    case KEY_CAPS_LOCK:
      key_state_ &= ~(KEY_STATE_CAPS_LOCK_PRESSED);
      break;
    case KEY_NUM_LOCK:
      key_state_ &= ~(KEY_STATE_NUM_LOCK_PRESSED);
      break;
    case KEY_SCROLL_LOCK:
      key_state_ &= ~(KEY_STATE_SCROLL_LOCK_PRESSED);
      break;
    default:
      break;
    }
  }
}

void process_e0_scancode(unsigned char scancode) {
  if ((scancode & 0x80) == 0) { // Key press
    switch (scancode & 0x7F) {
    case KEY_CTRL:
      key_state_ex_ |= KEY_STATE_EX_RCTRL_PRESSED;
      if ((key_state_ & KEY_STATE_LCTRL_PRESSED) != 0 || (key_state_ex_ & KEY_STATE_EX_RCTRL_PRESSED) != 0) {
        key_state_ |= KEY_STATE_CTRL_PRESSED;
      }
      break;
    case KEY_ALT:
      key_state_ex_ |= KEY_STATE_EX_RALT_PRESSED;
      if ((key_state_ & KEY_STATE_LALT_PRESSED) != 0 || (key_state_ex_ & KEY_STATE_EX_RALT_PRESSED) != 0) {
        key_state_ |= KEY_STATE_ALT_PRESSED;
      }
      break;
    default:
      process_character(scancode);
      break;
    }
  } else { // Key release
    switch (scancode & 0x7F) {
    case KEY_CTRL:
      key_state_ex_ &= ~KEY_STATE_EX_RCTRL_PRESSED;
      if ((key_state_ & KEY_STATE_LCTRL_PRESSED) == 0 && (key_state_ex_ & KEY_STATE_EX_RCTRL_PRESSED) == 0) {
        key_state_ &= ~KEY_STATE_CTRL_PRESSED;
      }
      break;
    case KEY_ALT:
      key_state_ex_ &= ~KEY_STATE_EX_RALT_PRESSED;
      if ((key_state_ & KEY_STATE_LALT_PRESSED) == 0 && (key_state_ex_ & KEY_STATE_EX_RALT_PRESSED) == 0) {
        key_state_ &= ~KEY_STATE_ALT_PRESSED;
      }
      break;
    default:
      break;
    }
  }
}

#define SCANCODE_BUFFER_LENGTH 6
char scancode_buffer_[SCANCODE_BUFFER_LENGTH] = {0}; // Buffer for scancodes
unsigned char scancode_length_ = 0;                  // Number of scancodes in the buffer
// Special scancode sequences:
// 0xE0, 0x2A, 0xE0, 0x37	print screen pressed
// 0xE0, 0xB7, 0xE0, 0xAA	print screen released
// 0xE1, 0x1D, 0x45, 0xE1, 0x9D, 0xC5	pause pressed
// Note: There is no scan code for "pause key released" (it behaves as if it is released as soon as it's pressed)
char pause_scancode_sequence_[6] = {0xE1, 0x1D, 0x45, 0xE1, 0x9D, 0xC5};

void process_incoming_scancode(unsigned char scancode) {
  if (scancode_buffer_[0] != 0) {
    scancode_buffer_[scancode_length_++] = scancode;
    // Judge if the scancode sequence is complete
    if (scancode_buffer_[0] == 0xE0) {
      if (scancode_length_ > 2) {
        // Invalid scancode sequence, reset buffer
        scancode_length_ = 0;
        return;
      }
      scancode_length_ = 0;
      process_e0_scancode(scancode);
    } else if (scancode_buffer_[0] == 0xE1) {
      scancode_length_ = 0;
      // Process the three-byte scancode (e.g., Pause/Break)
    } else if (scancode_length_ >= sizeof(scancode_buffer_)) {
      for (unsigned char i = 0; i < scancode_length_; i++) {
        if (scancode_buffer_[i] != pause_scancode_sequence_[i]) {
          // Invalid scancode sequence, reset buffer
          scancode_length_ = 0;
          return;
        }
      }
      if (scancode_length_ == sizeof(pause_scancode_sequence_)) {
        scancode_length_ = 0;
        // Process the complete Pause/Break scancode sequence
      } else {
        // Wait for more scancodes
      }
    }
  } else {
    if (scancode == 0xE0 || scancode == 0xE1) {
      scancode_buffer_[scancode_length_++] = scancode;
    } else {
      // Process the single-byte scancode immediately
      process_single_scancode(scancode);
    }
  }
}

void init_key_state() {
  key_state_ = *(unsigned short __far *)0x00000417L;
  if ((key_state_ & KEY_STATE_CTRL_PRESSED) != 0 && (key_state_ & KEY_STATE_LCTRL_PRESSED) == 0) {
    key_state_ex_ |= KEY_STATE_EX_RCTRL_PRESSED;
  }
  if ((key_state_ & KEY_STATE_ALT_PRESSED) != 0 && (key_state_ & KEY_STATE_LALT_PRESSED) == 0) {
    key_state_ex_ |= KEY_STATE_EX_RALT_PRESSED;
  }
}

void hal_init() {
  init_key_state();
}

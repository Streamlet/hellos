#include "hal.h"

#include "bootstrap.h"

unsigned short vga_cursor_get_linear() {
  _outb(0x3D4, 0x0F);
  unsigned char low = _inb(0x3D5);
  _outb(0x3D4, 0x0E);
  unsigned char high = _inb(0x3D5);
  return ((unsigned short)high << 8) | low;
}

void vga_cursor_set_linear(unsigned short pos) {
  _outb(0x3D4, 0x0F);
  _outb(0x3D5, pos & 0xFF);
  _outb(0x3D4, 0x0E);
  _outb(0x3D5, (pos >> 8) & 0xFF);
}

void vga_cursor_get(int *x, int *y) {
  unsigned short pos = vga_cursor_get_linear();
  *x = pos % SCREEN_WIDTH;
  *y = pos / SCREEN_WIDTH;
}

void vga_cursor_set(int x, int y) {
  unsigned short pos = y * SCREEN_WIDTH + x;
  vga_cursor_set_linear(pos);
}

void vga_text_putc(char c) {
  char __far *const VIDEO_MEMORY = (char __far *)0xB8000000L;
  const unsigned char DEFAULT_CHAR_ATTR = 0x07; // Light grey on black
  unsigned cursor_pos = vga_cursor_get_linear();
  if (c == '\r') {
    cursor_pos -= cursor_pos % SCREEN_WIDTH;
  } else if (c == '\n') {
    cursor_pos += SCREEN_WIDTH - cursor_pos % SCREEN_WIDTH;
  } else if (c == '\b') {
    if (cursor_pos > 0) {
      cursor_pos--;
      VIDEO_MEMORY[cursor_pos * 2] = ' ';
      VIDEO_MEMORY[cursor_pos * 2 + 1] = DEFAULT_CHAR_ATTR;
    }
  } else {
    VIDEO_MEMORY[cursor_pos * 2] = c;
    VIDEO_MEMORY[cursor_pos * 2 + 1] = DEFAULT_CHAR_ATTR;
    cursor_pos++;
    if (cursor_pos >= SCREEN_WIDTH * SCREEN_HEIGHT) {
      // Scroll up
      for (int i = 0; i < (SCREEN_WIDTH * (SCREEN_HEIGHT - 1)) * 2; i++) {
        VIDEO_MEMORY[i] = VIDEO_MEMORY[i + SCREEN_WIDTH * 2];
      }
      // Clear last line
      for (int i = (SCREEN_WIDTH * (SCREEN_HEIGHT - 1)) * 2; i < SCREEN_WIDTH * SCREEN_HEIGHT * 2; i += 2) {
        VIDEO_MEMORY[i] = ' ';
        VIDEO_MEMORY[i + 1] = DEFAULT_CHAR_ATTR;
      }
      cursor_pos -= SCREEN_WIDTH;
    }
  }
  vga_cursor_set_linear(cursor_pos);
}

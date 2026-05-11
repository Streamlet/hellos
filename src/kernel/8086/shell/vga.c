#include "vga.h"

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

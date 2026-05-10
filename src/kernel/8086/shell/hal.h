#ifndef __HAL_H_INCLUDED__
#define __HAL_H_INCLUDED__

#define SCREEN_WIDTH 80
#define SCREEN_HEIGHT 25

void hal_init();

void power_off();
void reset();

unsigned short vga_cursor_get_flat_pos();
void vga_cursor_set_flat_pos(unsigned short pos);
void vga_cursor_get_pos(int *x, int *y);
void vga_cursor_set_pos(int x, int y);

enum {
  VGA_TEXT_ATTR_BLACK = 0x00,
  VGA_TEXT_ATTR_BLUE = 0x01,
  VGA_TEXT_ATTR_GREEN = 0x02,
  VGA_TEXT_ATTR_CYAN = 0x03,
  VGA_TEXT_ATTR_RED = 0x04,
  VGA_TEXT_ATTR_MAGENTA = 0x05,
  VGA_TEXT_ATTR_YELLOW = 0x06,
  VGA_TEXT_ATTR_WHITE = 0x07,

  VGA_TEXT_ATTR_HILIGHT = 0x08,

  VGA_TEXT_ATTR_BG_BLACK = 0x00,
  VGA_TEXT_ATTR_BG_BLUE = 0x10,
  VGA_TEXT_ATTR_BG_GREEN = 0x20,
  VGA_TEXT_ATTR_BG_CYAN = 0x30,
  VGA_TEXT_ATTR_BG_RED = 0x40,
  VGA_TEXT_ATTR_BG_MAGENTA = 0x50,
  VGA_TEXT_ATTR_BG_YELLOW = 0x60,
  VGA_TEXT_ATTR_BG_WHITE = 0x70,

  VGA_TEXT_ATTR_BLINK = 0x80,
};

unsigned short vga_text_putc_at(unsigned short pos, char c, unsigned char attr, unsigned char auto_scroll);
void vga_text_putc(char c, unsigned char attr);
void vga_text_puts(const char *s, unsigned char attr);

void timer_wait(unsigned long milliseconds);

unsigned short keyboard_read();

#endif // __HAL_H_INCLUDED__

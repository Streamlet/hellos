#ifndef __HAL_H_INCLUDED__
#define __HAL_H_INCLUDED__

#define SCREEN_WIDTH 80
#define SCREEN_HEIGHT 25

extern void vga_cursor_get(int* x, int* y);
extern void vga_cursor_set(int x, int y);

extern void vga_text_putc(char c);

#endif  // __HAL_H_INCLUDED__

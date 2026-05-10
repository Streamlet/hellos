#include "hal.h"
#include "int.h"

char *gets(char *buffer, unsigned int buffer_length) {
  for (int i = 0; i < buffer_length - 1;) {
    unsigned short key = keyboard_read();
    char c = key & 0xFF;
    if (c == '\r') {
      buffer[i++] = '\0';
      vga_text_putc('\n', VGA_TEXT_ATTR_WHITE | VGA_TEXT_ATTR_BG_BLACK);
      break;
    } else if (c == '\b') {
      if (i > 0) {
        --i; // Move back the index to overwrite the previous character
        vga_text_putc(c, VGA_TEXT_ATTR_WHITE | VGA_TEXT_ATTR_BG_BLACK); // Erase the character on screen
      }
    } else if (c > 0) {
      buffer[i++] = c;
      vga_text_putc(c, VGA_TEXT_ATTR_WHITE | VGA_TEXT_ATTR_BG_BLACK);
    }
  }
  buffer[buffer_length - 1] = '\0'; // Ensure null-termination
  return buffer;
}

int strcmp(const char *s1, const char *s2) {
  while (*s1 && (*s1 == *s2)) {
    s1++;
    s2++;
  }
  return *(unsigned char *)s1 - *(unsigned char *)s2;
}

void _kernel_main() {
  hal_init();
  int_init();

  char input_buffer[128] = {0};
  while (1) {
    vga_text_puts(">", VGA_TEXT_ATTR_WHITE | VGA_TEXT_ATTR_BG_BLACK);
    char *line = gets(input_buffer, sizeof(input_buffer));
    if (strcmp(line, "shutdown") == 0) {
      vga_text_puts("Shuting down...\n", VGA_TEXT_ATTR_GREEN | VGA_TEXT_ATTR_BG_BLACK);
      timer_wait(3000);
      // TODO
    } else if (strcmp(line, "reboot") == 0) {
      vga_text_puts("Rebooting\n", VGA_TEXT_ATTR_GREEN | VGA_TEXT_ATTR_BG_BLACK);
      timer_wait(3000);
      // TODO
    } else if (line[0] != '\0') {
      vga_text_puts("Bad command.\nAvailable commands: shutdown, reboot\n", VGA_TEXT_ATTR_RED | VGA_TEXT_ATTR_BG_BLACK);
    }
  }
}

void _interrupt_entry(unsigned char int_num) {
  int_handler(int_num);
}

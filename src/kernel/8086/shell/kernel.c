#include "ide.h"
#include "int.h"
#include "keyboard.h"
#include "power.h"
#include "timer.h"
#include "vga.h"

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

void puts(const char *s) {
  vga_text_puts(s, VGA_TEXT_ATTR_WHITE | VGA_TEXT_ATTR_BG_BLACK);
}
void success(const char *s) {
  vga_text_puts(s, VGA_TEXT_ATTR_GREEN | VGA_TEXT_ATTR_BG_BLACK);
}
void error(const char *s) {
  vga_text_puts(s, VGA_TEXT_ATTR_RED | VGA_TEXT_ATTR_BG_BLACK);
}

int strcmp(const char *s1, const char *s2) {
  while (*s1 && (*s1 == *s2)) {
    s1++;
    s2++;
  }
  return *(unsigned char *)s1 - *(unsigned char *)s2;
}

void shell_loop() {
  char input_buffer[128] = {0};
  while (1) {
    puts(">");
    char *line = gets(input_buffer, sizeof(input_buffer));
    if (strcmp(line, "shutdown") == 0) {
      success("Shutting down...\n");
      timer_wait(1000);
      power_off();
    } else if (strcmp(line, "reboot") == 0) {
      success("Rebooting...\n");
      timer_wait(1000);
      reset();
    } else if (line[0] != '\0') {
      error("Bad command.\nAvailable commands: shutdown, reboot\n");
    }
  }
}

void _kernel_main() {
  puts("Initializing keyboard...");
  keyboard_init();
  success("Done\n");

  puts("Initializing IDE...");
  ide_init();
  success("Done\n");
  for (unsigned char device = IDE_PRIMARY_MASTER; device <= IDE_SECONDARY_SLAVE; device++) {
    const ide_device_info *info = ide_get_device_info(device);
    if (info != 0) {
      puts("Found IDE device: ");
      puts(info->model);
      puts("\n");
    }
  }

  puts("Initializing interrupts...");
  int_init();
  success("Done\n");

  puts("\nEntering shell...\n");
  shell_loop();
}

void _interrupt_entry(unsigned char int_num) {
  int_handler(int_num);
}

#include "bootstrap.h"

void print_string(const char *s) {
  for (const char *p = s; *p != '\0'; p++) {
    print_char(*p);
  }
}

void kernel_main() {
  char *message = "\r\nHello, Kernel!\r\n";
  print_string(message);
}

#include "bootstrap.h"

int print_string(const char* s) {
  for (const char* p = s; *p != '\0'; p++) {
    print_char(*p);
  }
  return 0;
}

int kernel_main() {
  char* message = "\r\nHello, Kernel!\r\n";
  print_string(message);
  return 0;
}

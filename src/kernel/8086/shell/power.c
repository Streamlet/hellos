#include "power.h"

#include "bootstrap.h"

void power_off() {
  _disable();
  _outw(0x604, 0x2000); // Qemu only, for real hardware, we may need to send ACPI command to power off
}

void reset() {
  _disable();
  _outb(0x64, 0xFE);
}

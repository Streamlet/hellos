#include "timer.h"

#include "bootstrap.h"

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

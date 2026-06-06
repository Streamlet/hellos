#include "mm.h"
#include "heap.h"

#define KERNEL_HEAP_START 0x0000
#define KERNEL_HEAP_SIZE 0x8000

unsigned long kernel_heap_ = 0;

void mm_init() {
  kernel_heap_ = heap_init((void *)KERNEL_HEAP_START, KERNEL_HEAP_SIZE);
}

void *mm_allocate(unsigned long size) {
  return heap_allocate(kernel_heap_, size);
}

void mm_free(void *address) {
  heap_free(kernel_heap_, address);
}

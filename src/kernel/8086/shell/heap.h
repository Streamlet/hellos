#ifndef __HEAP_H_INCLUDED__
#define __HEAP_H_INCLUDED__

#ifndef _M_I86
#define __far
#endif

unsigned long heap_far_init(void __far *heap_start, unsigned long heap_size);
void __far *heap_far_allocate(unsigned long heap, unsigned long size);
void heap_far_free(unsigned long heap, void __far *address);

unsigned long heap_init(void *heap_start, unsigned long heap_size);
void *heap_allocate(unsigned long heap, unsigned long size);
void heap_free(unsigned long heap, void *address);

#endif // __HEAP_H_INCLUDED__

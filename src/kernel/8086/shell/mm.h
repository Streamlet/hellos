#ifndef __MM_H_INCLUDED__
#define __MM_H_INCLUDED__

void mm_init();
void *mm_allocate(unsigned long size);
void mm_free(void *address);

#endif // __MM_H_INCLUDED__

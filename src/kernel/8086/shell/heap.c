#include "heap.h"
#include "bootstrap.h"

#define PAGE_ALIGN_BITS 10
#define PAGE_SIZE (1 << PAGE_ALIGN_BITS)
#define PAGE_ALIGN_MASK (PAGE_SIZE - 1)
#define MAX_PAGES 512L
#define MAX_HEAP_SIZE (MAX_PAGES * PAGE_SIZE) // 512KB total memory for allocation
#define MEMORY_POOLS 6                        // 16, 32, 64, 128, 256, 512
#define MIN_BLOCK_SIZE 16

typedef union {
  // for small block
  struct {
    unsigned char sb_ref_count;          // bit 0-6: reference count; bit 7: flag for large block (0 for small block)
    unsigned char sb_free_blocks_header; // head of free block list; the first bytes of blocks are used as next pointers
    unsigned short sb_next_page;         // bit 0-11: index of the next page in the free page list, use page index
                                         // bit 12-15: index of the memory pool for small blocks
  };
  // for large block
  struct {
    unsigned char lb_flags; //  bit 0: first page; bit 1: last page; bit 7: flag for large block (1 for large block)
    unsigned char lb_page_count;  //  number of pages for this block
    unsigned short lb_first_page; //  bit 0-11: first page index; bit 12-15: high 4 bits of page count for large blocks
  };
} page_control_block;

typedef struct {
  char magic[4];                                  // "HCB\0"
  unsigned long size;                             // size of the heap, including the control block
  unsigned short page_count;                      // number of pages in this heap
  unsigned short reserved_pages;                  // number of reserved pages in this heap
  unsigned char bitmap[MAX_PAGES / 8];            // bitmap to track allocated/free pages, 1 bit per page
  unsigned short free_pages_header[MEMORY_POOLS]; // head of free page list for each pool, bit 0-11: page index
  page_control_block pcb_list[];                  // control block for each page
} heap_control_block;

#define MK_FP(seg, off) ((void __far *)(((unsigned long)(seg) << 16) | (unsigned long)(unsigned short)(off)))
#define FP_SEG(fp) ((unsigned short)(((unsigned long)(fp)) >> 16))
#define FP_OFF(fp) ((unsigned short)(((unsigned long)(fp)) & 0xFFFF))

unsigned long heap_near_to_linear(void *p) {
  unsigned short seg = _get_ds();
  unsigned short off = FP_OFF(p);
  return ((unsigned long)seg << 4) + off;
}

unsigned long heap_far_to_linear(void __far *p) {
  unsigned short seg = FP_SEG(p);
  unsigned short off = FP_OFF(p);
  return ((unsigned long)seg << 4) + off;
}

void *heap_linear_to_near(unsigned long linear) {
  if (linear - ((unsigned long)_get_ds() << 4) > 0xFFFF) {
    return 0; // cannot be represented in near pointer
  }
  return (void *)(linear - ((unsigned long)_get_ds() << 4));
}

void __far *heap_linear_to_far(unsigned long linear) {
  unsigned short seg = linear >> 4;
  unsigned short off = linear & 0x0F;
  return MK_FP(seg, off);
}

void __far *heap_near_to_far(void *p) {
  return MK_FP(_get_ds(), p);
}

void *heap_far_to_near(void __far *p) {
  return heap_linear_to_near(heap_far_to_linear(p));
}

#define PAGE_FLAG_LARGE 0x80            // page is part of a large block
#define PAGE_FLAG_LARGE_FIRST_PAGE 0x01 // page is the first page of a large block
#define PAGE_FLAG_LARGE_LAST_PAGE 0x02  // page is the last page of a large block
#define PAGE_MASK_LOW_12_BITS 0x0FFF // mask for next page index for small blocks or first page index for large blocks
#define PAGE_MASK_HIGH_4_BITS 0xF000 // mask for pool index for small blocks or high bits of page count for large blocks

unsigned long heap_far_init(void __far *heap_start, unsigned long heap_size) {
  heap_size = (heap_size + PAGE_SIZE - 1) & ~PAGE_ALIGN_MASK; // align to page size
  unsigned short page_count = heap_size >> PAGE_ALIGN_BITS;
  unsigned short hcb_pages =
      (sizeof(heap_control_block) + sizeof(page_control_block) * page_count + PAGE_SIZE - 1) >> PAGE_ALIGN_BITS;
  if (page_count <= hcb_pages) { // not enough space for allocation
    return 0;
  }

  // align heap control block to page boundary
  unsigned short heap_seg = FP_SEG(heap_start);
  unsigned short heap_off = FP_OFF(heap_start);
  unsigned long heap_linear = ((unsigned long)heap_seg << 4) + heap_off;
  heap_linear = (heap_linear + PAGE_SIZE - 1) & ~PAGE_ALIGN_MASK;
  while (heap_linear - ((unsigned long)heap_seg << 4) > 0xFFFF) {
    heap_seg++;
  }
  heap_off = heap_linear - ((unsigned long)heap_seg << 4);
  heap_control_block __far *hcb = (heap_control_block __far *)heap_linear_to_far(heap_linear);

  // initialize magic
  hcb->magic[0] = 'H';
  hcb->magic[1] = 'C';
  hcb->magic[2] = 'B';
  hcb->magic[3] = '\0';

  // initialize size and counts
  hcb->size = heap_size;
  hcb->page_count = page_count;
  hcb->reserved_pages = hcb_pages;

  // initialize bitmap, mark all pages as free except those used by heap control block itself
  for (int i = 0; i < sizeof(hcb->bitmap); i++) {
    hcb->bitmap[i] = 0;
  }
  for (int i = 0; i < hcb_pages; i++) {
    hcb->bitmap[i / 8] |= (1 << (i % 8));
  }

  // initialize free page list, all pools are empty
  for (int i = 0; i < MEMORY_POOLS; i++) {
    // page 0 will always be used to store heap control block, so 0 can be used to indicate end of free page list
    hcb->free_pages_header[i] = 0;
  }

  return heap_linear;
}

void __far *heap_far_allocate_small(heap_control_block __far *hcb, unsigned short aligned_size) {
  // calculate linear address of the heap control block for later use
  unsigned short heap_seg = FP_SEG(hcb);
  unsigned short heap_off = FP_OFF(hcb);
  unsigned long heap_linear = ((unsigned long)heap_seg << 4) + heap_off;

  // calculate pool index based on aligned size, pool 0 for 16 bytes, pool 1 for 32 bytes, ..., pool 5 for 512 bytes
  unsigned short pool_index = 0;
  unsigned short block_size = MIN_BLOCK_SIZE;
  while (block_size < aligned_size) {
    block_size <<= 1;
    pool_index++;
  }

  // no free page in the pool, need to allocate a new page and add it to free page list of the pool
  if ((hcb->free_pages_header[pool_index] & PAGE_MASK_LOW_12_BITS) == 0) {
    // find a free page from bitmap
    unsigned short page_index = 0;
    for (unsigned short i = 0; i < hcb->page_count; i++) {
      if ((hcb->bitmap[i / 8] & (1 << (i % 8))) == 0) {
        page_index = i;
        hcb->bitmap[page_index / 8] |= (1 << (page_index % 8));
        break; // found a free page
      }
    }
    if (page_index == 0) {
      return 0;
    }
    hcb->free_pages_header[pool_index] = page_index;

    // initialize page control block for this page and add it to free page list of the pool
    page_control_block __far *pcb = &hcb->pcb_list[page_index];
    pcb->sb_ref_count = 0;
    pcb->sb_next_page = (pool_index << 12) | 0; // 0 indicates the last page in the free page list
    pcb->sb_free_blocks_header = 0;             // the first block is block[0]
    // all blocks are free at the beginning, block[j] points to block[j+1]
    unsigned long page_linear = heap_linear + PAGE_SIZE * page_index;
    unsigned short page_seg = heap_seg;
    while (page_linear - ((unsigned long)page_seg << 4) > 0xFFFF) {
      page_seg++;
    }
    unsigned short page_off = page_linear - ((unsigned long)page_seg << 4);
    unsigned char __far *page = (unsigned char __far *)MK_FP(page_seg, page_off);
    for (int j = 0; j < PAGE_SIZE / aligned_size - 1; j++) {
      *(page + aligned_size * j) = j + 1;
    }
    *(page + aligned_size * (PAGE_SIZE / aligned_size - 1)) = 0xff; // 0xff indicates the end of free block list
  }

  // now there must be a free page in the pool, allocate from the free page list of the pool
  unsigned short page_index = hcb->free_pages_header[pool_index] & PAGE_MASK_LOW_12_BITS;
  page_control_block __far *pcb = &hcb->pcb_list[page_index];
  unsigned long block_linear = heap_linear + PAGE_SIZE * page_index + aligned_size * pcb->sb_free_blocks_header;
  unsigned short block_seg = heap_seg;
  while (block_linear - ((unsigned long)block_seg << 4) > 0xFFFF) {
    block_seg++;
  }
  unsigned short block_off = block_linear - ((unsigned long)block_seg << 4);

  unsigned char __far *block = (unsigned char __far *)MK_FP(block_seg, block_off);
  pcb->sb_free_blocks_header = *(unsigned char __far *)block; // update free block list head
  pcb->sb_ref_count++;                                        // increase ref count for this page
  if (pcb->sb_free_blocks_header == 0xff) {
    // this page is now fully allocated, remove it from free page list
    hcb->free_pages_header[pool_index] = pcb->sb_next_page & PAGE_MASK_LOW_12_BITS;
  }
  return block;
}

void __far *heap_far_allocate_large(heap_control_block __far *hcb, unsigned short required_pages) {
  // calculate linear address of the heap control block for later use
  unsigned short heap_seg = FP_SEG(hcb);
  unsigned short heap_off = FP_OFF(hcb);
  unsigned long heap_linear = ((unsigned long)heap_seg << 4) + heap_off;

  // find continuous free pages from bitmap
  unsigned short page_index = 0, free_page_count = 0;
  for (unsigned short i = 0; i < hcb->page_count; i++) {
    if ((hcb->bitmap[i / 8] & (1 << (i % 8))) == 0) {
      if (free_page_count == 0) {
        page_index = i; // potential start of free pages
      }
      free_page_count++;
      if (free_page_count >= required_pages) {
        break; // found enough free pages
      }
    } else {
      free_page_count = 0;
    }
  }
  if (free_page_count < required_pages) {
    return 0; // not enough free pages available
  }

  // found, mark pages as allocated
  for (unsigned short i = page_index; i < page_index + required_pages; i++) {
    hcb->bitmap[i / 8] |= (1 << (i % 8));
  }

  // initialize page control blocks for these pages
  for (unsigned short i = page_index; i < page_index + required_pages; i++) {
    page_control_block __far *pcb = &hcb->pcb_list[i];
    pcb->lb_flags = PAGE_FLAG_LARGE;
    if (i == page_index) {
      pcb->lb_flags |= PAGE_FLAG_LARGE_FIRST_PAGE;
    } else if (i == page_index + required_pages - 1) {
      pcb->lb_flags |= PAGE_FLAG_LARGE_LAST_PAGE;
    }
    pcb->lb_page_count = required_pages & 0xff;
    pcb->lb_first_page = ((required_pages << 4) & 0xf000) | (page_index & 0x0fff);
  }

  // return linear address of the first page as the block address
  unsigned long page_linear = heap_linear + PAGE_SIZE * page_index;
  unsigned short page_seg = heap_seg;
  while (page_linear - ((unsigned long)page_seg << 4) > 0xFFFF) {
    page_seg++;
  }
  unsigned short page_off = page_linear - ((unsigned long)page_seg << 4);
  return (void __far *)MK_FP(page_seg, page_off);
}

void __far *heap_far_allocate(unsigned long heap, unsigned long size) {
  if (size == 0) {
    return 0; // cannot allocate zero bytes
  }
  heap_control_block __far *hcb = (heap_control_block __far *)heap_linear_to_far(heap);
  if (hcb->magic[0] != 'H' || hcb->magic[1] != 'C' || hcb->magic[2] != 'B' || hcb->magic[3] != '\0') {
    return 0; // invalid heap control block
  }
  unsigned long aligned_size = MIN_BLOCK_SIZE;
  while (aligned_size < size && aligned_size < PAGE_SIZE) {
    aligned_size <<= 1;
  }
  if (aligned_size < size) {
    aligned_size = (size + PAGE_SIZE - 1) & ~PAGE_ALIGN_MASK; // align to page size for large blocks
  }
  if (aligned_size < PAGE_SIZE) {
    return heap_far_allocate_small(hcb, aligned_size);
  } else {
    unsigned short required_pages = aligned_size >> PAGE_ALIGN_BITS;
    return heap_far_allocate_large(hcb, required_pages);
  }
}

void heap_far_free_small(heap_control_block __far *hcb,
                         unsigned short page_index,
                         unsigned short pool_index,
                         unsigned short block_size,
                         unsigned char block_index) {
  page_control_block __far *pcb = &hcb->pcb_list[page_index];
  pcb->sb_ref_count--; // decrease ref count for this page
  if (pcb->sb_ref_count == 0) {
    // remove from free page list
    unsigned short pi = hcb->free_pages_header[pool_index] & PAGE_MASK_LOW_12_BITS;
    if (pi == page_index) {
      hcb->free_pages_header[pool_index] = pcb->sb_next_page & PAGE_MASK_LOW_12_BITS;
    } else {
      while (pi != 0) {
        unsigned short next_pi = hcb->pcb_list[pi].sb_next_page & PAGE_MASK_LOW_12_BITS;
        if (next_pi == page_index) {
          hcb->pcb_list[pi].sb_next_page =
              (hcb->pcb_list[pi].sb_next_page & PAGE_MASK_HIGH_4_BITS) | (pcb->sb_next_page & PAGE_MASK_LOW_12_BITS);
          break;
        }
        pi = next_pi;
      }
    }
    // mark page as free in bitmap
    hcb->bitmap[page_index / 8] &= ~(1 << (page_index % 8));
  } else {
    // if this page was fully allocated, add it back to free page list of the pool
    if (pcb->sb_free_blocks_header == 0xff) {
      pcb->sb_next_page =
          ((pool_index << 12) & PAGE_MASK_HIGH_4_BITS) | (hcb->free_pages_header[pool_index] & PAGE_MASK_LOW_12_BITS);
      hcb->free_pages_header[pool_index] = page_index;
    }
    // calculate the address of the freed block
    unsigned short heap_seg = FP_SEG(hcb);
    unsigned short heap_off = FP_OFF(hcb);
    unsigned long heap_linear = ((unsigned long)heap_seg << 4) + heap_off;
    unsigned long block_linear = heap_linear + PAGE_SIZE * page_index + block_size * block_index;
    unsigned short block_seg = heap_seg;
    while (block_linear - ((unsigned long)block_seg << 4) > 0xFFFF) {
      block_seg++;
    }
    unsigned short block_off = block_linear - ((unsigned long)block_seg << 4);
    unsigned char __far *block = (unsigned char __far *)MK_FP(block_seg, block_off);
    // make the block point to current free block list head
    *(unsigned char __far *)block = pcb->sb_free_blocks_header;
    // set free block list head to this block
    pcb->sb_free_blocks_header = block_index;
  }
}

void heap_far_free_large(heap_control_block __far *hcb, unsigned short page_index, unsigned short page_count) {
  for (unsigned short i = page_index; i < page_index + page_count; i++) {
    page_control_block __far *pcb = &hcb->pcb_list[i];
    if (i == page_index && (pcb->lb_flags & PAGE_FLAG_LARGE_FIRST_PAGE) == 0) {
      return; // not the first page of a large block, cannot free
    }
    if ((pcb->lb_flags & PAGE_FLAG_LARGE) == 0) {
      return; // not a large block, invalid state
    }
    if (((pcb->lb_first_page & PAGE_MASK_HIGH_4_BITS) >> 4) | (pcb->lb_page_count & 0x0ff) != page_count) {
      return; // inconsistent page count, invalid state
    }
    if ((pcb->lb_first_page & PAGE_MASK_LOW_12_BITS) != page_index) {
      return; // inconsistent first page index, invalid state
    }
    if (i == page_index + page_count - 1 && (pcb->lb_flags & PAGE_FLAG_LARGE_LAST_PAGE) == 0) {
      return; // last page does not have last page flag, invalid state
    }
  }
  for (unsigned short i = page_index; i < page_index + page_count; i++) {
    hcb->bitmap[i / 8] &= ~(1 << (i % 8)); // mark page as free in bitmap
  }
}

void heap_far_free(unsigned long heap, void __far *address) {
  heap_control_block __far *hcb = (heap_control_block __far *)heap_linear_to_far(heap);
  if (hcb->magic[0] != 'H' || hcb->magic[1] != 'C' || hcb->magic[2] != 'B' || hcb->magic[3] != '\0') {
    return; // invalid heap control block
  }
  unsigned short address_seg = FP_SEG(address);
  unsigned short address_off = FP_OFF(address);
  unsigned long address_linear = ((unsigned long)address_seg << 4) + address_off;
  unsigned short page_index = (address_linear - heap) >> PAGE_ALIGN_BITS;
  if (page_index < hcb->reserved_pages || page_index >= hcb->page_count) {
    return; // invalid address
  }
  page_control_block __far *pcb = &hcb->pcb_list[page_index];
  if (pcb->lb_flags & PAGE_FLAG_LARGE) {
    if (((address_linear - heap) & PAGE_ALIGN_MASK) != 0) {
      return; // address is not aligned to page size
    }
    unsigned short page_count = ((pcb->lb_first_page & PAGE_MASK_HIGH_4_BITS) >> 4) | (pcb->lb_page_count & 0x0ff);
    heap_far_free_large(hcb, page_index, page_count);
  } else {
    unsigned short pool_index = ((pcb->sb_next_page & PAGE_MASK_HIGH_4_BITS) >> 12);
    unsigned short block_size = MIN_BLOCK_SIZE << pool_index;
    if (((unsigned short)((address_linear - heap) & PAGE_ALIGN_MASK)) % block_size != 0) {
      return; // address is not aligned to block size
    }
    unsigned char block_index = ((unsigned short)((address_linear - heap) & PAGE_ALIGN_MASK)) / block_size;
    heap_far_free_small(hcb, page_index, pool_index, block_size, block_index);
  }
}

unsigned long heap_init(void *heap_start, unsigned long heap_size) {
  return heap_far_init(heap_near_to_far(heap_start), heap_size);
}

void *heap_allocate(unsigned long heap, unsigned long size) {
  return heap_far_to_near(heap_far_allocate(heap, size));
}

void heap_free(unsigned long heap, void *address) {
  heap_far_free(heap, heap_near_to_far(address));
}

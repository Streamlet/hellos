; memory layout:
%ifndef __LAYOUT_ASM_INCLUDED__
%define __LAYOUT_ASM_INCLUDED__

STAGE1_ADDRESS          equ 0x7C00  ; standard bootloader load address
STAGE2_ADDRESS          equ 0x7E00  ; stage2 bootloader load address, one sector (512 bytes) after stage1
STAGE2_SECTOR_COUNT     equ 7       ; stage2 bootloader size in sectors (7 sectors = 3.5KB, together with stage1 is 4KB)

KERNEL_ADDRESS_SEGMENT  equ 0x8000  ; kernel load segment
KERNEL_ADDRESS_OFFSET   equ 0x0000  ; kernel load offset

%endif  ; __LAYOUT_ASM_INCLUDED__

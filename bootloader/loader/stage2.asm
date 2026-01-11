org 0x8000  ; the stage2 bootloader load address
bits 16     ; 16-bit real mode

; %include "debug.asm"

init_registers:
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x8000

find_bootable_partition:
    mov si, 0x7C00 + 446    ; load partition table address into SI
    mov cl, 4               ; 4 partition entries to check
    .next_partition:
        mov al, [si]        ; load boot indicator byte
        cmp al, 0x80        ; check if bootable
        je check_partition_type
        add si, 16          ; move to next partition entry (16 bytes each)
        dec cl              ; decrement counter
        jnz .next_partition
    mov si, msg_no_boot_partition_found
    call print_string
    jmp $

FAT_TYPE_12 equ 3       ; value indicates bytes per two fat items
FAT_TYPE_16 equ 4       ;
FAT_TYPE_32 equ 8       ;
fat_type db 0           ; FAT_TYPE_*
check_partition_type:
    xor ah, ah          ; clear AH
    mov al, [si + 4]    ; load partition type byte
    cmp al, 0x01        ; check if FAT12 partition
    je .fat12
    cmp al, 0x04        ; check if FAT16 partition (< 65536 sectors)
    je .fat16
    cmp al, 0x06        ; check if FAT16B partition (>= 65536 sectors)
    je .fat16
    cmp al, 0x0B        ; check if FAT32 partition (CHS)
    je .fat32
    cmp al, 0x0C        ; check if FAT32 partition (LBA)
    je .fat32
    cmp al, 0x0E        ; check if FAT16B partition (LBA)
    je .fat16
    mov si, msg_unsupported_partition
    call print_string
    jmp $
    .fat12:
    mov byte [fat_type], FAT_TYPE_12
    jmp load_vbr
    .fat16:
    mov byte [fat_type], FAT_TYPE_16
    jmp load_vbr
    .fat32:
    mov byte [fat_type], FAT_TYPE_32
    jmp load_vbr

VBR_ADDRESS equ 0xA000
BYTES_PER_SECTOR equ VBR_ADDRESS + 0x0B
SECTORS_PER_CLUSTER equ VBR_ADDRESS + 0x0D
RESERVED_SECTORS equ VBR_ADDRESS + 0x0E
NUM_FATS equ VBR_ADDRESS + 0x10
MAX_ROOT_DIR_ENTRIES equ VBR_ADDRESS + 0x11
TOTAL_SECTORS_16 equ VBR_ADDRESS + 0x13
MEDIA_DESCRIPTOR equ VBR_ADDRESS + 0x15
SECTORS_PER_FAT equ VBR_ADDRESS + 0x16
SECTORS_PER_TRACK equ VBR_ADDRESS + 0x18
NUM_HEADS equ VBR_ADDRESS + 0x1A
HIDDEN_SECTORS equ VBR_ADDRESS + 0x1C
TOTAL_SECTORS_32 equ VBR_ADDRESS + 0x20
SECTORS_PER_FAT_32 equ VBR_ADDRESS + 0x24
load_vbr:
    push 0
    push 0
    mov ax, [si + 10]
    push ax
    mov ax, [si + 8]
    push ax
    push 0
    push VBR_ADDRESS
    push 1
    push LBA_PACKET_SIZE
    call bios_load_sector_lba
    add sp, 16
    jnc set_fat_globals
    mov si, msg_failed_to_load_vbr
    call print_string
    jmp $
    .vbr_loaded:
        ret


fat_table_lba dd 0
root_dir_lba dd 0
root_dir_sectors dw 0
data_lba dd 0

set_fat_globals:
    mov ax, [si + 8]                ; load starting LBA (4 bytes) into BX:AX
    mov bx, [si + 10]
    add ax, [RESERVED_SECTORS]
    adc bx, 0
    mov word [fat_table_lba], ax
    mov word [fat_table_lba + 2], bx
    mov cl, [NUM_FATS]              ; fats count
    .add_fats:
        add ax, [SECTORS_PER_FAT]   ; sectors per fat
        adc bx, 0
        dec cl
    jnz .add_fats
    mov word [root_dir_lba], ax
    mov word [root_dir_lba + 2], bx
    push ax
    mov ax, [MAX_ROOT_DIR_ENTRIES]  ; root dir entries
    mov dx, 32
    mul dx                          ; dx:ax = root dir entries * 32
    mov cx, [BYTES_PER_SECTOR]      ; bytes per sector
    div cx                          ; ax = number of sectors in root dir
    neg dx                          ; if remainder, add one more sector
    adc ax, 0
    mov cx, ax                      ; CX = root dir sectors
    mov word [root_dir_sectors], cx
    pop ax
    add ax, cx
    adc bx, 0
    mov word [data_lba], ax
    mov word [data_lba + 2], bx
    jmp load_root_dir

ROOT_DIR_LBA equ 0xB000
load_root_dir:
    push 0
    push 0
    mov ax, [root_dir_lba + 2]
    push ax
    mov ax, [root_dir_lba]
    push ax
    push 0
    push ROOT_DIR_LBA
    mov ax, [root_dir_sectors]
    push ax
    push LBA_PACKET_SIZE
    call bios_load_sector_lba
    add sp, 16
    jnc find_kernel_file
    mov si, msg_failed_to_load_root_dir
    call print_string
    jmp $

kernel_file_name db 'KERNEL  BIN ', 0 ; 11 bytes (8.3 format)
kernel_file_cluster dw 0
find_kernel_file:
    mov si, 0xB000       ; start of root directory
    mov di, kernel_file_name
    mov cx, [MAX_ROOT_DIR_ENTRIES]
    .next_entry:
        mov al, [si]        ; load first byte of entry
        cmp al, 0           ; check for end of directory
        je .not_found
        cmp al, 0xE5        ; check for deleted entry
        je .skip_entry
        mov ah, [si + 0x0B] ; load attribute byte
        and ah, 0x18        ; check if it's a volume label or directory
        jne .skip_entry
        cmp al, 0x05
        jne .compare_filename
        mov al, 0xE5        ; treat 0x05 as 0xE5 for comparison
        .compare_filename:
            push si
            push cx
            mov cx, 12      ; compare 12 bytes (8.3 format)
            call strncmp
            pop cx
            pop si
            jnz .skip_entry ; if not equal, skip to next entry
        ; if we reach here, the filename matches
        mov dx, [si + 0x1E]
        cmp dx, 2           ; max 128K file size (2 sectors of 64K)
        ja .too_large_file
        ; load starting cluster (2 bytes at offset 0x1A)
        mov ax, [si + 0x1A]
        mov [kernel_file_cluster], ax
        jmp load_kernel_file
    .skip_entry:
        add si, 32          ; move to next entry (32 bytes each)
        loop .next_entry
    .not_found:
        mov si, msg_kernel_file_not_found
        call print_string
        jmp $               ; halt execution if kernel file not found
    .too_large_file:
        mov si, msg_kernel_file_too_large
        call print_string
        jmp $               ; halt execution if file is too large

FAT_TABLE_ITEMS_EOC_12 equ 0x0FF8
FAT_TABLE_ITEMS_EOC_16 equ 0xFFF8
FAT_TABLE_ITEMS_EOC_32 equ 0x0FFFFFF8
FAT_ADDRESS equ 0xC000
KERNEL_ADDRESS_SEGMENT equ 0x8000
KERNEL_ADDRESS_OFFSET equ 0x0000
load_kernel_file:
    mov si, [kernel_file_cluster]
    mov ax, KERNEL_ADDRESS_SEGMENT
    mov es, ax
    mov di, KERNEL_ADDRESS_OFFSET
    .next_cluster:
        ; calculate starting LBA: data_lba + (cluster - 2) * sectors_per_cluster
        mov ax, si
        sub ax, 2
        movzx cx, byte [SECTORS_PER_CLUSTER]
        mul cx  ; dx:ax = (cluster - 2) * sectors_per_cluster
        add ax, [data_lba]
        adc dx, [data_lba + 2]
        push 0
        push 0
        push dx
        push ax
        push es
        push di
        movzx ax, byte [SECTORS_PER_CLUSTER]
        push ax
        push LBA_PACKET_SIZE
        call bios_load_sector_lba
        add sp, 16
        jc .load_error

        ; increment to ES:DI to point to next free space for next cluster
        mov ax, [BYTES_PER_SECTOR]
        mul cx  ; dx:ax = sectors_per_cluster * bytes_per_sector = bytes to advance
        add di, ax
        adc dx, 0
        shl dx, 12
        mov ax, es
        add ax, dx
        mov es, ax

        ; set SI to next cluster
        call find_next_cluster
        jc .load_error
        mov si, ax
        .fat12:
            cmp bx, FAT_TYPE_12
            jne .fat16
            cmp si, FAT_TABLE_ITEMS_EOC_12  ; check for end-of-chain markers
            jb .next_cluster                ; if not end of chain, load next cluster
            jmp jump_to_kernel
        .fat16:
            cmp bx, FAT_TYPE_16
            jne .fat32
            cmp si, FAT_TABLE_ITEMS_EOC_16  ; check for end-of-chain markers
            jb .next_cluster                ; if not end of chain, load next cluster
            jmp jump_to_kernel
        .fat32:
    .load_error:
        mov si, msg_failed_to_load_kernel_file
        call print_string
        jmp $

jump_to_kernel:
    jmp KERNEL_ADDRESS_SEGMENT:KERNEL_ADDRESS_OFFSET

; function to find the next cluster in FAT
; inputs: SI = current cluster number
; outputs: DX:AX = next cluster number, CF set on error
find_next_cluster:
    ; FAT entry address: fat_table_lba + cluster * fat_type / bytes_per_sector
    mov ax, si
    movzx bx, byte [fat_type]
    mul bx                      ; dx:ax = cluster * bytes_per_2items = next_cluster_offset * 2
    shr dx, 1
    rcr ax, 1                   ; dx:ax = cluster * bytes_per_items = next_cluster_offset
    mov bx, [BYTES_PER_SECTOR]  ; load bytes per sector
    div bx                      ; ax = sector offset, dx = byte offset
    push dx
    xor dx, dx
    add ax, [fat_table_lba]
    adc dx, [fat_table_lba + 2]
    push 0
    push 0
    push dx
    push ax                    ; Starting LBA
    push 0                     ; Segment of output buffer
    push FAT_ADDRESS           ; Offset of output buffer
    push 1                     ; Number of sectors to read
    push LBA_PACKET_SIZE       ; Size of packet
    call bios_load_sector_lba
    add sp, 16
    jc .end             ; Check for errors
    pop dx
    push si
    mov si, FAT_ADDRESS
    add si, dx
    mov ax, [si]
    mov dx, [si + 2]
    pop si
    movzx bx, byte [fat_type]
    cmp bx, FAT_TYPE_12
    jnz .end
    test si, 1                  ; check if cluster number is odd or even
    jz .even
    .odd:
        shr ax, 4               ; odd cluster, get high 12 bits
    .even:
        and ax, 0x0FFF          ; mask to get 12-bit FAT entry
    .end:
        ret


; function to load sectors from disk using LBA
; inputs: stack
;   db 16 : size of packet
;   db 0  : reserved
;   dw 0  : number of sectors to read
;   dw 0  : offset of output buffer
;   dw 0  : segment of output buffer
;   dw 0  : starting LBA, 0-15 bits
;   dw 0  :               16-31 bits
;   dw 0  :               32-47 bits
;   dw 0  :               48-63 bits
; output: CF is set on error, clear if no error
LBA_PACKET_SIZE equ 0x0010
bios_load_sector_lba:
    push si
    mov si, sp
    add si, 4       ; load pointer to LBA packet
    mov ah, 0x42    ; bios read sectors function (LBA)
    mov dl, 0x80    ; drive number (first hard disk)
    int 0x13        ; call BIOS disk interrupt
    pop si
    ret

; function to print a null-terminated string at the current cursor position
; input: DS:SI points to the string
print_string:
    mov ah, 0x0E        ; bios teletype function to print character in AL
    .loop:
        lodsb           ; AL = [DS:SI], SI++
        test al, al     ; test for null terminator
        je .end         ; if zero, end of string, jump to halt
        int 0x10        ; call BIOS video interrupt to print character in AL
        jmp .loop       ; repeat for next character
    .end:
        ret

; function to compare two null-terminated strings
; input: SI points to full string, DI points to prefix string, CX = length of the part to compare
; output: ZF set if equal, clear if not equal
strncmp:
    .loop:
        test cx, cx
        je .end         ; if length is zero, strings are equal, jump to end
        mov al, [si]    ; load byte from first string
        cmp al, [di]    ; compare bytes
        jne .end        ; if not equal, jump to end
        inc si          ; move to next byte in first string
        inc di          ; move to next byte in second string
        dec cx          ; decrement length
        jmp .loop       ; repeat comparison
    .end:
        ret

; message string
msg_no_boot_partition_found db 'Error: no bootable partition found.', 0x0D, 0x0A, 0
msg_unsupported_partition db 'Error: unsupported partition type.', 0x0D, 0x0A, 0
msg_failed_to_load_vbr db 'Error: failed to load VBR.', 0x0D, 0x0A, 0
msg_failed_to_load_root_dir db 'Error: failed to load root directory.', 0x0D, 0x0A, 0
msg_kernel_file_not_found db 'Error: kernel file not found.', 0x0D, 0x0A, 0
msg_kernel_file_too_large db 'Error: kernel file larger than 128K.', 0x0D, 0x0A, 0
msg_failed_to_load_kernel_file db 'Error: failed to load kernel file.', 0x0D, 0x0A, 0

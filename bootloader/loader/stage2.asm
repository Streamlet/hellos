org 0x8000  ; the standard bootloader load address
bits 16     ; 16-bit real mode

%macro DEBUG_PRINT 1
    mov [debug_buffer], %1
    call debug_print_hex
%endmacro

find_bootable_partition:
    .find_partition:
        mov si, 0x7C00 + 446    ; load partition table address into SI
        mov cl, 4               ; 4 partition entries to check
        .next_partition:
            mov al, [si]        ; load boot indicator byte
            cmp al, 0x80        ; check if bootable
            je .check_partition_type
            add si, 16          ; move to next partition entry (16 bytes each)
            dec cl              ; decrement counter
            jnz .next_partition
        mov si, msg_no_boot_partition_found
        call print_string
        jmp halt
    .check_partition_type:
        xor ah, ah          ; clear AH
        mov al, [si + 4]    ; load partition type byte
        cmp al, 0x01        ; check if FAT12 partition
        je fat12
        cmp al, 0x04        ; check if FAT16 partition (< 65536 sectors)
        je fat16
        cmp al, 0x06        ; check if FAT16B partition (>= 65536 sectors)
        je fat16
        cmp al, 0x0B        ; check if FAT32 partition (CHS)
        je fat32
        cmp al, 0x0C        ; check if FAT32 partition (LBA)
        je fat32
        cmp al, 0x0E        ; check if FAT16B partition (LBA)
        je fat16
        mov si, msg_unsupported_partition
        call print_string
        jmp halt

fat_lba dd 0
root_dir_lba dd 0
root_dir_sectors dw 0
data_lba dd 0
fat12:
    call load_vbr
    mov ax, [si + 8]            ; load starting LBA (4 bytes) into BX:AX
    mov bx, [si + 10]
    add ax, [RESERVED_SECTORS]  ; reserved sectors
    adc bx, 0
    mov word [fat_lba], ax
    mov word [fat_lba + 2], bx
    mov cl, [NUM_FATS]          ; fats count
    .add_fats:
        add ax, [SECTORS_PER_FAT_16]   ; sectors per fat
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

    call load_root_dir
    call find_kernel_file
    call load_kernel_file
    call jump_to_kernel

fat16:
    call load_vbr
    jmp halt

fat32:
    call load_vbr
    jmp halt

; function to load vbr
; input: SI = pointer to partition entry
; output: none (loads VBR into memory at 0xA000)
VBR_ADDRESS equ 0xA000
BYTES_PER_SECTOR equ VBR_ADDRESS + 0x0B
SECTORS_PER_CLUSTER equ VBR_ADDRESS + 0x0D
RESERVED_SECTORS equ VBR_ADDRESS + 0x0E
NUM_FATS equ VBR_ADDRESS + 0x10
MAX_ROOT_DIR_ENTRIES equ VBR_ADDRESS + 0x11
TOTAL_SECTORS_16 equ VBR_ADDRESS + 0x13
MEDIA_DESCRIPTOR equ VBR_ADDRESS + 0x15
SECTORS_PER_FAT_16 equ VBR_ADDRESS + 0x16
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
    jnc .vbr_loaded
    mov si, msg_failed_to_load_vbr
    call print_string
    jmp halt
    .vbr_loaded:
        ret

; function to load root directory
; input: none (uses global variables)
; output: none (loads root directory into memory at 0xB000)
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
    jnc .root_dir_loaded  ; change label to reflect root dir loading
    mov si, msg_failed_to_load_root_dir
    call print_string
    jmp halt
    .root_dir_loaded:  ; change label to reflect root dir loading
        ret

; function to find kernel file in root directory
; input: none (uses memory at ROOT_DIR_LBA and global variables)
; output: none (sets global variable with starting LBA of kernel file and size)
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
            call strcmp_prefix
            pop si
            jnz .skip_entry   ; if not equal, skip to next entry
        ; if we reach here, the filename matches
        ; mov ax, [si + 0x1C]
        mov dx, [si + 0x1E]
        cmp dx, 2   ; max 128K file size (2 sectors of 64K)
        jg .too_large_file
        ; load starting cluster (2 bytes at offset 0x1A)
        mov ax, [si + 0x1A]
        mov [kernel_file_cluster], ax
        ret
    .skip_entry:
        add si, 32          ; move to next entry (32 bytes each)
        loop .next_entry
    .not_found:
        mov si, msg_kernel_file_not_found
        call print_string
        jmp halt            ; halt execution if kernel file not found
    .too_large_file:
        mov si, msg_kernel_file_too_large
        call print_string
        jmp halt            ; halt execution if file is too large

; function to load kernel file
; input: none (uses global variables)
; output: none (loads kernel into memory at 0x80000)
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

        ; get next cluster from FAT
        ; FAT entry address: fat_lba + cluster * 1.5 / bytes_per_sector
        mov ax, si
        mov bx, 3
        mul bx                      ; dx:ax = cluster * 3
        shr dx, 1
        rcr ax, 1                   ; dx:ax = cluster * 1.5
        mov bx, [BYTES_PER_SECTOR]  ; load bytes per sector
        div bx                      ; ax = sector offset, dx = byte offset
        push dx
        xor dx, dx
        add ax, [fat_lba]
        adc dx, [fat_lba + 2]
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
        jc .load_error             ; Check for errors
        pop dx
        push si
        mov si, FAT_ADDRESS
        add si, dx
        mov ax, [si]
        pop si
        ; if si is odd, get high 12 bits, else low 12 bits
        test si, 1
        jz .even
        .odd:
            shr ax, 4               ; Odd cluster, get high 12 bits
        .even:
            and ax, 0x0FFF          ; Mask to get 12-bit FAT entry
        mov si, ax
        cmp si, 0x0FF8              ; check for end-of-chain markers
        jl .next_cluster            ; if not end of chain, load next cluster
        ret
    .load_error:
        mov si, msg_failed_to_load_kernel_file
        call print_string
        jmp halt

jump_to_kernel:
    jmp KERNEL_ADDRESS_SEGMENT:KERNEL_ADDRESS_OFFSET


; wait forever
halt:
    hlt         ; halt the CPU
    jmp halt

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
    mov ah, 0x0E    ; bios teletype function to print character in AL
    .loop:
        lodsb           ; AL = [DS:SI], SI++
        cmp al, 0       ; test for null terminator
        je .end         ; if zero, end of string, jump to halt
        int 0x10        ; call BIOS video interrupt to print character in AL
        jmp .loop       ; repeat for next character
    .end:
        ret

; function to compare two null-terminated strings
; input: SI points to full string, DI points to prefix string
; output: ZF set if equal, clear if not equal
strcmp_prefix:
    .loop:
        mov al, [si]    ; load byte from first string
        mov bl, [di]    ; load byte from second string
        cmp bl, 0       ; check for null terminator in prefix
        je .end         ; if null terminator, prefix matches, jump to end
        cmp al, bl      ; compare bytes
        jne .end        ; if not equal, jump to end
        cmp al, 0       ; check for null terminator
        je .end         ; if null terminator, strings are equal, jump to end
        inc si          ; move to next byte in first string
        inc di          ; move to next byte in second string
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


; 16 byte buffer for debug print
debug_buffer times 16 db 0  ; Reserve 16 bytes for the debug buffer
debug_print_hex:
    pusha
    mov ah, 0x0E
    mov ch, 16
    mov si, debug_buffer
    .loop_bytes:
        mov cl, 4
        .loop_chars:
            mov al, [si]
            shr al, cl
            and al, 0x0F
            cmp al, 9
            jg .hex
            .digit:
                add al, '0'
                jmp .print
            .hex:
                add al, 'A' - 10
                jmp .print
            .print:
                int 0x10
                cmp cl, 0
                jz .byte_done
                xor cl, cl
                and al, 0x0F
                jmp .loop_chars
        .byte_done:
            inc si
            dec ch
            jz .done
            mov al, ' '
            int 0x10
            jmp .loop_bytes
    .done:
        mov al, 0x0D
        int 0x10
        mov al, 0x0A
        int 0x10
        popa
        ret

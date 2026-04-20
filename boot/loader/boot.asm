org 0x7C00  ; the standard bootloader load address
bits 16     ; 16-bit real mode

init_registers:
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00

clean_screen:
    mov ax, 0x0003  ; AH=00h, AL=03h (mode 3: 80x25 text), reset video mode to clear screen
    int 0x10

print_hello:
    mov si, msg_loading
    call print_string

load_stage2:
    mov si, lba_packet
    call bios_load_sector_lba
    jnc jmp_to_stage2
    mov si, msg_loading_error
    call print_string
    jmp $

STAGE2_ADDRESS_SEGMENT equ 0x0000
STAGE2_ADDRESS_OFFSET equ 0x8000
jmp_to_stage2:
    jmp STAGE2_ADDRESS_SEGMENT:STAGE2_ADDRESS_OFFSET


; function to print a null-terminated string at the current cursor position
; input: DS:SI points to the string
print_string:
    mov ah, 0x0E    ; bios teletype function to print character in AL
    .loop:
        lodsb           ; AL = [DS:SI], SI++
        test al, al     ; test for null terminator
        je .end         ; if zero, end of string, jump to halt
        int 0x10        ; call BIOS video interrupt to print character in AL
        jmp .loop       ; repeat for next character
    .end:
        ret


; function to load sectors from disk using LBA
; inputs: SI = pointer to LBA packet
lba_packet:
    db 16                       ; size of packet
    db 0                        ; reserved
    .lba_packet_sectors:
    dw 7                        ; number of sectors to read
    .lba_packet_buffer:
    dw STAGE2_ADDRESS_OFFSET    ; offset of buffer
    dw STAGE2_ADDRESS_SEGMENT   ; segment of buffer
    .lba_packet_lba:
    dd 1                        ; low dword of starting LBA (set later)
    dd 0                        ; high dword of starting LBA (set later)
bios_load_sector_lba:
    mov ah, 0x42    ; bios read sectors function (LBA)
    mov dl, 0x80    ; drive number (first hard disk)
    int 0x13        ; call BIOS disk interrupt
    ret

; predefined strings
msg_loading db 'Welcome to HellOS!', 0x0D, 0x0A, 0x0D, 0x0A, 'Loading kernel...', 0x0D, 0x0A, 0
msg_loading_error db 'Error reading sectors. Disk too small?', 0x0D, 0x0A, 0
times 446 - ($ - $$) db 0 ; fill with 0 until the 446th byte

; boot loader code: 446 bytes
; partition table: 16 bytes each, 4 entries
; boot flag: 2 bytes
; total: 512 bytes
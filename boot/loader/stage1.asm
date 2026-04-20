; stage1 bootloader

org 0x7C00  ; the standard bootloader load address
bits 16     ; 16-bit real mode

; initialization

init_registers:
    mov ax, cs
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00

clean_screen:
    mov ax, 0x0003  ; AH=00h, AL=03h (mode 3: 80x25 text), reset video mode to clear screen
    int 0x10

; main routine

main:
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

; functions
; callee-saved registers: BP, DS
; caller-saved registers: AX, BX, CX, DX, SI, DI, ES
; return value: AX (16-bit), DX:AX (32-bit)

; print a null-terminated string at the current cursor position
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

; load sectors from disk using LBA
; inputs: SI=pointer to LBA packet
bios_load_sector_lba:
    mov ah, 0x42    ; bios read sectors function (LBA)
    mov dl, 0x80    ; drive number (first hard disk)
    int 0x13        ; call BIOS disk interrupt
    ret

; data

; LBA packet for BIOS interrupt 0x13, function 0x42
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

; strings
msg_loading db 'Welcome to HellOS!', 0x0D, 0x0A, 0x0D, 0x0A, 'Loading kernel...', 0x0D, 0x0A, 0
msg_loading_error db 'Error reading sectors. Disk too small?', 0x0D, 0x0A, 0
; padding
times 446 - ($ - $$) db 0
; do not padding to 512 bytes, or the partition table will be overwritten
; boot signature will be added by mkdisk.sh

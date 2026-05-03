; stage1 bootloader

%include "layout.asm"

org STAGE1_ADDRESS  ; the stage1 bootloader load address
bits 16             ; 16-bit real mode

; initialization

start:
    ; Some BIOSes load the bootloader with a non-zero segment, which can cause issues when accessing data with hardcoded offsets
    jmp 0x0000:init_registers   ; force cs to be 0; 

init_registers:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, start


; main routine

main:
    call bios_clean_screen  ; clear the screen
    mov si, msg_loading     ; load loading message into SI
    call bios_print_string  ; print the loading message

    ; load stage2 bootloader
    mov bx, STAGE2_ADDRESS      ; BX = destination address to load stage2
    mov al, STAGE2_SECTOR_COUNT ; AL = number of sectors to read
    call bios_load_sector_chs   ; load stage2 sectors
    jc .error_load_sector
    jmp STAGE2_ADDRESS          ; jump to stage2 bootloader
    .error_load_sector:
    mov si, msg_loading_error   ; load error message into SI
    call bios_print_string      ; print error message
    jmp $                       ; infinite loop to halt the system


; functions
; caller-saved registers: AX, CX, DX
; callee-saved registers: The rests
; return value: AX (16-bit), DX:AX (32-bit)

; print a null-terminated string at the current cursor position
; input: DS:SI points to the string
bios_print_string:
    mov ah, 0x0E    ; bios teletype function to print character in AL
    .loop:
        lodsb       ; AL = [DS:SI], SI++
        test al, al ; test for null terminator
        je .end     ; if zero, end of string, jump to halt
        int 0x10    ; call BIOS video interrupt to print character in AL
        jmp .loop   ; repeat for next character
    .end:
        ret

; clean screen by resetting video mode
bios_clean_screen:
    mov ax, 0x0003  ; AH=00h, AL=03h (mode 3: 80x25 text), reset video mode to clear screen
    int 0x10
    ret

; load sectors from disk using CHS
; inputs: AL = number of sectors to read
;         ES:BX = destination buffer address
; outputs：CF = 0 succeeded, 1 failed
;          AH = status code (if CF=1)
;          AL = number of sectors read (if CF=0)
bios_load_sector_chs:
    mov ah, 0x02    ; bios read sectors function (CHS)
    mov ch, 0       ; cylinder number (low 8 bits) = 0
    mov cl, 2       ; sector number (low 6 bits) = 2 (note: sector numbers start from 1), cylinder number (high 2 bits) = 0
    mov dh, 0       ; head number = 0
    mov dl, 0x80    ; drive number (0x80 = first hard disk)
    int 0x13        ; call BIOS disk interrupt
    ret

; data

; strings
msg_loading         db 'Welcome to HellOS!', 0x0D, 0x0A, 0x0D, 0x0A, 'Loading kernel...', 0x0D, 0x0A, 0
msg_loading_error   db 'Error reading sectors. Disk too small?', 0x0D, 0x0A, 0

; padding
times 446 - ($ - $$) db 0
; do not padding to 512 bytes, or the partition table will be overwritten when writing to disk
; boot signature will be added by mkdisk.sh

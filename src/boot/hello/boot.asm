; a simple bootloader that prints "Hello, OS!" to the screen.

org 0x7C00  ; the standard bootloader load address
bits 16     ; 16-bit real mode

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
    mov si, msg_hello       ; load address of hello message into SI
    call bios_print_string  ; print the hello message
    jmp $                   ; infinite loop to halt the system

; functions

; print a null-terminated string at the current cursor position
; input: DS:SI points to the string
bios_print_string:
    mov ah, 0x0E    ; bios teletype function to print character in AL
    .loop:
        lodsb       ; AL = [DS:SI], SI++
        test al, al ; test for null terminator
        je .end     ; if zero, end of string, jump to end
        int 0x10    ; call BIOS video interrupt to print character in AL
        jmp .loop   ; repeat for next character
    .end:
        ret

; clean screen by resetting video mode
bios_clean_screen:
    mov ax, 0x0003  ; AH=00h, AL=03h (mode 3: 80x25 text), reset video mode to clear screen
    int 0x10
    ret


; data

; strings
msg_hello db 'Hello, OS!', 0x0D, 0x0A, 0

; padding
times 510 - ($ - $$) db 0

; boot signature (last two bytes must be 0xAA55)
dw 0xAA55

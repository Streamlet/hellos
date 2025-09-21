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
    mov si, msg     ; load address of msg into SI
    mov ah, 0x0E    ; bios teletype function to print character in AL
    .loop:
        lodsb           ; AL = [DS:SI], SI++
        test  al, al    ; test for null terminator
        je .end         ; if zero, end of string, jump to halt
        int 0x10        ; call BIOS video interrupt to print character in AL
        jmp .loop       ; repeat for next character
    .end:
        jmp $

; message string
msg db 'Hello, OS!', 0x0D, 0x0A, 0

times 510 - ($ - $$) db 0 ; fill with 0 until the 510th byte
dw 0xAA55                 ; last two bytes are the boot signature

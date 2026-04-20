; a simple bootloader that prints "Hello, OS!" to the screen.

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
    mov si, msg     ; load address of msg into SI
    call bios_print

; functions
; callee-saved registers: BP, DS
; caller-saved registers: AX, BX, CX, DX, SI, DI, ES
; return value: AX (16-bit), DX:AX (32-bit)

; print a null-terminated string at the current cursor position
; input: DS:SI points to the string
bios_print:
    mov ah, 0x0E    ; bios teletype function to print character in AL
    .loop:
        lodsb           ; AL = [DS:SI], SI++
        test al, al     ; test for null terminator
        je .end         ; if zero, end of string, jump to end
        int 0x10        ; call BIOS video interrupt to print character in AL
        jmp .loop       ; repeat for next character
    .end:
        ret

; data

; strings
msg db 'Hello, OS!', 0x0D, 0x0A, 0
; padding
times 510 - ($ - $$) db 0
; boot signature (last two bytes must be 0xAA55)
dw 0xAA55

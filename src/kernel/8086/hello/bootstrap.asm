; A startup file for the 8086 kernel that initializes the segment registers and stack, then jumps to the main function.
[bits 16]   ; 16-bit real mode

extern _kernel_main

section .text

global _start
_start:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, _start
    call _kernel_main
    jmp $

global _small_code_
_small_code_:
    ret

global _print_char
_print_char:
    push bp
    mov bp, sp
    mov al, [bp + 4]    ; get the character argument from the stack
    mov ah, 0x0E        ; BIOS teletype function to print character in AL
    int 0x10            ; call BIOS video interrupt to print character in AL
    pop bp
    ret

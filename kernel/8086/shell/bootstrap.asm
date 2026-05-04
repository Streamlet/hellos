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

global _inb
_inb:
    push bp
    mov bp, sp
    mov dx, [bp + 4]    ; port
    in al, dx           ; read value from port
    xor ah, ah          ; clear upper byte of AX
    pop bp
    ret

global _inw
_inw:
    push bp
    mov bp, sp
    mov dx, [bp + 4]    ; port
    in ax, dx           ; read value from port
    pop bp
    ret

global _outb
_outb:
    push bp
    mov bp, sp
    mov dx, [bp + 4]    ; port
    mov ax, [bp + 6]    ; value
    out dx, al          ; write value to port
    pop bp
    ret

global _outw
_outw:
    push bp
    mov bp, sp
    mov dx, [bp + 4]    ; port
    mov ax, [bp + 6]    ; value
    out dx, ax          ; write value to port
    pop bp
    ret


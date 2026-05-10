; A startup file for the 8086 kernel that initializes the segment registers and stack, then jumps to the main function.
[bits 16]   ; 16-bit real mode

extern __kernel_main
extern __interrupt_entry

section .text

global _start
_start:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, _start
    call init_ivt
    call __kernel_main
    jmp $

global _small_code_
_small_code_:
    ret

global __halt
__halt:
    cli
    hlt

global __disable
__disable:
    cli
    ret

global __enable
__enable:
    sti
    ret

global __inb
__inb:
    push bp
    mov bp, sp
    mov dx, [bp + 4]    ; port
    in al, dx           ; read value from port
    xor ah, ah          ; clear upper byte of AX
    pop bp
    ret

global __inw
__inw:
    push bp
    mov bp, sp
    mov dx, [bp + 4]    ; port
    in ax, dx           ; read value from port
    pop bp
    ret

global __outb
__outb:
    push bp
    mov bp, sp
    mov dx, [bp + 4]    ; port
    mov ax, [bp + 6]    ; value
    out dx, al          ; write value to port
    pop bp
    ret

global __outw
__outw:
    push bp
    mov bp, sp
    mov dx, [bp + 4]    ; port
    mov ax, [bp + 6]    ; value
    out dx, ax          ; write value to port
    pop bp
    ret

init_ivt:
    cli
    call reset_ivt
    call setup_pit
    sti
    ret

IVT_COUNT equ 32

reset_ivt:
    push es
    push si
    push bx
    xor bx, bx
    mov es, bx
    mov si, isr_stub_table
    mov cx, IVT_COUNT
    .loop:
        mov ax, [si]
        mov [es:bx], ax
        mov ax, cs
        mov [es:bx+2], ax
        add bx, 4
        add si, 2
        loop .loop
    pop bx
    pop si
    pop es
    ret

setup_pit:
    ; set PIT channel 0 to mode 3 (square wave generator) with a frequency of 100Hz
    mov dx, 0x43
    mov al, 0x36
    out dx, al  ; control word: channel 0, access mode lobyte/hibyte, mode 3, binary
    mov dx, 0x40
    xor al, al  ; divisor (1193180 / 65536 ≈ 18.2Hz)
    out dx, al  ; low byte
    out dx, al  ; high byte
    ret

isr_stub:
    ; isr_stub_* will push the interrupt number onto the stack before jumping here
    pusha   ; 8 general-purpose registers
    push ds ; 9th
    push es ; 10th
    mov bp, sp
    mov ax, [bp+20]  ; get the interrupt number
    push ax
    call __interrupt_entry
    add sp, 2   ; pop the interrupt number argument
    ; send EOI to PICs if it's a hardware interrupt (INT 0x08 - 0x1F)
    cmp word [bp+20], 0x08
    jb .end
    cmp word [bp+20], 0x20
    jae .end
        mov dx, 0x20
        mov al, 0x20
        out dx, al ; send EOI to PIC
    .end:
    pop es
    pop ds
    popa
    add sp, 2   ; pop the interrupt number pushed by isr_stub_*
    iret

%assign i 0
%rep IVT_COUNT
isr_stub_%+i:
    push i
    jmp isr_stub
%assign i i+1
%endrep


section .data

isr_stub_table:
%assign i 0
%rep IVT_COUNT
    dw isr_stub_%+i ; save the address of each isr_stub_*
%assign i i+1
%endrep

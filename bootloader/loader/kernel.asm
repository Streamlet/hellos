org 0000    ; the standard bootloader load address
bits 16     ; 16-bit real mode

start:
    ; init segment registers
    mov ax, cs
    mov ds, ax
    mov ss, ax
    mov ax, 0xB800
    mov es, ax      ; set es to point to segment of video memory
    ; set stack pointer
    mov sp, 0x7C00
    jmp start_kernel

times 512 * 16 - ($ - $$) db 0 ; make the file at least 1 cluster (16 sectors)

start_kernel:
    mov si, msg     ; load address of msg into SI
    call print_string

; wait forever
halt:
    hlt         ; halt the CPU
jmp halt

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

; message string
msg db 'Hello, OS Kernel!', 0x0D, 0x0A, 0

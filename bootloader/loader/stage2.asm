org 0x8000  ; the standard bootloader load address
bits 16     ; 16-bit real mode

start:
    mov si, msg     ; load address of msg into SI
    call print_string

    ; wait forever
    .halt:
        hlt         ; halt the CPU
    jmp .halt

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
msg db 'Hello, Stage 2!', 0x0D, 0x0A, 0

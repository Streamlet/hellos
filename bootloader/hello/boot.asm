org 0x7C00  ; the standard bootloader load address
bits 16     ; 16-bit real mode

start:
    ; init segment registers
    mov ax, 0
    mov ds, ax
    mov ss, ax
    mov ax, 0xB800
    mov es, ax      ; set es to point to segment of video memory
    ; set stack pointer
    mov sp, 0x7C00

    call clean_screen
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

; function to clear screen
clean_screen:
    mov di, 0       ; now ES:DI points to the start of the screen (0xB800:0000)
    mov ax, 0x0720  ; 20h = space character, 07h = attribute (light grey on black)
    mov cx, 80 * 25 ; 80 cols * 25 rows = 2000 characters
    cld             ; clear direction flag
    rep stosw       ; stow: store AX at ES:DI, increment DI by 2
                    ; rep:  repeat CX times
    mov dx, 0       ; row 0, column 0
    call bios_set_cursor_pos ; set cursor position to (0,0)
    ret

; function to set cursor position
; inputs: row in DH, column in DL
bios_set_cursor_pos:
    mov ah, 0x02    ; bios teletype function to set cursor position
    mov bh, 0       ; page number
    int 0x10        ; call BIOS video interrupt
    ret

; message string
msg db 'Hello, OS!', 0x0D, 0x0A, 0

times 510 - ($ - $$) db 0 ; fill with 0 until the 510th byte
dw 0xAA55                 ; last two bytes are the boot signature

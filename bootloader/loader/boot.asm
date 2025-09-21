org 0x7C00  ; the standard bootloader load address
bits 16     ; 16-bit real mode

start:
    ; init segment registers
    mov ax, 0
    mov ds, ax
    mov ss, ax
    ; set stack pointer
    mov sp, 0x7C00

    call clean_screen
    mov si, msg_loading     ; load address of msg into SI
    call print_string

    mov si, lba_packet
    call bios_load_sector_lba
    jc .error
    jmp 0x0000:0x8000
    .error:
        mov si, msg_loading_error    ; load address of error message into SI
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
    mov ax, 0xB800
    mov es, ax      ; set es to point to segment of video memory
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

; function to load sectors from disk using LBA
; inputs: SI = pointer to LBA packet
bios_load_sector_lba:
    mov ah, 0x42    ; bios read sectors function (LBA)
    mov dl, 0x80    ; drive number (first hard disk)
    int 0x13        ; call BIOS disk interrupt
    ret

lba_packet:
    db 16         ; size of packet
    db 0          ; reserved
lba_packet_sectors:
    dw 7          ; number of sectors to read
lba_packet_buffer:
    dw 0x8000     ; offset of buffer
    dw 0          ; segment of buffer
lba_packet_lba:
    dd 1          ; low dword of starting LBA (set later)
    dd 0          ; high dword of starting LBA (set later)

; predefined strings
msg_loading db 'Welcome to HellOS!', 0x0D, 0x0A, 0x0D, 0x0A, 'Loading kernel...', 0x0D, 0x0A, 0
msg_loading_error db 'Error reading sectors. Disk too small?', 0x0D, 0x0A, 0
times 446 - ($ - $$) db 0 ; fill with 0 until the 446th byte

; boot loader code: 446 bytes
; partition table: 16 bytes each, 4 entries
; boot flag: 2 bytes
; total: 512 bytes
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
    mov si, msg_hello     ; load address of msg into SI
    call print_string
    call run_loop

run_loop:
    mov si, prompt         ; load address of prompt into SI
    call print_string      ; print prompt
    call read_line         ; read a line of input from keyboard
    mov si, buffer         ; load address of input buffer into SI
    mov di, cmd_shutdown   ; load address of cmd_shutdown into DI
    call strcmp            ; compare input string with cmd_shutdown
    jz .shutdown           ; if equal, jump to shutdown
    mov si, buffer         ; reload address of input buffer into SI
    mov di, cmd_reboot     ; load address of cmd_reboot into DI
    call strcmp            ; compare input string with cmd_reboot
    jz .reboot             ; if equal, jump to reboot
    mov si, msg_bad_cmd    ; load address of bad command message into SI
    call print_string      ; print bad command message
    mov si, buffer         ; load address of input buffer into SI
    call print_string      ; print the bad command
    mov al, 0x0D
    call print_char        ; print carriage return
    mov al, 0x0A
    call print_char        ; print line feed
    jmp run_loop           ; repeat the loop
    .shutdown:
        call bios_shutdown ; shutdown the system
        jmp .halt
    .reboot:
        call bios_reboot   ; reboot the system
        jmp .halt
    ; wait forever
    .halt:
        hlt         ; halt the CPU
    jmp .halt

; function to compare two null-terminated strings
; input: SI points to first string, DI points to second string
; output: ZF set if equal, clear if not equal
strcmp:
    .loop:
        mov al, [si]    ; load byte from first string
        mov bl, [di]    ; load byte from second string
        cmp al, bl      ; compare bytes
        jne .end        ; if not equal, jump to end
        cmp al, 0       ; check for null terminator
        je .end         ; if null terminator, strings are equal, jump to end
        inc si          ; move to next byte in first string
        inc di          ; move to next byte in second string
        jmp .loop       ; repeat comparison
    .end:
        ret

; function to read a line of input from the keyboard
; input: none
; output: buffer contains the input string, null-terminated
read_line:
    mov di, buffer          ; DI points to the start of the buffer
    .input_loop:
        call read_key       ; read a key from keyboard, result in AL
        cmp al, 0           ; check for non-ascii keys
        je .input_loop      ; ignore and read again
        call print_char     ; echo the character
        cmp al, 0x0D        ; check for Enter key (carriage return)
        je .done            ; if Enter, finish input
        cmp al, 0x08        ; check for Backspace key
        je .backspace       ; if Backspace, handle it
        ; store character in buffer
        mov [di], al
        inc di              ; increment character count
        jmp .input_loop      ; repeat for next character
    .backspace:
        cmp di, buffer      ; check if there's anything to backspace
        je .input_loop       ; if not, ignore backspace
        dec di               ; decrement character count
        mov al, ' '          ; overwrite with space
        call print_char      ; print space
        mov al, 0x08         ; move cursor back again
        call print_char      ; move cursor back
        jmp .input_loop      ; continue input loop
    .done:
        mov byte [di], 0     ; null-terminate the string at the correct position
        mov al, 0x0A
        call print_char      ; print newline
        ret

; function to read a key from the keyboard
; output: AL = ASCII code of the key pressed, AH = scan code
read_key:
    mov ah, 0x00    ; BIOS keyboard function to read a key
    int 0x16        ; call BIOS keyboard interrupt
    ret

; function to print a single character in AL at the current cursor position
; input: AL = character to print
print_char:
    mov ah, 0x0E    ; BIOS teletype function to print character in AL
    int 0x10        ; call BIOS video interrupt to print character in AL
    ret

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

; function to shutdown the system
bios_shutdown:
    mov ax, 0x5307  ; BIOS function to power off the system
    mov bx, 0x0001  ; power off
    mov cx, 0x0003  ; soft off
    int 0x15        ; call BIOS interrupt
    ret

; function to reboot the system
bios_reboot:
    mov ax, 0x0000  ; BIOS function to reboot the system
    int 0x19        ; call BIOS interrupt
    ret

; predefined strings
msg_hello db 'Hello, OS!', 0x0D, 0x0A, 'Supported commands: shutdown, reboot.', 0x0D, 0x0A, 0x0D, 0x0A, 0
msg_bad_cmd db 'Bad command: ', 0
prompt db '>', 0
cmd_shutdown db 'shutdown', 0
cmd_reboot db 'reboot', 0
buffer db 128 dup(0) ; buffer to hold input string, max 128 characters

times 510 - ($ - $$) db 0 ; fill with 0 until the 510th byte
dw 0xAA55                 ; last two bytes are the boot signature

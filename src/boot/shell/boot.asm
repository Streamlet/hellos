; A simple bootloader that prints "Hello, Shell!" to the screen and handles basic keyboard input.
; When KERNEL is defined, it becomes a simple kernel that prints "Kernel loaded!"

%ifdef KERNEL
org 0x0000  ; the kernel is loaded at 0x????:0x0000
%else
org 0x7C00  ; the standard bootloader load address
%endif
bits 16     ; 16-bit real mode

; initialization

start:
%ifndef KERNEL
    ; Some BIOSes load the bootloader with a non-zero segment, which can cause issues when accessing data with hardcoded offsets
    jmp 0x0000:init_registers   ; force cs to be 0; 
%endif

init_registers:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, start

; if KERNEL is defined, padding the file to 1 cluster (16 sectors) and jump to main
%ifdef KERNEL
jmp main
times 512 * 16 - ($ - $$) db 0 ; make the file at least 1 cluster (16 sectors)
%endif

; main routine

main:
%ifndef KERNEL
    call bios_clean_screen  ; clear the screen
    mov si, msg_hello       ; load hello message into SI
    call bios_print_string  ; print the hello message
%endif

cmd_loop:
    mov si, prompt          ; load prompt message into SI
    call bios_print_string  ; print prompt
    mov di, input_buffer    ; load input buffer into DI
    call read_line          ; read a line of input from keyboard

    mov si, input_buffer    ; load input buffer into SI
    mov di, cmd_shutdown    ; load cmd_shutdown into DI
    call strcmp             ; compare input string with cmd_shutdown
    jz bios_shutdown        ; if equal, jump to shutdown

    mov si, input_buffer    ; load input buffer into SI
    mov di, cmd_reboot      ; load cmd_reboot into DI
    call strcmp             ; compare input string with cmd_reboot
    jz bios_reboot          ; if equal, jump to reboot

    mov si, msg_bad_cmd     ; load bad command message into SI
    call bios_print_string  ; print bad command message
    jmp cmd_loop            ; repeat the loop


; functions
; caller-saved registers: AX, CX, DX
; callee-saved registers: The rests
; return value: AX (16-bit), DX:AX (32-bit)

; read a line of input from the keyboard
; input: DI=buffer
; output: buffer contains the input string, null-terminated
read_line:
    .input_loop:
        call bios_read_key  ; read a key from keyboard, result in AL
        test al, al         ; check for non-ascii keys
        je .input_loop      ; ignore and read again
        call bios_print_char; echo the character
        cmp al, 0x0D        ; check for CR (carriage return) character
        je .done            ; if Enter, finish input
        cmp al, 0x08        ; check for Backspace key
        je .backspace       ; if Backspace, handle it
        mov [di], al        ; store character in buffer
        inc di              ; increment character count
        jmp .input_loop     ; repeat for next character
    .backspace:
        cmp di, input_buffer; check if there's anything to backspace
        je .input_loop      ; if not, ignore backspace
        dec di              ; decrement character count
        mov al, ' '         ; load space character to AL
        call bios_print_char; print space to overwrite screen
        mov al, 0x08        ; load backspace character to AL
        call bios_print_char; print backspace to move cursor back
        jmp .input_loop     ; continue input loop
    .done:
        mov byte [di], 0    ; make the output string null-terminated
        mov al, 0x0A        ; load LF (line feed) character to AL
        call bios_print_char; print LF to move to next line
        ret

; compare two null-terminated strings
; input: SI points to first string, DI points to second string
; output: ZF set if equal, clear if not equal
strcmp:
    .loop:
        mov al, [si]        ; load byte from first string
        cmp al, [di]        ; compare bytes
        jne .end            ; if not equal, jump to end
        test al, al         ; check for null terminator
        je .end             ; if null terminator, strings are equal, jump to end
        inc si              ; move to next byte in first string
        inc di              ; move to next byte in second string
        jmp .loop           ; repeat comparison
    .end:   
        ret

; read a key from the keyboard
; output: AL = ASCII code of the key pressed, AH = scan code
bios_read_key:
    mov ah, 0x00    ; BIOS keyboard function to read a key
    int 0x16        ; call BIOS keyboard interrupt
    ret

; print a single character in AL at the current cursor position
; input: AL = character to print
bios_print_char:
    mov ah, 0x0E    ; BIOS teletype function to print character in AL
    int 0x10        ; call BIOS video interrupt to print character in AL
    ret


; print a null-terminated string at the current cursor position
; input: DS:SI points to the string
bios_print_string:
    mov ah, 0x0E    ; bios teletype function to print character in AL
    .loop:
        lodsb       ; AL = [DS:SI], SI++
        test al, al ; test for null terminator
        je .end     ; if zero, end of string, jump to end
        int 0x10    ; call BIOS video interrupt to print character in AL
        jmp .loop   ; repeat for next character
    .end:
        ret

; clean screen by resetting video mode
bios_clean_screen:
    mov ax, 0x0003  ; AH=00h, AL=03h (mode 3: 80x25 text), reset video mode to clear screen
    int 0x10
    ret

; shutdown the system
bios_shutdown:
    mov ax, 0x5307  ; BIOS function to power off the system
    mov bx, 0x0001  ; power off
    mov cx, 0x0003  ; soft off
    int 0x15        ; call BIOS interrupt

;  reboot the system
bios_reboot:
    mov ax, 0x0000  ; BIOS function to reboot the system
    int 0x19        ; call BIOS interrupt

; data

; strings
%ifndef KERNEL
msg_hello       db 'Hello, Shell!', 0x0D, 0x0A, 0x0D, 0x0A, 0
%endif
msg_bad_cmd     db 'Bad command.', 0x0D, 0x0A, 'Available commands: shutdown, reboot', 0x0D, 0x0A, 0
prompt          db '>', 0
cmd_shutdown    db 'shutdown', 0
cmd_reboot      db 'reboot', 0
input_buffer times 128 db 0 ; buffer to hold input string, max 128 characters

; padding and boot signature for bootloader
%ifndef KERNEL 
; padding
times 510 - ($ - $$) db 0
; boot signature (last two bytes must be 0xAA55)
dw 0xAA55
%endif

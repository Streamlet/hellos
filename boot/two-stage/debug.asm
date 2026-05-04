%ifndef __DEBUG_ASM_INCLUDED__
%define __DEBUG_ASM_INCLUDED__

%macro DEBUG_LOG 1
    push si
    mov si, %%debug_log_msg
    call debug_print_string
    pop si
    jmp %%debug_log_end
%%debug_log_msg db %1, 0x0D, 0x0A, 0
%%debug_log_end:
%endmacro

%macro DEBUG_REG 2
    push si
    push cx
    mov [%%debug_reg_buffer], %1
    mov si, %%debug_reg_buffer
    mov cl, %2
    call debug_print_buffer
    pop cx
    pop si
    jmp %%debug_reg_end
%%debug_reg_buffer db 0, 0, 0, 0
%%debug_reg_end:
%endmacro


jmp debug_end

; function to print a null-terminated string at the current cursor position
; input: DS:SI points to the string
debug_print_string:
    pushf
    pusha
    mov ah, 0x0E        ; bios teletype function to print character in AL
    .loop:
        lodsb           ; AL = [DS:SI], SI++
        test al, al     ; test for null terminator
        je .end         ; if zero, end of string, jump to halt
        int 0x10        ; call BIOS video interrupt to print character in AL
        jmp .loop       ; repeat for next character
    .end:
    popa
    popf
    ret

; 16 byte buffer for debug print
; input: SI=buffer, CL=number of bytes to print
debug_print_buffer:
    pushf
    pusha
    mov ah, 0x0E
    mov ch, cl
    .loop_bytes:
        mov cl, 4
        .loop_chars:
            mov al, [si]
            shr al, cl
            and al, 0x0F
            cmp al, 9
            ja .hex
            .digit:
                add al, '0'
                jmp .print
            .hex:
                add al, 'A' - 10
                jmp .print
            .print:
                int 0x10
                cmp cl, 0
                je .byte_done
                xor cl, cl
                jmp .loop_chars
        .byte_done:
            inc si
            dec ch
            jz .done
            mov al, ' '
            int 0x10
            jmp .loop_bytes
    .done:
        mov al, 0x0D
        int 0x10
        mov al, 0x0A
        int 0x10
    popa
    popf
    ret

debug_end:

%endif  ; __DEBUG_ASM_INCLUDED__

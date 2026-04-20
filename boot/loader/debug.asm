%macro DEBUG_PRINT 1
    mov [debug_buffer], %1
    call debug_print
%endmacro

jmp debug_print_end

; 16 byte buffer for debug print
debug_buffer times 16 db 0  ; Reserve 16 bytes for the debug buffer
debug_print:
    pusha
    mov ah, 0x0E
    mov ch, 16
    mov si, debug_buffer
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
                jz .byte_done
                xor cl, cl
                and al, 0x0F
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
        ret

debug_print_end:

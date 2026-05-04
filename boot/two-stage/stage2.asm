; stage2 bootloader

%include "layout.asm"

org STAGE2_ADDRESS  ; the stage2 bootloader load address
bits 16             ; 16-bit real mode

section .text

; initialization

start:
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, start

;%include "debug.asm"

; main routine

main:

    ; init fat filesystem
    mov si, STAGE1_ADDRESS + 0x1BE ; SI = address of partition entry in MBR
    call fat_init
    jc .fat_error

    ; find kernel file
    mov di, kernel_file_name
    call fat_find_file_in_root
    jc .fat_error

    ; check file size (must be less than 64K)
    mov si, ax
    mov ax, [si + fat_dir_entry.file_size] ; load file size
    mov dx, [si + fat_dir_entry.file_size + 2]
    cmp dx, 0
    jne .error_file_too_large
    cmp ax, 0x8000 ; compare with 32K
    ja .error_file_too_large

    ; load kernel file
    mov di, KERNEL_ADDRESS_SEGMENT
    mov es, di
    mov di, KERNEL_ADDRESS_OFFSET
    call fat_load_file
    jc .fat_error

    ; jump to kernel entry point
    jmp KERNEL_ADDRESS_SEGMENT:KERNEL_ADDRESS_OFFSET
    ; error handling
    .fat_error:
        cmp al, ERROR_NO_BOOT_PARTITION_FOUND
        je .error_no_boot_partition_found
        cmp al, ERROR_UNSUPPORTED_PARTITION
        je .error_unsupported_partition
        cmp al, ERROR_LOAD_VBR
        je .error_load_vbr
        cmp al, ERROR_LOAD_ROOT_DIR
        je .error_load_root_dir
        cmp al, ERROR_LOAD_FAT
        je .error_load_fat
        cmp al, ERROR_FILE_NOT_FOUND
        je .error_file_not_found
        cmp al, ERROR_LOAD_FILE
        je .error_load_file
    .error_no_boot_partition_found:
        mov si, msg_no_boot_partition_found
        jmp .print_error_and_halt
    .error_unsupported_partition:
        mov si, msg_unsupported_partition
        jmp .print_error_and_halt
    .error_load_vbr:
        mov si, msg_failed_to_load_vbr
        jmp .print_error_and_halt
    .error_load_root_dir:
        mov si, msg_failed_to_load_root_dir
        jmp .print_error_and_halt
    .error_load_fat:
        mov si, msg_failed_to_load_fat
        jmp .print_error_and_halt
    .error_file_not_found:
        mov si, msg_kernel_file_not_found
        jmp .print_error_and_halt
    .error_load_file:
        mov si, msg_failed_to_load_kernel_file
        jmp .print_error_and_halt
    .error_file_too_large:
        mov si, msg_kernel_file_too_large
        jmp .print_error_and_halt
    .print_error_and_halt:
        call bios_print_string
        jmp $ ; halt the system

; functions
; caller-saved registers: AX, CX, DX
; callee-saved registers: The rests
; return value: AX (16-bit), DX:AX (32-bit)

; function to print a null-terminated string at the current cursor position
; input: DS:SI points to the string
bios_print_string:
    mov ah, 0x0E        ; bios teletype function to print character in AL
    .loop:
        lodsb           ; AL = [DS:SI], SI++
        test al, al     ; test for null terminator
        je .end         ; if zero, end of string, jump to halt
        int 0x10        ; call BIOS video interrupt to print character in AL
        jmp .loop       ; repeat for next character
    .end:
        ret

%include "fat.asm"

; data
section .data

; strings
kernel_file_name db 'KERNEL  BIN ', 0 ; 11 bytes (8.3 format)
msg_no_boot_partition_found db 'Error: no bootable partition found.', 0x0D, 0x0A, 0
msg_unsupported_partition db 'Error: unsupported partition type.', 0x0D, 0x0A, 0
msg_failed_to_load_vbr db 'Error: failed to load VBR.', 0x0D, 0x0A, 0
msg_failed_to_load_root_dir db 'Error: failed to load root directory.', 0x0D, 0x0A, 0
msg_failed_to_load_fat db 'Error: failed to load fat.', 0x0D, 0x0A, 0
msg_kernel_file_not_found db 'Error: kernel file not found.', 0x0D, 0x0A, 0
msg_kernel_file_too_large db 'Error: kernel file larger than 32K.', 0x0D, 0x0A, 0
msg_failed_to_load_kernel_file db 'Error: failed to load kernel file.', 0x0D, 0x0A, 0

; FAT filesystem functions for stage2 bootloader
%ifndef __FAT_ASM_INCLUDED__
%define __FAT_ASM_INCLUDED__

%include "layout.asm"

section .text

;%include "debug.asm"

; functions
; caller-saved registers: AX, CX, DX
; callee-saved registers: The rests
; return value: AX (16-bit), DX:AX (32-bit)

ERROR_NO_BOOT_PARTITION_FOUND   equ 1
ERROR_UNSUPPORTED_PARTITION     equ 2
ERROR_LOAD_VBR                  equ 3
ERROR_LOAD_ROOT_DIR             equ 4
ERROR_LOAD_FAT                  equ 5
ERROR_FILE_NOT_FOUND            equ 6
ERROR_LOAD_FILE                 equ 7


; initialize FAT filesystem, find the bootable partition, load VBR and root directory
; inputs: SI = pointer to partition table (16 bytes * 4)
; outputs: global variables
;          CF set on error, clear if no error, AL = error code if CF=1
fat_init:
    push si
    call mbr_find_bootable_partition
    jc .error
    call mbr_check_partition_type
    jc .error
    call mbr_load_vbr
    jc .error
    call fat_calc_layout
    jc .error
    jmp .return
    .error:
    .return:
    pop si
    ret

; find the bootable partition in MBR
; inputs: SI = pointer to partition table (16 bytes * 4)
; outputs: fill MBR_PARTITION_TABLE_ADDRESS with the bootable partition entry
;          CF set on error, clear if no error
mbr_find_bootable_partition:
    push si
    mov cl, 4               ; 4 partition entries to check
    .next:
        mov al, [si + partition_entry.boot_indicator - partition_entry] ; load boot indicator byte
        cmp al, 0x80        ; check if bootable
        je .found
        add si, 16          ; move to next partition entry (16 bytes each)
        dec cl              ; decrement counter
        jnz .next
    .not_found:
        mov al, ERROR_NO_BOOT_PARTITION_FOUND
        stc                 ; set carry flag to indicate error
        jmp .return
    .found:
        ; copy the bootable partition entry to MBR_PARTITION_TABLE_ADDRESS
        cld                 ; clear direction flag for string operations
        push di
        mov di, partition_entry ; ES:DI = destination address
        mov cx, 16          ; copy 16 bytes of partition entry
        rep movsb           ; perform copy
        pop di
        jmp .return
    .return:
        pop si
        ret

; find the bootable partition in MBR
; inputs: none (use partition_entry.*)
; outputs: FAT_VARIABLES.fat_size = FAT size (12, 16, or 32)
;          FAT_VARIABLES.fat_double_entry_size = two FAT entries size in bytes (3 for FAT12, 4 for FAT16, 8 for FAT32)
;          CF set on error, clear if no error, AL = error code if CF=1
mbr_check_partition_type:
    clc
    xor ax, ax          ; clear AX
    mov al, [partition_entry.system_id]    ; load partition type byte
    cmp al, 0x01        ; check if FAT12 partition
    je .fat12
    cmp al, 0x04        ; check if FAT16 partition (< 65536 sectors)
    je .fat16
    cmp al, 0x06        ; check if FAT16B partition (>= 65536 sectors)
    je .fat16
    cmp al, 0x0B        ; check if FAT32 partition (CHS)
    je .fat32
    cmp al, 0x0C        ; check if FAT32 partition (LBA)
    je .fat32
    cmp al, 0x0E        ; check if FAT16B partition (LBA)
    je .fat16
    .error:
        mov al, ERROR_UNSUPPORTED_PARTITION
        stc
        ret
    .fat12:
        mov byte [fat_variables.fat_size], 12
        mov byte [fat_variables.fat_double_entry_size], 3
        ret
    .fat16:
        mov byte [fat_variables.fat_size], 16
        mov byte [fat_variables.fat_double_entry_size], 4
        ret
    .fat32:
        mov byte [fat_variables.fat_size], 32
        mov byte [fat_variables.fat_double_entry_size], 8
        ret

; load the bootable partition in MBR
; inputs: none (use global variables)
; outputs: fill VBR_BPB_ADDRESS with the BPB from the partition's VBR
;          CF set on error, clear if no error, AL = error code if CF=1
mbr_load_vbr:
    mov ax, [partition_entry.relative_sector + 2]
    push ax
    mov ax, [partition_entry.relative_sector]
    push ax
    push ds
    push fat_sectors_buffer
    push 1
    call bios_load_sector_lba
    jc .error
    .copy_bpb:
        ; copy the BPB from the loaded VBR to VBR_BPB_ADDRESS
        push si
        push di
        mov si, fat_sectors_buffer + 0x0b  ; SI = source address of loaded VBR
        cld                     ; clear direction flag for string operations
        mov di, bpb             ; ES:DI = destination address
        mov cx, bpb_end - bpb   ; copy BPB size
        rep movsb               ; perform copy
        pop di
        pop si
        ret
    .error:
        mov al, ERROR_LOAD_VBR
        ret

; calculate FAT layout based on the BPB and partition information
; inputs: none (use global variables)
; outputs: FAT_VARIABLES.fat_table_lba = starting LBA of FAT table
;          FAT_VARIABLES.fat_root_dir_lba = starting LBA of root directory
;          FAT_VARIABLES.fat_root_dir_sectors = number of sectors of root directory
;          FAT_VARIABLES.fat_data_lba = starting LBA of data region
fat_calc_layout:
    ; calulate FAT table LBA: partition starting LBA + reserved sectors
    mov ax, [partition_entry.relative_sector]   ; load partition starting LBA (4 bytes) into DX:AX
    mov dx, [partition_entry.relative_sector + 2]
    add ax, [bpb.reserved_sectors]              ; add reserved sectors
    adc dx, 0
    mov [fat_variables.fat_table_lba], ax       ; store FAT table starting LBA in global variable
    mov [fat_variables.fat_table_lba + 2], dx

    ; calculate root directory LBA and sectors
    mov [fat_variables.fat_root_dir_lba], ax    ; initially set root dir LBA to FAT table LBA, will add FAT size later
    mov [fat_variables.fat_root_dir_lba + 2], dx
    cmp byte [fat_variables.fat_size], 32
    je .fat32_sectors_per_fat
        mov ax, [bpb.sectors_per_fat_0]         ; load sectors per FAT for FAT12/16 into DX:AX
        xor dx, dx
        jmp .end_sectors_per_fat
    .fat32_sectors_per_fat:
        mov ax, [bpb.sectors_per_fat_1]         ; load sectors per FAT for FAT32 into DX:AX
        mov dx, [bpb.sectors_per_fat_1 + 2]
    .end_sectors_per_fat:
    mov cl, [bpb.number_of_fats]                ; CL = fats count
    .loop_number_of_fats:
        add [fat_variables.fat_root_dir_lba], ax; add FAT size in sectors to root dir LBA
        adc [fat_variables.fat_root_dir_lba + 2], dx
        dec cl
        jnz .loop_number_of_fats
    ; [fat_variables.fat_root_dir_lba] now is the starting LBA of root directory for FAT12/16, and starting LBA of data region for FAT32

    ; calculate data region LBA and root dir sectors
    cmp byte [fat_variables.fat_size], 32
    jz .fat32_layout
        mov ax, [bpb.root_entries]              ; AX = root dir entries
        mov cx, 32                              ; CX = fat dir entry size in bytes
        mul cx                                  ; DX:AX = root dir entries * 32 = root dir size in bytes
        mov cx, [bpb.bytes_per_sector]          ; CX = bytes per sector
        div cx                                  ; AX = number of sectors in root dir, DX = remainder
        neg dx                                  ; if DX != 0, 'neg dx' result to CF=1
        adc ax, 0                               ; add CF to sector count, AX = root dir sectors
        mov [fat_variables.fat_root_dir_sectors], ax    ; store root dir sectors in global variable
        xor dx, dx                              ; DX:AX = root dir sectors
        add ax, [fat_variables.fat_root_dir_lba]
        adc dx, [fat_variables.fat_root_dir_lba + 2]; DX:AX = root dir sectors + root dir LBA = data region LBA
        mov [fat_variables.fat_data_lba], ax
        mov [fat_variables.fat_data_lba + 2], dx; store data region LBA in root dir LBA variable for FAT12/16
        jmp .end_fat_layout
    .fat32_layout:
        mov ax, [fat_variables.fat_root_dir_lba]    ; load root dir LBA (which is data region LBA for FAT32) into DX:AX
        mov dx, [fat_variables.fat_root_dir_lba + 2]
        mov [fat_variables.fat_data_lba], ax        ; store data region LBA in global variable
        mov [fat_variables.fat_data_lba + 2], dx
        mov dword [fat_variables.fat_root_dir_lba], 0   ; FAT32 root directory has no fixed location, set to 0
        mov word [fat_variables.fat_root_dir_sectors], 0; FAT32 root directory has no fixed size, set to 0
    .end_fat_layout:
    ret


; find a file in the root directory
; inputs: DI = file name
; outputs: CF=0: AX = file entry address in buffer
;          CF=1: AL = error code, AL=0 if not found
fat_find_file_in_root:
    push bp
    mov bp, sp
    sub sp, 12
    cmp byte [fat_variables.fat_size], 32
    je .load_root_dir_fat32
        ; local variables:
        ; [bp-2]: rest sectors to load for root dir
        ; [bp-4]: current cluster LBA to load (low 16 bits)
        ; [bp-6]: current cluster LBA to load (high 16 bits)
        ; [bp-8]: current sectors to load or loaded
        mov cx, [fat_variables.fat_root_dir_sectors]
        mov [bp-2], cx
        mov ax, [fat_variables.fat_root_dir_lba]
        mov [bp-4], ax
        mov ax, [fat_variables.fat_root_dir_lba + 2]
        mov [bp-6], ax
        .load_root_dir_fat1x_chunk:
            ; calucate chunk size to load
            cmp cx, FAT_SECTORS_BUFFER_SIZE     ; compare if rest sectors > buffer size
            ja .load_full_buffer_for_fat1x
                mov dx, cx                      ; if rest sectors <= buffer size, DX = rest sectors
                jmp .end_calculate_load_size_for_fat1x
            .load_full_buffer_for_fat1x:
                mov dx, FAT_SECTORS_BUFFER_SIZE ; if rest sectors > buffer size, DX = buffer size
            .end_calculate_load_size_for_fat1x:
            mov [bp-8], dx                      ; store current load sectors in local variable

            ; load a chunk of root dir sectors into buffer
            mov ax, [bp-6]
            push ax
            mov ax, [bp-4]
            push ax
            push ds
            push fat_sectors_buffer
            push dx
            call bios_load_sector_lba
            jc .error_load_root_dir

            ; find file in the loaded root dir sectors
            push si
            mov si, fat_sectors_buffer  ; SI = root directory buffer
            mov cx, [bp-8]              ; set loop counter for loaded sectors
            call fat_find_file_in_dir   ; search the file in the loaded root dir chunk, AX = file entry address in buffer if found
            pop si
            jz .return                 ; if found, return with file cluster in DX:AX

            ; continue to load next chunk of root dir
            mov ax, [bp-8]  ; load current loaded sectors
            add [bp-4], ax  ; current cluster LBA increase by current loaded sectors
            adc word [bp-6], 0
            sub [bp-2], ax  ; rest sectors decrease by current loaded sectors
            mov cx, [bp-2]  ; set loop counter for loaded sectors
        jnz .load_root_dir_fat1x_chunk
        jmp .end_load_root_dir
    .load_root_dir_fat32:
        ; local variables:
        ; [bp-2]: rest sectors to load for root dir
        ; [bp-4]: current cluster number to load (low 16 bits)
        ; [bp-6]: current cluster number to load (high 16 bits)
        ; [bp-8]: current cluster LBA to load (low 16 bits)
        ; [bp-10]: current cluster LBA to load (high 16 bits)
        ; [bp-12]: current sectors to load or loaded
        movzx cx, byte [bpb.sectors_per_cluster]
        mov [bp-2], cx
        mov ax, [bpb.root_cluster]              ; load root cluster number into DX:AX
        mov [bp-4], ax
        mov ax, [bpb.root_cluster + 2]
        mov [bp-6], ax
        .load_root_dir_cluster:
            ; calculate starting LBA of the cluster to load
            mov ax, [bp-4]
            mov dx, [bp-6]  ; DX:AX = current cluster number to load
            call fat_cluster_to_lba ; convert cluster number to LBA, result in DX:AX
            mov [bp-8], ax  ; store current cluster LBA (low 16 bits) in local variable
            mov [bp-10], dx ; store current cluster LBA (high 16 bits) in local variable
            .load_root_dir_fat32_chunk:
                ; calucate chunk size to load
                cmp cx, FAT_SECTORS_BUFFER_SIZE     ; compare if rest sectors > buffer size
                ja .load_full_buffer_for_fat32
                    mov dx, cx                      ; if rest sectors <= buffer size, DX = rest sectors
                    jmp .end_calculate_load_size_for_fat32
                .load_full_buffer_for_fat32:
                    mov dx, FAT_SECTORS_BUFFER_SIZE ; if rest sectors > buffer size, DX = buffer size
                .end_calculate_load_size_for_fat32:
                mov [bp-12], dx                      ; store current load sectors in local variable

                ; load a chunk of root dir sectors into buffer
                mov ax, [bp-10]
                push ax
                mov ax, [bp-8]
                push ax
                push ds
                push fat_sectors_buffer
                push dx
                call bios_load_sector_lba
                jc .error_load_root_dir

                ; find file in the loaded root dir sectors
                push si
                mov si, fat_sectors_buffer  ; SI = root directory buffer
                mov cx, [bp-12]              ; set loop counter for loaded sectors
                call fat_find_file_in_dir   ; search the file in the loaded root dir chunk, AX = file entry address in buffer if found
                pop si
                jz .return                  ; if found, return with file cluster in DX:AX

                ; continue to load next chunk of root dir
                mov ax, [bp-12]  ; load current loaded sectors
                add [bp-8], ax  ; current cluster LBA increase by current loaded sectors
                adc word [bp-10], 0
                sub [bp-2], ax  ; rest sectors decrease by current loaded sectors
                mov cx, [bp-2]  ; set loop counter for loaded sectors
            jnz .load_root_dir_fat32_chunk
            mov ax, [bp-4]      ; load current cluster number
            mov dx, [bp-6]
            call find_next_cluster ; get next cluster number in DX:AX
            jc .error_find_next_cluster
                mov [bp-4], ax      ; store next cluster number
                mov [bp-6], dx
                call fat_cluster_to_lba ; convert next cluster to LBA, result in DX:AX
                mov [bp-8], ax      ; store next cluster LBA (low 16 bits)
                mov [bp-10], dx     ; store next cluster LBA (high 16 bits)
                movzx cx, byte [bpb.sectors_per_cluster]
                mov [bp-2], cx
                jmp .load_root_dir_cluster ; if no error, load next cluster
            .error_find_next_cluster:
                cmp al, 0
                jne .return
        jmp .end_load_root_dir
    .end_load_root_dir:
        mov al, ERROR_FILE_NOT_FOUND
        stc
        jmp .return
    .error_load_root_dir:
        mov al, ERROR_LOAD_ROOT_DIR
        stc
        jmp .return
    .return:
        mov sp, bp
        pop bp
        ret


; find a file in directory buffer
; inputs: SI = directory buffer, CX = buffer sectors, DI = file name
; outputs: ZF=0: not found, continue
;          ZF=1, CF=0: found, AX = file entry address in buffer
;          ZF=1, CF=1: error, AL = error code, AL=0 if end of directory (indicats not found)
fat_find_file_in_dir:
    push si
    mov ax, [bpb.bytes_per_sector]  ; load bytes per sector
    mul cx                          ; DX:AX = buffer size in bytes
    mov cx, 32
    div cx                          ; AX = number of directory entries in buffer (buffer size / 32)
    mov cx, ax                      ; set loop counter for directory entries
    .loop_entries:
        mov al, [si]        ; load first byte of entry
        cmp al, 0           ; check for end of directory
        je .end_of_directory
        cmp al, 0xE5        ; check for deleted entry
        je .next_entry
        mov ah, [si + 0x0B] ; load attribute byte
        cmp ah, 0x0f        ; check if it's a long file name entry
        je .next_entry
        and ah, 0x18        ; check if it's a volume label or directory
        jne .next_entry
        push si
        push di
        cmp al, 0x05
        jne .compare_filename
        mov byte [si], 0xE5 ; treat 0x05 as 0xE5 for comparison
        .compare_filename:
        push cx
        mov cx, 11      ; compare 11 bytes (8.3 format)
        call strncmp
        pop cx
        pop di
        pop si
        jnz .next_entry ; if not equal, skip to next entry
        ; found
        mov ax, si      ; return file entry address in AX
        jmp .found
    .next_entry:
        add si, 32          ; move to next entry (32 bytes each)
        loop .loop_entries
    .not_found_continue:
        ; ZF=0: not found, continue
        cmp cx, 1
        jmp .return
    .found:
        ; ZF=1, CF=0: found
        cmp ax, ax
        clc
        jmp .return
    .end_of_directory:
        ; ZF=1, CF=1: error, AL = error code
        cmp ax, ax
        mov al, 0           ; file not found, set AL=0
        stc
    .return:
        pop si
        ret


; load a file given its starting cluster
; inputs: SI = file entry, ES:DI = destination buffer
; outputs: CF set on error, clear if no error, AL = error code if CF=1
fat_load_file:
    push bp
    mov bp, sp
    sub sp, 4
    ; local variables:
    ; [bp-2]: current cluster number (low 16 bits)
    ; [bp-4]: current cluster number (high 16 bits)
    mov ax, [si + fat_dir_entry.low_cluster] ; load starting cluster number into DX:AX
    mov [bp-2], ax
    cmp byte [fat_variables.fat_size], 32
    mov ax, 0
    jne .skip_fat32_high_bits
    mov ax, [si + fat_dir_entry.high_cluster]
    .skip_fat32_high_bits:
    mov [bp-4], ax
    push es
    push di
    .loop_clusters:
        ; calculate starting LBA: data_lba + (cluster - 2) * sectors_per_cluster
        mov ax, [bp-2]
        mov dx, [bp-4]  ; DX:AX = current cluster number
        call fat_cluster_to_lba ; convert cluster number to LBA, result in DX:AX
        push dx
        push ax
        push es
        push di
        movzx cx, byte [bpb.sectors_per_cluster]
        push cx
        call bios_load_sector_lba
        jc .error_load_data_sector

        ; increment to ES:DI to point to next free space for next cluster
        mov ax, [bpb.bytes_per_sector]
        movzx cx, byte [bpb.sectors_per_cluster]
        mul cx      ; DX:AX = bytes_per_sector * sectors_per_cluster = bytes to advance
        add di, ax  ; advance DI by cluster size in bytes (low 16 bits), dx stores the high 16 bits
        adc dx, 0   ; add carry to high 16 bits
        shl dx, 12  ; shift high 16 bits to the segment address, 1 segment = 16 bytes = 2^4 bytes, so shift left by 12 to convert from 2^16 bytes to segments (2^4 bytes)
        mov ax, es
        add ax, dx
        mov es, ax  ; update ES to new segment after adding high 16 bits of byte offset

        ; set SI to next cluster
        mov ax, [bp-2]
        mov dx, [bp-4]
        call find_next_cluster
        mov [bp-2], ax
        mov [bp-4], dx
        jnc .loop_clusters  ; if no error, load next cluster
        cmp al, 0
        jne .error_find_next_cluster
        clc
        jmp .return
    .error_load_data_sector:
        mov al, ERROR_LOAD_FILE
    .error_find_next_cluster:
        stc
        jmp .return
    .return:
        pop di
        pop es
        mov sp, bp
        pop bp
        ret

; calculate the LBA of a given cluster number, LBA=data_lba + (cluster - 2) * sectors_per_cluster
; inputs: DX:AX = cluster number
; outputs: DX:AX = starting LBA of the cluster
fat_cluster_to_lba:
    sub ax, 2                               ; cluster number starts from 2, so subtract 2 to get the zero-based cluster index
    sbb dx, 0
    movzx cx, byte [bpb.sectors_per_cluster]; CL = sectors per cluster
    mul cx                                  ; DX:AX = (cluster - 2) * sectors_per_cluster = offset in sectors
    add ax, [fat_variables.fat_data_lba]
    adc dx, [fat_variables.fat_data_lba + 2]; DX:AX = starting LBA of the cluster
    ret


; find the next cluster in FAT
; inputs: DX:AX = current cluster number
; outputs: CF=0: DX:AX = next cluster number
;          CF=1: AL = error code, AL=0 if end of cluster chain
find_next_cluster:
    push bp
    mov bp, sp
    sub sp, 2
    ; local variables:
    ; [bp-2]: current cluster number
    mov [bp-2], ax
    ; FAT entry address: fat_table_lba + cluster * fat_item_bytes / bytes_per_sector
    movzx cx, byte [fat_variables.fat_double_entry_size]
    push bx
    push ax
    mov ax, dx
    mul cx
    mov bx, ax
    pop ax
    mul cx
    add dx, bx                  ; DX:AX = cluster * fat_item_bytes * 2
    pop bx
    shr dx, 1
    rcr ax, 1                   ; DX:AX = cluster * bytes_per_items
    mov cx, [bpb.bytes_per_sector]  ; load bytes per sector
    div cx                      ; AX = cluster * bytes_per_items / bytes_per_sector, DX = byte offset
    push dx
    xor dx, dx
    add ax, [fat_variables.fat_table_lba]
    adc dx, [fat_variables.fat_table_lba + 2]   ; DX:AX = next FAT entry address in LBA
    push dx
    push ax                     ; Starting LBA
    push ds                      ; Segment of output buffer
    push fat_sectors_buffer     ; Offset of output buffer
    push 2                      ; Number of sectors to read
    call bios_load_sector_lba
    jc .error_load_fat
    pop dx                      ; DX = byte offset
    push bx
    mov bx, fat_sectors_buffer
    add bx, dx
    mov ax, [bx]
    xor dx, dx
    cmp byte [fat_variables.fat_size], 32
    jne .fat1x_skip_high_bits
        mov dx, [bx + 2]
        and dx, 0x0FFF          ; mask to get 12-bit FAT entry for FAT32
    .fat1x_skip_high_bits:
    pop bx
    cmp byte [fat_variables.fat_size], 12
    jnz .fat_16_check_end_of_chain
        test byte [bp-2], 1 ; check if cluster number is odd or even
        jz .even
        .odd:
            shr ax, 4       ; odd cluster, get high 12 bits
        .even:
            and ax, 0x0FFF  ; mask to get 12-bit FAT entry
        cmp ax, 0x0FF8      ; check for end-of-chain markers
        jb .found_next_cluster
        jmp .end_of_fat_chain
    .fat_16_check_end_of_chain:
        cmp ax, 0xFFF8      ; check for end-of-chain markers
        jb .found_next_cluster
        cmp byte [fat_variables.fat_size], 16
        jne .fat_32_check_end_of_chain
        jmp .end_of_fat_chain
    .fat_32_check_end_of_chain:
        cmp dx, 0x0FFF      ; check for end-of-chain markers
        jne .found_next_cluster         ; if not end of chain, load next cluster
        jmp .end_of_fat_chain
    .found_next_cluster:
        clc
        jmp .return
    .end_of_fat_chain:
        mov al, 0
        stc
        jmp .return
    .error_load_fat:
        mov al, ERROR_LOAD_FAT
        stc
        jmp .return
    .return:
        mov sp, bp
        pop bp
        ret


; function to load sectors from disk using LBA
; inputs: stack
;   dw 0  : number of sectors to read
;   dw 0  : offset of output buffer
;   dw 0  : segment of output buffer
;   dw 0  : starting LBA, 0-15 bits
;   dw 0  :               16-31 bits
; output: CF is set on error, clear if no error
bios_load_sector_lba:
    push bp
    mov bp, sp
    mov byte [lba_packet.packet_size], 16
    mov byte [lba_packet.reserved], 0
    mov ax, [bp+4]      ; number of sectors to read
    mov word [lba_packet.sector_count], ax
    mov ax, [bp+6]      ; offset of output buffer
    mov word [lba_packet.buffer_offset], ax
    mov ax, [bp+8]      ; segment of output buffer
    mov word [lba_packet.buffer_segment], ax
    mov ax, [bp+10]      ; starting LBA low 16 bits
    mov word [lba_packet.lba_low], ax
    mov ax, [bp+12]     ; starting LBA high 16 bits
    mov word [lba_packet.lba_low + 2], ax
    mov dword [lba_packet.lba_high], 0
    push si
    mov si, lba_packet
    mov ah, 0x42    ; bios read sectors function (LBA)
    mov dl, 0x80    ; drive number (first hard disk)
    int 0x13        ; call BIOS disk interrupt
    pop si
    pop bp
    ret 10

; function to compare two null-terminated strings
; input: SI points to full string, DI points to prefix string, CX = length of the part to compare
; output: ZF set if equal, clear if not equal
strncmp:
    push si
    push di
    .loop:
        test cx, cx
        je .end         ; if length is zero, strings are equal, jump to end
        mov al, [si]    ; load byte from first string
        cmp al, [di]    ; compare bytes
        jne .end        ; if not equal, jump to end
        inc si          ; move to next byte in first string
        inc di          ; move to next byte in second string
        dec cx          ; decrement length
        jmp .loop       ; repeat comparison
    .end:
        pop di
        pop si
        ret

; data
section .bss

lba_packet:
    .packet_size                resb 1
    .reserved                   resb 1
    .sector_count               resw 1
    .buffer_offset              resw 1
    .buffer_segment             resw 1
    .lba_low                    resd 1
    .lba_high                   resd 1

partition_entry:
    .boot_indicator             resb 1
    .starting_head              resb 1
    .starting_sector_cylinder   resw 1
    .system_id                  resb 1
    .ending_head                resb 1
    .ending_sector_cylinder     resw 1
    .relative_sector            resd 1
    .total_sectors              resd 1
partition_entry_end:

bpb:
    .bytes_per_sector           resw 1
    .sectors_per_cluster        resb 1
    .reserved_sectors           resw 1
    .number_of_fats             resb 1
    .root_entries               resw 1
    .total_sectors              resw 1
    .media                      resb 1
    .sectors_per_fat_0          resw 1
    .sectors_per_track          resw 1
    .heads_per_cylinder         resw 1
    .hidden_sectors             resd 1
    .total_sectors_big          resd 1
    .sectors_per_fat_1          resd 1
    .flags                      resw 1
    .version                    resw 1
    .root_cluster               resd 1
    .info_sector                resw 1
    .boot_backup_start          resw 1
    .reserved                   resb 12
bpb_end:

; fat globals variables
fat_variables:
    .fat_size                   resb 1  ; FAT size, 12, 16 or 32
    .fat_double_entry_size      resb 1  ; two FAT entries size in bytes, 3 for FAT12, 4 for FAT16 and 8 for FAT32
    .fat_table_lba              resd 1  ; starting LBA of FAT table
    .fat_root_dir_lba           resd 1  ; starting LBA of root directory
    .fat_root_dir_sectors       resw 1  ; number of sectors of root directory
    .fat_data_lba               resd 1  ; starting LBA of data region
fat_variables_end:

FAT_SECTORS_BUFFER_SIZE         equ 4   ; number of sectors that can be loaded into fat_sectors_buffer
fat_sectors_buffer              resb 512 * FAT_SECTORS_BUFFER_SIZE  ; buffer for loading FAT sectors

struc fat_dir_entry
    .name                       resb 8 ; 8 bytes for file name
    .extention                  resb 3 ; 3 bytes for file extension
    .attribute                  resb 1 ; file attribute byte
    .reserved                   resb 1 ; reserved
    .create_time_10ms           resb 1 ; creation time in 10ms units
    .create_time                resw 1 ; 16-bit time
    .create_date                resw 1 ; 16-bit date
    .access_date                resw 1 ; 16-bit date of last access
    .high_cluster               resw 1 ; high 16 bits of starting cluster
    .update_time                resw 1 ; 16-bit time of last update
    .update_date                resw 1 ; 16-bit date of last update
    .low_cluster                resw 1 ; low 16 bits of starting cluster
    .file_size                  resd 1 ; 32-bit file size
endstruc

%endif  ; __FAT_ASM_INCLUDED__

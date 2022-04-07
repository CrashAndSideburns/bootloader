ORG 0x7C00
SECTION .text
USE16
stage1:
    ; Zero all segment registers.
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Set up stack.
    mov sp, stage1

    ; Enforce CS:IP in case the BIOS loads the bootloader to 0x07C0:0x0000.
    jmp 0x0:.enforce_csip
.enforce_csip:

    ; Print welcome message.
    mov si, boot_message
    call print

    ; Error if the boot disk does not support INT 13h extensions.
    mov ah, 0x41
    mov bx, 0x55AA
    int 0x13
    jc no_extensions_error

    ; Identify the bootable partition.
    mov bx, partition_table
    mov cx, 4
.loop:
    mov byte al, [bx]
    cmp al, 0x80
    je .bootable_partition_found
    add bx, 0x10
    loop .loop
    jmp stage2_load_error
.bootable_partition_found:

    ; Load bootable partition Boot Record.
    add bx, 0x08
    mov eax, [bx]
    mov [data_address_packet.address], eax
    mov ah, 0x42
    mov si, data_address_packet
    int 0x13
    jc stage2_load_error

    ; Locate and load C:/boot/bootloader.bin.
    ; TODO

    ; Jump to stage 2.
    ; TODO

    jmp halt

no_extensions_error:
    mov si, no_extensions_error_message
    call print
    jmp halt

stage2_load_error:
    mov si, stage2_load_error_message
    call print
    jmp halt

halt:
    hlt
    jmp halt

; Print a string.
; IN
;   si: pointer to null-terminated string to be printed
; CLOBBER
;   ax, si
print:
    pushf
    cld
.loop:
    lodsb
    cmp al, 0
    je .return
    call print_char
    jmp .loop
.return:
    popf
    ret

; Print a character.
; IN
;   al: character to be printed
print_char:
    pusha
    xor bx, bx
    mov ah, 0x0E
    int 0x10
    popa
    ret

data_address_packet:
    db 0x10
    db 0
.count:
    dw 1
.offset:
    dw boot_record
.segment:
    dw 0
.address:
    dq 0

boot_message: db "Bootloader - Stage One", 0
no_extensions_error_message: db "Error: Disk does not support INT 13h extensions.", 0
stage2_load_error_message: db "Error: Failed to load Stage Two.", 0

times 446-($-$$) db 0
partition_table: times 4 * 16 db 0
db 0x55
db 0xAA

boot_record:

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
    ; TODO

    ; Load bootable partition Boot Record and FAT.
    ; TODO

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

boot_message: db "Bootloader - Stage One", 0
no_extensions_error_message: db "Disk does not support INT 13h extensions. Unable to boot.", 0
stage2_load_error_message: db "Failed to load Stage Two. Unable to boot.", 0

times 446-($-$$) db 0
partition_table: times 4 * 16 db 0
db 0x55
db 0xAA

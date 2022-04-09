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

    ; Store the disk number.
    mov [disk], dl

    ; Error if the boot disk does not support INT 13h extensions.
    mov ah, 0x41
    mov bx, 0x55AA
    int 0x13

    ; Identify the bootable partition.
    mov bx, partition_table
    mov cx, 4
.loop:
    mov byte al, [bx]
    cmp al, 0x80
    je .bootable_partition_found
    add bx, 0x10
    loop .loop
.bootable_partition_found:

    ; Load bootable partition Boot Record.
    add bx, 0x08
    mov eax, [bx]
    mov [data_address_packet.address], eax
    mov ah, 0x42
    mov si, data_address_packet
    int 0x13

    ; Load first cluster of / into memory.
    mov eax, [boot_record.root_cluster]
    mov si, file
    call load_cluster

halt:
    hlt
    jmp halt

; load a cluster into memory
; IN
;   eax: cluster address
;   si:  address at which to load cluster
load_cluster:
    pusha

    movzx bx, [boot_record.cluster_size]
    mov [data_address_packet.count], bx

    mov [data_address_packet.offset], si

    mov ebx, [boot_record.hidden_sector_count]
    add bx, [boot_record.reserved_sector_count]
    movzx cx, [boot_record.fat_count]
.loop:
    add ebx, [boot_record.fat_size]
    loop .loop
    mov [data_address_packet.address], ebx

    mov ah, 0x42
    mov si, data_address_packet
    mov dl, [disk]
    int 0x13

    popa
    ret

disk: db 0

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

boot_dir_name: db "boot       "
boot_bin_name: db "boot    bin"

times 446-($-$$) db 0
partition_table: times 4 * 16 db 0
db 0x55
db 0xAA

SECTION .bss
boot_record:
    resb 3
    resb 8
    resb 2
.cluster_size:
    resb 1
.reserved_sector_count:
    resb 2
.fat_count:
    resb 1
    resb 2
    resb 2
    resb 1
    resb 2
    resb 2
    resb 2
.hidden_sector_count:
    resb 4
    resb 4
.fat_size:
    resb 4
    resb 2
    resb 2
.root_cluster:
    resb 4
    resb 2
    resb 2
    resb 12
    resb 1
    resb 1
    resb 1
    resb 4
    resb 11
    resb 8
    resb 420
    resb 2
fat:
    resb 512
file:

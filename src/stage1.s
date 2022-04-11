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

    ; Store the disk number in case dx is clobbered.
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

    ; Store the address at which the loaded cluster ends.
    movzx ax, [boot_record.cluster_size]
    shl ax, 9
    add [cluster_end], ax

    ; Locate /boot/boot.bin
    mov eax, [boot_record.root_cluster]
    mov di, boot_dir_name
    call find_file
    mov di, boot_bin_name
    call find_file

    ; Load the contents of /boot/boot.bin to 0x7E00 and jump to it.
    mov si, stage2
.load_stage2_cluster:
    cmp eax, 0x0FFFFFF8
    jae stage2
    call load_cluster
    call next_cluster
    add si, [boot_record.cluster_size]
    jmp .load_stage2_cluster

halt:
    hlt
    jmp halt

; load a cluster into memory
; IN
;   eax: cluster address
;   si:  address at which to load cluster
load_cluster:
    pusha

    ; Load a single cluster's worth of sectors.
    movzx bx, [boot_record.cluster_size]
    mov [data_address_packet.count], bx

    ; Load to si.
    mov [data_address_packet.offset], si

    ; The LBA address of the first sector of a cluster is given by:
    ; hidden_sector_count + reserved_sector_count + (fat_count * fat_size) + ((cluster_address - 2) * cluster_size)
    mov ebx, [boot_record.hidden_sector_count]
    add bx, [boot_record.reserved_sector_count]
    movzx cx, [boot_record.fat_count]
.fat_loop:
    add ebx, [boot_record.fat_size]
    loop .fat_loop
    sub eax, 2
    movzx cx, [boot_record.cluster_size]
.cluster_loop:
    add ebx, eax
    loop .cluster_loop
    mov [data_address_packet.address], ebx

    ; Load the appropriate sectors from the disk.
    mov ah, 0x42
    mov si, data_address_packet
    mov dl, [disk]
    int 0x13

    popa
    ret

; find the address of the next cluster in a cluster chain
; IN
;   eax: current cluster address
; OUT
;   eax: subsequent cluster address
; CLOBBERS
;   TODO
next_cluster:
    ; Load 1 sector into the region allocated for FAT sectors.
    mov word [data_address_packet.offset], fat
    mov word [data_address_packet.count], 1

    ; The sector of the FAT containing the relevant entry is given by:
    ; (cluster_address * 4) / 512
    ; This is not simplified to cluster_address / 128 due to the fact that
    ; cluster_address * 4 is also needed to index the loaded sector.
    shl eax, 2
    pusha
    shr eax, 9
    add eax, [boot_record.hidden_sector_count]
    add ax, [boot_record.reserved_sector_count]
    mov [data_address_packet.address], eax

    ; Load the appropriate sector from the disk.
    mov ah, 0x42
    mov si, data_address_packet
    mov dl, [disk]
    int 0x13
    popa

    ; The index of the relevant entry in this sector of the FAT is given by:
    ; (cluster_address * 4) % 512
    ; A bitwise AND may seem like an odd way to compute the modulus, but it
    ; works due to the fact that 2^n is congruent to 0 mod 512 for all n >= 9.
    ; As such, the 9 lowest bits can be taken as the modulus.
    and ax, 0x01FF
    mov si, ax

    ; Load the value in the relevant entry of the FAT into eax.
    mov eax, [si + fat]
    ret

; locate a file in a directory
; IN
;   eax: cluster address of first cluster of directory
;   di:  name of the file to search for
; OUT
;   eax: cluster address of first cluster of requested file
; CLOBBERS
;   TODO
find_file:
    ; Load the first cluster of the directory.
    mov si, cluster
    call load_cluster

.loop:
    ; Check if we have exhausted the current cluster.
    cmp si, [cluster_end]
    je .exhausted_cluster

    ; Check if we have exhausted all entries in the directory.
    cmp byte [si], 0x00
    je halt

    ; Check if the next entry is unused.
    cmp byte [si], 0xE5
    je .next_entry

    ; Check if the current entry has a long file name entry.
    ; These should not be skipped in general, but neither /boot nor
    ; /boot/boot.bin are long enough names to have long file name entries.
    cmp byte [si + 11], 0x0F
    je .skip_long_file_name

    ; Check if the current entry is the file being searched for.
    mov cx, 11
    repe cmpsb
    je .file_found
    add si, cx
    add di, cx
    sub si, 11
    sub di, 11
    jmp .next_entry

.skip_long_file_name:
    add si, 0x20

.next_entry:
    add si, 0x20
    jmp .loop

.file_found:
    ; Load the address of the first cluster of the file into eax and return.
    mov ax, [si + 9]
    shl eax, 16
    mov ax, [si + 15]

    ret

.exhausted_cluster:
    ; Find the address of the next cluster and, if it exists, keep searching.
    call next_cluster
    cmp eax, 0x0FFFFFF8
    jae halt
    call load_cluster
    jmp find_file

; Drive number, stored in case dx is clobbered.
disk: db 0

; Address of the end of the loaded cluster, since cluster lengths are variable.
cluster_end: dw cluster

; Data Address Packet used for calls to INT 13h.
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

; File names for the /boot directory and the /boot/boot.bin file.
boot_dir_name: db "BOOT       "
boot_bin_name: db "BOOT    BIN"

; Padding to ensure that the MBR is 512 bytes long.
times 446-($-$$) db 0

; The location of the partition table.
partition_table: times 4 * 16 db 0

; Bootable signature.
db 0x55
db 0xAA


; Some labels to make accessing the currently loaded portion of the FAT, the
; currently loaded cluster, and the fields of the VBR easier. Stage 2 of the
; bootloader is loaded in at 0x8200.
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
stage2:
cluster:

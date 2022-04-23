ORG 0x8200
SECTION .text
USE16
stage2:
    ; Check if the A20 line is already enabled.
    call check_a20
    cmp ax, 1
    je .a20_enabled

    ; Attempt to enable the A20 line using INT 15h.
    mov ax, 0x2401
    int 0x15
    call check_a20
    cmp ax, 1
    je .a20_enabled

    ; TODO
    ; Attempt to enable the A20 line using the keyboard controller and fast A20
    ; methods.

    ; Unable to enable the A20 line.
    jmp halt

.a20_enabled:
    ; Load the GDT
    lgdt [gdtr]

halt:
    hlt
    jmp halt

; check if the A20 line is enabled
; OUT
;   ax: 0 if the A20 line is disabled, 1 if it is enabled
check_a20:
    push ds
    push di
    push ss
    push si

    mov ax, 0x0000
    mov ds, ax
    mov di, 0x7DFE
    mov ax, 0xFFFF
    mov ss, ax
    mov si, 0x7E0E

    ; The boot signature (0x55AA) is located at 0x0000:0x7DFE. If 0xFFFF:0x7E0E
    ; contains a different value, the A20 line must be enabled.
    cmp word [ss:si], 0x55AA
    jne .a20_enabled

    ; It is still possible that the A20 line is enabled and 0x0000:0x7DFE just
    ; happens to contain 0x55AA. Just in case this is the case, we overwrite
    ; the value at 0x0000:0x7DFE and check if 0x0000:0x7DFE still contains the
    ; boot signature. If it does, the A20 line must still be enabled.
    mov word [ss:si], 0
    cmp word [ds:di], 0x55AA
    mov word [ss:si], 0x55AA
    je .a20_enabled

    mov ax, 0
    jmp .return

.a20_enabled:
    mov ax, 1

.return:
    pop si
    pop ss
    pop di
    pop ds

    ret

gdtr:
.limit:
    dw gdt.end
.base:
    dd gdt

; The Global Descriptor Table.
gdt:
.null_descriptor:
    dq 0
.kernel_mode_code_segment:
    dq 0x00_A_F_9A_00_0000_FFFF
.kernel_mode_data_segment:
    dq 0x00_C_F_92_00_0000_FFFF
.user_mode_code_segment:
    dq 0x00_A_F_FA_00_0000_FFFF
.user_mode_data_segment:
    dq 0x00_C_F_F2_00_0000_FFFF
.task_state_segment:
    ; TODO
    ; Add appropriate TSS.
.end:

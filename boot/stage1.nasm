[org 0x7C00]

[bits 16]
jmp start

%include "boot/print16.nasm"
; %include "gdt.nasm"
; --------------------
start:
    ; Set text mode 80x25 color
    mov ax, 0x03
    int 0x10

    ; Stack/Data reset
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7BFE    ; Stack grows down from bootloader
    sti

    ; Save boot drive address
    mov [boot_drive], dl

    call enable_a20_fast

    ; Print 'Loading...'
    mov si, msg
    call print16

    ; --------------------
    ; Check drive type
    ; --------------------
    mov al, [boot_drive]   ; load boot drive into AL
    cmp al, 0x80           ; compare with 0x80 (HDD)
    je from_hdd            ; jump if equal
    cmp al, 0x00           ; compare with 0x00 (floppy)
    je from_floppy         ; jump if equal

    jmp unknown_drive

stage2_start_marker:
    db "B"  ; Marker byte

from_hdd:
    ; code for HDD boot here
    jmp continue_boot

from_floppy:
    mov ah, 0x00
    mov dl, 0x00
    int 0x13

    jmp continue_boot

unknown_drive:
    mov si, msg_unknown
    call print16
    jmp hang

continue_boot:
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [boot_drive]
    int 0x13
    ; jc no_lba_support
    ; cmp bx, 0xAA55
    ; jne no_lba_support

    ; Print LBA support confirmed
    ; mov si, msg_lba_ok
    ; call print16
    ; ----------------------------------------------------
    ; Load Stage2 to 0x0800:0x0000 (0x8000 phys)
    ; ----------------------------------------------------
    mov si, dap_stage2
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    jc stage2_error

    ; Print Stage 2 loaded successfully
    mov si, msg_stage2_ok
    call print16
    ; ----------------------------------------------------
    ; Load Kernel to 0x100000 (1MB)
    ; ----------------------------------------------------
    mov si, dap_kernel
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    jc kernel_error

    ; Print kernel loaded successfully
    mov si, msg_kernel_ok
    call print16

    ; Success - jump to Stage 2
    mov si, msg_jumping
    call print16

    jmp 0x0800:0x0000

no_lba_support:
    mov si, msg_no_lba
    call print16
    jmp hang

stage2_error:
    mov si, msg_stage2_err
    call print16
    mov al, ah            ; BIOS error code is in AH after int 0x13
    call print_hex8
    jmp hang

kernel_error:
    mov si, msg_kernel_ok
    call print16
    jmp hang

disk_error:
    mov si, msg_disk_err
    call print16          ; print the text first

    mov al, ah            ; BIOS error code is in AH after int 0x13
    call print_hex8       ; print it in hex
    jmp $

; ------------------------------- A20 enable ---------------------------------
; Fast A20 via port 0x92 (System Control Port A)
enable_a20_fast:
    in al, 0x92
    or al, 00000010b    ; Set bit 1 (A20 enable)
    and al, 11111101b   ; Clear bit 2 (don't reset CPU)
    out 0x92, al
    ret
; --------------------
hang:
    jmp hang

; Disk Address Packet (DAP)
dap_stage2:
    db 0x10
    db 0
    dw 4                  ; sectors to read
    dw 0x0000             ; offset
    dw 0x0800             ; segment
    dd 1, 0               ; LBA (64-bit, little endian)

dap_kernel:
    db 0x10
    db 0  
    dw 128                  ; sectors to read (adjust as needed) 512 bytes each
    dw 0x0000             ; offset
    dw 0x5000            ; segment
    dd 5, 0               ; LBA (64-bit, little endian)

; Messages
msg db "Stage 1: Loading...", 13, 10, 0
msg_disk_err db "Disk load error!", 0
msg_lba_ok db "LBA support OK", 13, 10, 0
msg_stage2_ok db "Stage 2 loaded", 13, 10, 0
msg_kernel_ok db "Kernel loaded", 13, 10, 0
msg_jumping db "Jumping to Stage 2...", 13, 10, 0
msg_stage2_err db "Stage 2 load error: ", 0
msg_kernel_err db "Kernel load error: ", 0
msg_unknown db "Unknown boot device!", 13, 10, 0
msg_no_lba db "No LBA support!", 13, 10, 0
msg_byte_is db "First byte is: ", 0
boot_drive: db 0x80

times 510-($-$$) db 0
dw 0xAA55
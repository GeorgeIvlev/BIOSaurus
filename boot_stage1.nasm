org 0x7C00

bits 16

jmp start

%include "print16.nasm"
; %include "gdt.nasm"

; --------------------
; GDT for PM (unused right now)
gdt_start:
    dq 0x0000000000000000
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEL equ 0x08
DATA_SEL equ 0x10

start:
    ; Clear screen
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    ; vga=0x365 - 1920x1080 8-bit color
    ; vga=0x366 - 1920x1080 16-bit color
    ; vga=0x367 - 1920x1080 32-bit color

    mov eax, 0x0000          ; DS is 0x0000 in your setup
    mov ax, cs               ; Get code segment
    shl eax, 4               ; Convert to physical address
    add eax, gdt_start       ; Add GDT offset
    mov [gdt_descriptor + 2], eax

    lgdt [gdt_descriptor]

    ; Stack/Data reset
    cli
    mov ax, 0x0000
    mov ss, ax
    mov sp, 0x8000
    sti

    ; Save boot drive address
    mov [boot_drive], dl

    call    enable_a20_fast

    ; Print hello
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
    jmp $

continue_boot:
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [boot_drive]
    int 0x13
    jc disk_error
    cmp bx, 0xAA55
    jne disk_error

    ; ----------------------------------------------------
    ; Load Stage2 to 0x0800:0x0000 (0x8000 phys)
    ; ----------------------------------------------------
    ; mov ax, cs
    ; mov es, ax

    mov si, dap_stage2
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    jc disk_error
    ; ----------------------------------------------------
    ; Load Kernel to 0x100000 (1MB)
    ; Here we load e.g. 128 sectors (64KB). Adjust count.
    ; ----------------------------------------------------
    mov si, dap_kernel
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; Clear screen
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    ; Switch to PM
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    ; Far jump to Stage2 as PM code
    jmp dword CODE_SEL:0x8000

; Disk Address Packet (DAP)
align 16
dap_stage2:
    db 0x10
    db 0
    dw 1                  ; Stage2 = 1 sector
    dw 0x0000
    dw 0x0800             ; load @ 0x8000
    dq 1                  ; LBA 1 (sector 2 on disk)

    ; size
    ; reserved
    ; sector count
    ; offset
    ; segment (0x0800:0x0000 = 0x8000 physical)
    ; LBA start (sector 2 on disk)
align 16
dap_kernel:
    db 0x10
    db 0
    dw 1              ; number of sectors (adjust to kernel size!)
    dw 0x0000           ; offset
    dw 0x1000           ; segment (0x1000:0 = 0x10000 physical)
    dq 2                ; starting LBA (after Stage2)

disk_error:
    mov si, msg_disk_err
    call print16          ; print the text first

    mov al, ah            ; BIOS error code is in AH after int 0x13
    call print_hex8       ; print it in hex
    jmp $

; ------------------------------- A20 enable ---------------------------------
; Fast A20 via port 0x92 (System Control Port A)
enable_a20_fast:
    in      al, 0x92
    or      al, 2       ; set A20
    out     0x92, al
    ret
; --------------------
hang:
    jmp hang

msg db "...Loading", 0
msg_disk_err db "Disk load error!", 0
msg_unknown db "Unknown boot device!", 0
boot_drive: db 0x80

times 510-($-$$) db 0
dw 0xAA55
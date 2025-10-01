[org 0x8000]
[bits 16]

jmp stage2_start

; --------------------------------------------------
; 32-bit GDT
; --------------------------------------------------
align 8
gdt_start:
    dq 0x0000000000000000  ; Null descriptor

gdt_code:
    dw 0xFFFF              ; Limit 0-15
    dw 0x0000              ; Base 0-15
    db 0x00                ; Base 16-23
    db 10011010b           ; Access: Present, Ring 0, Code, Executable, Readable
    db 11001111b           ; Flags + Limit 16-19: 4KB granularity, 32-bit
    db 0x00                ; Base 24-31

gdt_data:
    dw 0xFFFF              ; Limit 0-15
    dw 0x0000              ; Base 0-15
    db 0x00                ; Base 16-23
    db 10010010b           ; Access: Present, Ring 0, Data, Writable
    db 11001111b           ; Flags + Limit 16-19
    db 0x00                ; Base 24-31

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; Limit (size - 1)
    dd 0                         ; Base (will be filled at runtime)

CODE_SEL equ 0x08
DATA_SEL equ 0x10

; --------------------------------------------------
; 64-bit GDT
; --------------------------------------------------
gdt64:
    dq 0x0000000000000000  ; Null descriptor
.code equ $ - gdt64
    dq 0x00209A0000000000  ; 64-bit code (exec/read)
.data equ $ - gdt64
    dq 0x0000920000000000  ; 64-bit data (read/write)
.pointer:
    dw $ - gdt64 - 1
    dq gdt64
; --------------------------------------------------
stage2_start:
    ; Set up segments properly for Stage 2
    mov ax, 0x0800    ; We're loaded at 0x8000, so segment is 0x0800
    mov ds, ax
    mov es, ax

    ; Display Stage 2 startup message
    call display_stage2_msg
    ; Move kernel from temporary location to final location
    call wait_for_key       ; Will pause until you press any key
    jmp enter_protected_mode

wait_for_key:
    mov ah, 0x00        ; BIOS read keyboard function
    int 0x16            ; Wait for key press (blocks until key pressed)
    ret

; Display "Stage 2" message in VGA text mode
display_stage2_msg:
    push ax
    push es
    
    ; Point to VGA text buffer
    mov ax, 0xB800
    mov es, ax
    
    ; Clear first line
    mov word [es:0], 0x0F20    ; space, white on black
    mov word [es:2], 0x0F20    ; space
    mov word [es:4], 0x0F20    ; space
    mov word [es:6], 0x0F20    ; space
    
    ; Write "Stage 2 Active"
    mov word [es:0], 0x0F53     ; 'S' white on black
    mov word [es:2], 0x0F74     ; 't'
    mov word [es:4], 0x0F61     ; 'a'
    mov word [es:6], 0x0F67     ; 'g'
    mov word [es:8], 0x0F65     ; 'e'
    mov word [es:10], 0x0F20    ; ' '
    mov word [es:12], 0x0F32    ; '2'
    mov word [es:14], 0x0F20    ; ' '
    mov word [es:16], 0x0F41    ; 'A'
    mov word [es:18], 0x0F63    ; 'c'
    mov word [es:20], 0x0F74    ; 't'
    mov word [es:22], 0x0F69    ; 'i'
    mov word [es:24], 0x0F76    ; 'v'
    mov word [es:26], 0x0F65    ; 'e'
    
    pop es
    pop ax
    ret

enter_protected_mode:
    cli

    ; Manually write the GDT descriptor bytes
    mov word [gdt_descriptor], 0x0017        ; Limit = 23
    mov word [gdt_descriptor + 2], 0x8008    ; Base low word
    mov word [gdt_descriptor + 4], 0x0000    ; Base high word
    ; Load GDT
    db 0x66                    ; Operand size override
    lgdt [gdt_descriptor]

    ; Test if we can access GDT correctly
    ; sgdt [gdt_descriptor + 16]  ; Store current GDT info
    
    push es
    mov ax, 0xB800
    mov es, ax
    mov word [es:160], 0x0F47    ; 'G' - GDT loading
    mov word [es:162], 0x0F44    ; 'D'
    mov word [es:164], 0x0F54    ; 'T'
    mov word [es:170], 0x0F4F    ; 'O' - OK
    mov word [es:172], 0x0F4B    ; 'K'
    pop es

    mov ah, 0x00        ; BIOS read keyboard function
    int 0x16            ; Wait for key press (blocks until key pressed)

    ; Enable protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    jmp dword CODE_SEL:protected_mode_start
; --------------------------------------------------
; 32-bit Logic
; --------------------------------------------------
[bits 32]

%define KERNEL_ADDR         0x100000
%define KERNEL_TEMP_ADDR    0x50000    ; Where Stage 1 loaded it temporarily
%define KERNEL_SECTORS      1           ; Match what Stage 1 loaded (16KB)
%define KERNEL_SIZE         (KERNEL_SECTORS * 512)

write_string_pm:
    ; Inputs:
    ; ESI - pointer to null-terminated string
    ; EDI - position in character cells (not bytes!)
    ;       (e.g. 0 = top-left, 80 = second row start)

    mov ebx, 0xB8000      ; VGA memory base

.next_char:
    lodsb                 ; Load byte from [ESI] into AL, increment ESI
    cmp al, 0
    je .done              ; End of string if AL == 0

    mov [ebx + edi * 2], al      ; character byte
    mov byte [ebx + edi * 2 + 1], 0x0F  ; white on black
    inc edi
    jmp .next_char

.done:
    ret

; -------- PROTECTED MODE --------
protected_mode_start:
    ; Set up all segment registers with data selector
    mov ax, DATA_SEL
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Set up 32-bit stack (well below kernel area)
    mov esp, 0x90000

    ; Load string pointer into ESI
    mov esi, debug_msg

    ; Top-left corner (row 0, col 0) = char offset 0
    mov edi, 0

    in al, 0x92
    or al, 2
    out 0x92, al

    ; --- Copy Kernel code ---
    call copy_kernel_to_high
    ; ------------------------
    call setup_paging

    ; After setup_paging, before load_gdt64
    mov esi, debug_paging
    mov edi, 240
    call write_string_pm

    ; Display PML4[0]
    ; mov eax, [0x70000]
    ; mov edi, 0xB8000 + 260
    ; call display_hex_eax

    ; ; Display PDPT[0]
    ; mov eax, [0x71000]
    ; mov edi, 0xB8000 + 280
    ; call display_hex_eax

    ; ; Display PD[0]
    ; mov eax, [0x72000]
    ; mov edi, 0xB8000 + 300
    ; call display_hex_eax

    call load_gdt64
    call enable_long_mode

debug_paging db "PT:", 0

; Copies the kernel from 0x20000 to 0x100000 (64 sectors = 32 KiB)
copy_kernel_to_high:
    ; mov esi, debug_src
    ; mov edi, 320  ; Line 2
    ; call write_string_pm
    
    ; mov esi, KERNEL_TEMP_ADDR
    ; mov edi, 0xB8000 + 960
    ; mov ecx, 80
    ; call display_hex_bytes_32
    
    ; Do the actual copy
    mov esi, KERNEL_TEMP_ADDR
    mov edi, KERNEL_ADDR
    mov ecx, KERNEL_SIZE
    cld
    rep movsb                   ; ← Use movsb, not movsd!
    
    ; Display destination bytes AFTER copy
    mov esi, debug_dst
    mov edi, 800  ; Line 2, further right
    call write_string_pm
    
    mov esi, KERNEL_ADDR
    mov edi, 0xB8000 + 420
    mov ecx, 40
    call display_hex_bytes_32   

    ret

debug_src db "SRC:", 0
debug_dst db "DST:", 0

display_hex_bytes_32:
    pusha
.loop:
    test ecx, ecx
    jz .done
    
    movzx eax, byte [esi]
    
    ; High nibble
    mov edx, eax
    shr edx, 4
    and edx, 0x0F
    add dl, '0'
    cmp dl, '9'
    jle .high_ok
    add dl, 7
.high_ok:
    mov [edi], dl
    mov byte [edi+1], 0x0F
    add edi, 2
    
    ; Low nibble
    mov edx, eax
    and edx, 0x0F
    add dl, '0'
    cmp dl, '9'
    jle .low_ok
    add dl, 7
.low_ok:
    mov [edi], dl
    mov byte [edi+1], 0x0F
    add edi, 2
    
    ; Space
    mov byte [edi], ' '
    mov byte [edi+1], 0x0F
    add edi, 2
    
    inc esi
    dec ecx
    jmp .loop
.done:
    popa
    ret

display_hex_eax:
    ; Input: EAX = value to display, EDI = screen position
    push eax
    push ebx
    push ecx
    
    mov ebx, eax
    mov ecx, 8  ; 8 hex digits
.loop:
    rol ebx, 4
    mov eax, ebx
    and eax, 0x0F
    add al, '0'
    cmp al, '9'
    jle .digit
    add al, 7
.digit:
    mov [edi], al
    mov byte [edi+1], 0x0F
    add edi, 2
    dec ecx
    jnz .loop
    
    pop ecx
    pop ebx
    pop eax
    ret
copy_msg db "Copying kernel...", 0

setup_paging:
    ; Zero page tables
    mov edi, 0x70000
    mov ecx, 0x3000 / 4
    xor eax, eax
    rep stosd

    ; PML4[0] -> PDPT
    mov dword [0x70000], 0x71003
    mov dword [0x70004], 0x00000000

    ; PDPT[0] -> PD
    mov dword [0x71000], 0x72003
    mov dword [0x71004], 0x00000000

    ; PD[0]: Map first 2MB
    mov dword [0x72000], 0x00000083  ; Physical 0x000000, 2MB, Present, RW, PS
    mov dword [0x72004], 0x00000000

    ; PD[1]: Map second 2MB  
    mov dword [0x72008], 0x00200083  ; Physical 0x200000, 2MB, Present, RW, PS
    mov dword [0x7200C], 0x00000000

    ; Load CR3
    mov eax, 0x70000
    mov cr3, eax
    
    ; **FLUSH TLB**
    mov eax, cr3
    mov cr3, eax
    
    ret

load_gdt64:
    ; Compute address of gdt64 dynamically (optional)
    ; assuming code is loaded at 0x8000:
    mov eax, gdt64 - $$ + 0x8000
    mov [gdt64.pointer + 2], eax

    ; load GDT
    lgdt [gdt64.pointer]
    ret

enable_long_mode:
    ; Enable PAE
    mov eax, cr4
    or eax, 1 << 5        ; PAE = bit 5
    mov cr4, eax

    ; Enable long mode in EFER MSR
    mov ecx, 0xC0000080   ; IA32_EFER MSR
    rdmsr
    or eax, 1 << 8        ; LME = Long Mode Enable
    wrmsr

    ; Enable paging
    mov eax, cr0
    or eax, (1 << 31)     ; PG = Paging Enable
    or eax, (1 << 0)      ; PE = Protected Mode Enable
    mov cr0, eax

    jmp 0x08:long_mode_start  ; far jump to 64-bit mode

debug_msg db 'Hello from Protected Mode!', 0
; --------------------------------------------------
; 64-bit Code
; --------------------------------------------------
[bits 64]

long_mode_start:
    ; Reload data segments
    mov ax, gdt64.data
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Set up stack FIRST, before any function calls
    ; Set up BIGGER stack
    mov rsp, 0x90000      ; More stack space
    and rsp, -16
    ; xor rbp, rbp        ; ← ADD THIS: Clear RBP before calling kernel
    
    ; cld
    ; xor rax, rax
    ; xor rbx, rbx
    ; xor rcx, rcx
    ; xor rdx, rdx
    ; xor rsi, rsi    ; ← Make sure RSI is cleared!
    ; xor rdi, rdi
    ; xor rbp, rbp
    ; xor r8, r8
    ; xor r9, r9
    ; xor r10, r10
    ; xor r11, r11
    ; xor r12, r12
    ; xor r13, r13
    ; xor r14, r14
    ; xor r15, r15

    call KERNEL_ADDR
    cli
    hlt
    ; jmp $

.kernel_bad:
    ; Display error if kernel wasn't copied correctly
    mov rbx, 0xB8000 + 320  ; Line 2
    mov word [rbx], 0x4F45  ; 'E' - white on red
    mov word [rbx+2], 0x4F52  ; 'R'
    mov word [rbx+4], 0x4F52  ; 'R'
    jmp .halt

.halt:
    cli
    hlt
    jmp .halt

display_hex_bytes:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    
.byte_loop:
    test ecx, ecx
    jz .done
    
    ; Read one byte
    movzx eax, byte [rsi]
    
    ; Display high nibble
    mov edx, eax
    shr edx, 4
    and edx, 0x0F
    call .hex_digit
    mov [rdi], dl
    mov byte [rdi + 1], 0x0F
    add rdi, 2
    
    ; Display low nibble
    mov edx, eax
    and edx, 0x0F
    call .hex_digit
    mov [rdi], dl
    mov byte [rdi + 1], 0x0F
    add rdi, 2
    
    ; Space between bytes
    mov byte [rdi], ' '
    mov byte [rdi + 1], 0x0F
    add rdi, 2
    
    inc rsi
    dec ecx
    jmp .byte_loop
.done:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
.hex_digit:
    ; Convert DL (0-15) to ASCII hex character
    cmp dl, 9
    jle .is_digit
    add dl, 'A' - 10
    ret
.is_digit:
    add dl, '0'
    ret

vga64_msg db "64-bit Mode - Jumping to kernel...", 0

; rdi = pointer to null-terminated string
write_string_64:
    mov rsi, rdi
    mov rbx, 0xB8000
    xor rcx, rcx
.next:
    lodsb
    test al, al
    jz .done
    mov [rbx + rcx * 2], al
    mov byte [rbx + rcx * 2 + 1], 0x0F
    inc rcx
    jmp .next
.done:
    ret
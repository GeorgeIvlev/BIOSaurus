org 0x8000
bits 32

jmp start

%define KERNEL_ADDR 0x100000
%define KERNEL_SECTORS 128         ; adjust in build script
%define KERNEL_SIZE    (KERNEL_SECTORS * 512)

print_hex32_pm:
    pusha
    mov edi, 0xB8000
    mov ecx, 8
    mov ebx, eax
.loop:
    rol ebx, 4
    mov dl, bl
    and dl, 0x0F
    cmp dl, 9
    jbe .digit
    add dl, 'A' - 10
    jmp .out
.digit:
    add dl, '0'
.out:
    mov [edi], dl
    mov byte [edi+1], 0x1F
    add edi, 2
    loop .loop
    popa
    ret

start:
    ; Set up data segments
    mov ax, 0x10    ; DATA_SEL = 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; lidt [idt_descriptor]
    
    ; Set up stack
    mov esp, 0x90000

    ; Copy kernel from 0x10000 to 0x100000
    mov esi, 0x10000                  ; source
    mov edi, 0x100000                 ; destination
    mov ecx, KERNEL_SIZE
    rep movsb
    
    ; mov eax, [0x100000]
    ; call print_hex32_pm

    ; ; Memory barrier for VGA write
    ; mov eax, 0x1F4B1F4F  ; "OK" in white-on-blue
    ; mov dword [0xB8000], eax
    ; mov eax, [0xB8000]   ; Force read-back
    
    ; ; Halt with visible marker
    ; mov dword [0xB8004], 0x1F451F44  ; "DE" (Debug End)
    
    ; 3. Check if CPU supports long mode
    call check_long_mode
    jc .no_long_mode

    ; 4. Set up paging (4-level paging for x86-64)
    call setup_paging

    ; 5. Set up 64-bit GDT
    lgdt [gdt64.pointer]

    ; 6. Enable PAE (Physical Address Extension)
    mov eax, cr4
    or eax, 1 << 5      ; Set PAE bit
    mov cr4, eax

    ; 7. Set up long mode
    mov ecx, 0xC0000080 ; EFER MSR
    rdmsr
    or eax, 1 << 8      ; Set LME bit
    wrmsr

    ; 8. Enable paging and protection
    mov eax, cr0
    or eax, 1 << 31      ; Set PG bit
    or eax, 1 << 0       ; Set PE bit
    mov cr0, eax

    ; 9. Jump to 64-bit code segment
    jmp gdt64.code:long_mode_start

.no_long_mode:
    mov dword [0xB8000], 0x1F4E1F4C  ; "LN" (Long Mode Not Available)
    cli
    hlt


; --------------------------------------------------
; 32-bit Functions
; --------------------------------------------------
check_long_mode:
    ; Check for CPUID
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 1 << 21
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd
    xor eax, ecx
    jz .no_cpuid

    ; Check for long mode
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .no_long_mode

    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29
    jz .no_long_mode
    clc
    ret

.no_cpuid:
.no_long_mode:
    stc
    ret

setup_paging:
    ; Zero out page tables
    mov edi, 0x70000
    mov ecx, 0x10000/4
    xor eax, eax
    rep stosd

    ; Set up PML4
    mov eax, 0x71000 | 0b11 ; Present + Writable
    mov [0x70000], eax

    ; Set up PDP
    mov eax, 0x72000 | 0b11
    mov [0x71000], eax

    ; Set up PD (2MB pages)
    mov eax, 0x000000 | 0b10000011 ; 2MB page, Present + Writable + Large
    mov [0x72000], eax

    ; Set up identity mapping for first 2MB
    mov eax, 0x000000 | 0b10000011
    mov [0x72008], eax

    ; Load PML4 to CR3
    mov eax, 0x70000
    mov cr3, eax
    ret
; --------------------------------------------------
; 64-bit Code
; --------------------------------------------------
bits 64

extern __DATA_LOAD
extern __DATA_START
extern __DATA_SIZE  ; Use size instead of end-start

long_mode_start:
    ; Reload data segments
    mov ax, gdt64.data
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; set a 64-bit stack and align for SysV ABI
    mov rsp, 0x90000
    and rsp, -16

    ; ; ===== INITIALIZE .DATA SECTION =====
    ; mov rsi, __DATA_LOAD    ; Source address (from ROM)
    ; mov rdi, __DATA_START   ; Destination address (runtime)
    ; mov rcx, [__DATA_SIZE]  ; Load size value
    ; rep movsb               ; Copy .data from ROM to RAM
    
    ; ; ===== CLEAR .BSS =====
    ; mov rdi, __BSS_START
    ; mov rcx, __BSS_END - __BSS_START
    ; xor rax, rax
    ; rep stosb
    ; Print 64-bit marker
    ; mov rax, 0x1F341F36  ; "64" in white-on-blue
    ; mov [0xB8000], rax

    ; Call your kernel here
    mov rax, KERNEL_ADDR   ; 0x100000
    call rax               ; Call kernel entry point

    cli
    hlt

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
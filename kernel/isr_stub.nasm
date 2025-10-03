section .text

; Macro for ISRs that don't push error codes
%macro ISR_NOERRCODE 1
global isr%1
isr%1:
    push qword 0           ; Push dummy error code
    push qword %1          ; Push interrupt number
    jmp isr_common_stub
%endmacro

; Macro for ISRs that push error codes
%macro ISR_ERRCODE 1
global isr%1
isr%1:
    push qword %1          ; Push interrupt number (error code already pushed by CPU)
    jmp isr_common_stub
%endmacro

; Define the first 32 ISRs (CPU exceptions)
ISR_NOERRCODE 0   ; Divide by zero
ISR_NOERRCODE 1   ; Debug
ISR_NOERRCODE 2   ; Non-maskable interrupt
ISR_NOERRCODE 3   ; Breakpoint
ISR_NOERRCODE 4   ; Overflow
ISR_NOERRCODE 5   ; Bound range exceeded
ISR_NOERRCODE 6   ; Invalid opcode
ISR_NOERRCODE 7   ; Device not available
ISR_ERRCODE   8   ; Double fault (has error code)
ISR_NOERRCODE 9   ; Coprocessor segment overrun
ISR_ERRCODE   10  ; Invalid TSS (has error code)
ISR_ERRCODE   11  ; Segment not present (has error code)
ISR_ERRCODE   12  ; Stack-segment fault (has error code)
ISR_ERRCODE   13  ; General protection fault (has error code)
ISR_ERRCODE   14  ; Page fault (has error code)
ISR_NOERRCODE 15  ; Reserved
ISR_NOERRCODE 16  ; x87 floating point exception
ISR_ERRCODE   17  ; Alignment check (has error code)
ISR_NOERRCODE 18  ; Machine check
ISR_NOERRCODE 19  ; SIMD floating point exception
ISR_NOERRCODE 20  ; Virtualization exception
ISR_ERRCODE   21  ; Control protection exception (has error code)
ISR_NOERRCODE 22  ; Reserved
ISR_NOERRCODE 23  ; Reserved
ISR_NOERRCODE 24  ; Reserved
ISR_NOERRCODE 25  ; Reserved
ISR_NOERRCODE 26  ; Reserved
ISR_NOERRCODE 27  ; Reserved
ISR_NOERRCODE 28  ; Hypervisor injection exception
ISR_ERRCODE   29  ; VMM communication exception (has error code)
ISR_ERRCODE   30  ; Security exception (has error code)
ISR_NOERRCODE 31  ; Reserved

ISR_NOERRCODE 33   ; IRQ1 - Keyboard
ISR_NOERRCODE 44   ; IRQ12 - PS2 Mouse

; Common ISR stub - saves context and calls C handler
extern isr_handler
isr_common_stub:
    ; Save all registers
    push r15
    push r14
    push r13
    push r12
    push r11
    push r10
    push r9
    push r8
    push rbp
    push rdi
    push rsi
    push rdx
    push rcx
    push rbx
    push rax
    
    mov rbp, rsp
    and rsp, -16
    ; Call C handler (interrupt number and error code are already on stack)
    mov rdi, rsp        ; Pass stack pointer as first argument
    call isr_handler
    
    mov rsp, rbp        ; Restore original RSP
    
    ; Restore in reverse order
    pop rax
    pop rbx
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rbp
    pop r8
    pop r9
    pop r10
    pop r11
    pop r12
    pop r13
    pop r14
    pop r15

    ; Clean up error code and interrupt number
    add rsp, 16
    
    ; Return from interrupt
    iretq
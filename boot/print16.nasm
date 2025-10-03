print16:
    pusha
    mov ah, 0x0e
    mov bh, 0      ; Page number 0
    mov bl, 7      ; Light gray on black
.print_loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .print_loop
.done:
    popa
    ret

; Prints an 8-bit value in AL as two hex characters
print_hex8:
    push ax
    push bx
    push cx
    
    mov bx, ax          ; save original value
    mov cx, 2           ; 2 hex digits
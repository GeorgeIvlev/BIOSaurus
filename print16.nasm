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
    pusha
    mov ah, al
    shr ah, 4
    and ah, 0x0F
    call print_hex_digit

    mov ah, al
    and ah, 0x0F
    call print_hex_digit
    popa
    ret

; --------------------
; Prints a single hex digit in AH (0–15)
print_hex_digit:
    cmp ah, 9
    jbe .is_num
    add ah, 'A' - 10
    jmp .out
.is_num:
    add ah, '0'
.out:
    mov al, ah
    mov ah, 0x0E       ; BIOS teletype
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    ret
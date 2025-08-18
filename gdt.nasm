; ; ---------------- GDT ----------------
; align 8
; GDT_start:
; GDT_null:   dq 0x0000000000000000

; ; 32-bit code segment: base=0, limit=4GB
; GDT_code32: 
;     dw 0xFFFF
;     dw 0x0000
;     db 0x00
;     db 10011010b
;     db 11001111b
;     db 0x00

; ; 32-bit data segment: base=0, limit=4GB
; GDT_data32:
;     dw 0xFFFF
;     dw 0x0000
;     db 0x00
;     db 10010010b
;     db 11001111b
;     db 0x00

; ; 64-bit code: base=0, limit ignored, L=1, D=0, G can be 1 or 0 (ignored)
; GDT_code64:
;     dw 0x0000
;     dw 0x0000
;     db 0x00
;     db 10011010b        ; Access: P=1 DPL=0 S=1 Code R/X
;     db 00100000b        ; Flags: L=1, D=0, G=0, lim high=0
;     db 0x00

; GDT_end:

; GDT_descriptor:
;     dw GDT_end - GDT_start - 1
;     dd GDT_start

; ; Selectors = byte offsets from GDT base (same style you used)
; CODE32_SEL equ (GDT_code32 - GDT_start)
; DATA32_SEL equ (GDT_data32 - GDT_start)
; CODE64_SEL equ (GDT_code64 - GDT_start)
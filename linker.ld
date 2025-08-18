ENTRY(_kernel)

SECTIONS {
    . = 0x00100000;
    .text.entry : {
        *(.text.entry)  /* Only _kernel here */
    }
    .text : {
        *(.text*)       /* Other functions */
    }
    .rodata : {
        *(.rodata*)
    }
    __DATA_START = .;
    .data : {
        *(.data)
    }
    __DATA_END = .;
    __DATA_SIZE = __DATA_END - __DATA_START;  /* ADD THIS */
    __BSS_START = .;
    .bss : {
        *(COMMON)
        *(.bss)
    }
    __BSS_END = .;
}
ENTRY(_kernel)

SECTIONS {
    . = 0x00100000;
    
    .text : {
        *(.text._kernel)  /* Force _kernel to be first */
        *(.text*)
    }
    
    .rodata : ALIGN(4096) {
        *(.rodata*)
    }
    
    .data : ALIGN(4096) {
        *(.data*)
    }
    
    .bss : ALIGN(4096) {
        *(.bss*)
        *(COMMON)
    }
    
    /DISCARD/ : {
        *(.note*)
        *(.comment*)
        *(.eh_frame*)
    }
}
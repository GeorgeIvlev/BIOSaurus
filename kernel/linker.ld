OUTPUT_FORMAT(elf64-x86-64)
ENTRY(_kernel)

SECTIONS
{
    . = 0x100000;  /* Kernel loads at 1MB - matches your KERNEL_ADDR */

    /* Code section */
    .text : ALIGN(4096) {
        *entry.o(.text .text*)     /* Entry point first */
        *(.text .text*)            /* Then everything else */
    }

    /* Read-only data */
    .rodata : ALIGN(4096) {
        *(.rodata .rodata*)
    }

    /* Initialized data section */
    .data : ALIGN(4096) {
        __data_start = .;
        *(.data .data*)
        __data_end = .;
    }

    __data_load_start = LOADADDR(.data);

    /* Uninitialized data section */
    .bss : ALIGN(4096) {
        __bss_start = .;
        *(COMMON)
        *(.bss .bss*)
        __bss_end = .;        /* ADD THIS LINE */
    }

    __kernel_end = .;

    /* Discard unnecessary sections */
    /DISCARD/ : {
        *(.comment)
        *(.eh_frame)
        *(.note*)
    }
}
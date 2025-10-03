// #include <stdint.h>
#include "types.h"
#include "memory.h"

extern uint8_t __data_start[];
extern uint8_t __data_end[];
extern uint8_t __data_load_start[];
extern uint8_t __bss_start[];
extern uint8_t __bss_end[];

// Initialize .data section
void init_data(void) {
    size_t data_size = (size_t)(__data_end - __data_start);
    
    if (__data_load_start != __data_start && data_size > 0) {
        memcpy(__data_start, __data_load_start, data_size);
    }
}

// Initialize .bss section
void init_bss(void) {
    size_t bss_size = (size_t)(__bss_end - __bss_start);

    if (bss_size > 0) {
        zero_memory(__bss_start, bss_size);
    }
}

extern volatile uint16_t* VGA_BUFFER;

void kernel_init(void) {
    // TODO: Basic screen flush with default color
    // Be careful! Only used for 80 * 25 text mode!!!
    for (int i = 0; i < 80 * 25; i++) {
        VGA_BUFFER[i] = 0x0F20;  // Space, white on black
    }

    init_data();
    init_bss();
}
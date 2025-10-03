#include "types.h"

void kernel_init(void);
void kernel_main(void);

__attribute__((noreturn))
void _kernel(void) {
    kernel_init();
    // Now call the actual kernel
    kernel_main();
    
    // Should never reach here
    while (1) {
        __asm__ volatile("hlt");
    }
}
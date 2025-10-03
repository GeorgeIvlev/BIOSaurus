#include "types.h"
#include "io.h"
#include "isr.h"
#include "pic.h"

static char key_buffer[256];
static int buffer_read = 0;
static int buffer_write = 0;

// US QWERTY scancode to ASCII table (set 1)
static const char scancode_to_ascii[] = {
    0,  27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b',
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',
    0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',
    0, '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0,
    '*', 0, ' '
};

extern volatile uint16_t* VGA_BUFFER;

static void keyboard_handler(registers_t* regs) {
    uint8_t scancode = inb(KEYBOARD_DATA_PORT);

    // Only handle key press (bit 7 = 0)
    if (!(scancode & 0x80)) {
        if (scancode < sizeof(scancode_to_ascii)) {
            char ascii = scancode_to_ascii[scancode];
            if (ascii != 0) {
                // Add to circular buffer
                key_buffer[buffer_write] = ascii;
                buffer_write = (buffer_write + 1) % 256;
            }
        }
    }

    // Send End of Interrupt to PIC
    // pic_send_eoi(1);
}

void keyboard_init(void) {
    VGA_BUFFER[1940] = 0x0F42;  // 'B' - Before install
    // Install keyboard handler for IRQ1 (interrupt 33)
    isr_install_handler(33, keyboard_handler);
    
    VGA_BUFFER[1941] = 0x0F41;  // 'A' - After install
    // Enable keyboard IRQ
    pic_clear_mask(1);

    VGA_BUFFER[1942] = 0x0F45;  // 'E' - Enabled IRQ
}

char keyboard_getchar(void) {
    if (buffer_read == buffer_write) {
        return 0;  // No key available
    }
    
    char c = key_buffer[buffer_read];
    buffer_read = (buffer_read + 1) % 256;
    return c;
}
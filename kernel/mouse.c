#include "io.h"
#include "isr.h"
#include "pic.h"
#include "mouse.h"

#define MOUSE_DATA_PORT    0x60
#define MOUSE_COMMAND_PORT 0x64

#define MOUSE_CMD_SET_DEFAULTS  0xF6
#define MOUSE_CMD_ENABLE        0xF4
#define MOUSE_CMD_DISABLE       0xF5
#define MOUSE_CMD_SET_SAMPLE    0xF3
#define MOUSE_CMD_GET_ID        0xF2
#define CONTROLLER_CMD_WRITE    0xD4

static mouse_state_t mouse_state = {0, 0, 0};
static uint8_t mouse_cycle = 0;
static int8_t mouse_byte[3];

// Wait for mouse controller to be ready for writing
static void mouse_wait_write(void) {
    uint32_t timeout = 100000;
    while (timeout--) {
        if ((inb(MOUSE_COMMAND_PORT) & 2) == 0) {
            return;
        }
    }
}

// Wait for mouse data to be available
static void mouse_wait_read(void) {
    uint32_t timeout = 100000;
    while (timeout--) {
        if (inb(MOUSE_COMMAND_PORT) & 1) {
            return;
        }
    }
}

// Write to mouse
static void mouse_write(uint8_t data) {
    mouse_wait_write();
    outb(MOUSE_COMMAND_PORT, CONTROLLER_CMD_WRITE);
    mouse_wait_write();
    outb(MOUSE_DATA_PORT, data);
}

// Read from mouse
static uint8_t mouse_read(void) {
    // mouse_wait_read();
    // return inb(MOUSE_DATA_PORT);
    uint32_t timeout = 100000;
    while (timeout--) {
        if (inb(MOUSE_COMMAND_PORT) & 0x01) {
            return inb(MOUSE_DATA_PORT);
        }
    }
    return 0xFF;  // Timeout - return invalid value
}

extern volatile uint16_t* VGA_BUFFER;

// Mouse interrupt handler
static void mouse_handler(registers_t* regs) {
    uint8_t status = inb(MOUSE_COMMAND_PORT);
    
    if (!(status & 0x01)) {
        return;
    }
    
    uint8_t data = inb(MOUSE_DATA_PORT);
    
    if (!(status & 0x20)) {
        return;  // Keyboard data
    }
    
    // Discard ACK bytes
    if (data == 0xFA) {
        return;
    }
    
    mouse_byte[mouse_cycle] = data;
    mouse_cycle++;
    
    if (mouse_cycle >= 3) {
        mouse_cycle = 0;
        
        uint8_t flags = (uint8_t)mouse_byte[0];
        
        if (!(flags & 0x08)) {
            mouse_cycle = 0;  // Reset on bad packet
            return;
        }
        
        int8_t dx = (int8_t)mouse_byte[1];
        int8_t dy = (int8_t)mouse_byte[2];
        
        mouse_state.buttons = flags & 0x07;
        mouse_state.x += dx;
        mouse_state.y -= dy;
        
        if (mouse_state.x < 0) mouse_state.x = 0;
        if (mouse_state.x >= 80) mouse_state.x = 79;
        if (mouse_state.y < 0) mouse_state.y = 0;
        if (mouse_state.y >= 25) mouse_state.y = 24;
    }
    
    // Send EOI AFTER processing
    // pic_send_eoi(12);
}

void mouse_init(void) {
    // Only install the handler, don't configure anything
    isr_install_handler(44, mouse_handler);
    pic_clear_mask(12);
    
    mouse_state.x = 40;
    mouse_state.y = 12;
    mouse_cycle = 0;
}

mouse_state_t mouse_get_state(void) {
    return mouse_state;
}
#include "memory.h"
#include "io.h"
#include "vga.h"

// Correct VGA Mode 13h register values
static uint8_t mode13h_regs[] = {
    /* MISC */
    0x63,
    /* SEQ (5 registers) */
    0x03, 0x01, 0x0F, 0x00, 0x0E,  // Last value should be 0x0E, not 0x06
    /* CRTC (25 registers) */
    0x5F, 0x4F, 0x50, 0x82, 0x54, 0x80, 0xBF, 0x1F,
    0x00, 0x41, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x9C, 0x0E, 0x8F, 0x28, 0x40, 0x96, 0xB9, 0xA3,
    0xFF,
    /* GC (9 registers) */
    0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x05, 0x0F,
    0xFF,
    /* AC (21 registers) */
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
    0x41, 0x00, 0x0F, 0x00, 0x00
};

// Small delay function for VGA timing
static inline void vga_delay(void) {
    inb(0x80); // Port 0x80 is often used for timing delays
}

void vga_set_mode_13h(void) {
    // Disable interrupts during mode switch
    // cli(); // Uncomment if you have interrupt control functions
    
    // Reset AC index flip-flop first
    inb(VGA_INSTAT_READ);
    
    // Disable video output during mode switch
    outb(VGA_AC_INDEX, 0x00);
    vga_delay();
    
    // Write MISC register
    outb(VGA_MISC_WRITE, mode13h_regs[0]);
    vga_delay();
    
    // Sequencer registers (5 registers)
    // Reset sequencer first
    outb(VGA_SEQ_INDEX, 0x00);
    outb(VGA_SEQ_DATA, 0x01);
    vga_delay();
    
    for (int i = 1; i < 5; i++) {
        outb(VGA_SEQ_INDEX, i);
        outb(VGA_SEQ_DATA, mode13h_regs[1 + i]);
        vga_delay();
    }
    
    // End sequencer reset
    outb(VGA_SEQ_INDEX, 0x00);
    outb(VGA_SEQ_DATA, 0x03);
    vga_delay();
    
    // Disable CRTC protection
    outb(VGA_CRTC_INDEX, 0x11);
    outb(VGA_CRTC_DATA, inb(VGA_CRTC_DATA) & 0x7F);
    vga_delay();
    
    // CRTC registers (25 registers)
    for (int i = 0; i < 25; i++) {
        outb(VGA_CRTC_INDEX, i);
        outb(VGA_CRTC_DATA, mode13h_regs[6 + i]);
        vga_delay();
    }
    
    // Graphics Controller registers (9 registers)
    for (int i = 0; i < 9; i++) {
        outb(VGA_GC_INDEX, i);
        outb(VGA_GC_DATA, mode13h_regs[31 + i]);
        vga_delay();
    }
    
    // Attribute Controller registers (21 registers) - PROPERLY FIXED!
    inb(VGA_INSTAT_READ); // Reset AC flip-flop
    
    for (int i = 0; i < 20; i++) {
        outb(VGA_AC_INDEX, i | 0x20); // Set PAS bit to prevent flicker
        outb(VGA_AC_INDEX, mode13h_regs[40 + i]);
        vga_delay();
    }
    
    // Handle the last AC register (Mode Control Register)
    outb(VGA_AC_INDEX, 20 | 0x20);
    outb(VGA_AC_INDEX, mode13h_regs[60]);
    vga_delay();
    
    // Final screen enable
    inb(VGA_INSTAT_READ);
    outb(VGA_AC_INDEX, 0x20); // Enable video output
    
    // Re-enable interrupts
    // sti(); // Uncomment if you have interrupt control functions
}

void vga_set_text_mode(void) {
    // Set text mode 3 (80x25)
    // You'd need similar register table for text mode
    // For now, this is a placeholder
}

void vga_put_pixel(int x, int y, uint8_t color) {
    if (x >= 0 && x < 320 && y >= 0 && y < 200) {
        uint8_t* framebuffer = (uint8_t*)VGA_GFX_BUFFER;
        framebuffer[y * 320 + x] = color;
    }
}

void vga_clear_screen(uint8_t color) {
    uint8_t* framebuffer = (uint8_t*)VGA_GFX_BUFFER;
    
    // Use a simple loop instead of memset for better compatibility
    for (int i = 0; i < 320 * 200; i++) {
        framebuffer[i] = color;
    }
}
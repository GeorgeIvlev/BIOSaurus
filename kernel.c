#include <stdint.h>
#include <stddef.h>

#define VGA_ADDRESS 0xB8000
#define VGA_WIDTH   80
#define VGA_HEIGHT  25

static volatile uint16_t* const VGA_BUFFER = (uint16_t*)VGA_ADDRESS;

static size_t cursor_row = 0;
static size_t cursor_col = 0;
static uint8_t vga_color = 0x1F; // white on blue

// Encode a character + color into VGA cell
static inline uint16_t vga_entry(char c, uint8_t color) {
    return (uint16_t)c | ((uint16_t)color << 8);
}

void vga_clear() {
    for (size_t y = 0; y < VGA_HEIGHT; y++) {
        for (size_t x = 0; x < VGA_WIDTH; x++) {
            VGA_BUFFER[y * VGA_WIDTH + x] = vga_entry(' ', vga_color);
        }
    }
    cursor_row = 0;
    cursor_col = 0;
}

void vga_putc(char c) {
    if (c == '\n') {
        cursor_row++;
        cursor_col = 0;
    } else {
        VGA_BUFFER[cursor_row * VGA_WIDTH + cursor_col] = vga_entry(c, vga_color);
        cursor_col++;
        if (cursor_col >= VGA_WIDTH) {
            cursor_col = 0;
            cursor_row++;
        }
    }

    if (cursor_row >= VGA_HEIGHT) {
        cursor_row = 0; // wrap around (simple for now)
    }
}

void vga_print(const char* str) {
    for (size_t i = 0; str[i] != '\0'; i++) {
        vga_putc(str[i]);
    }
}

__attribute__((section(".text.entry")))
void _kernel() {
    vga_clear();
    volatile unsigned short* vga = (unsigned short*)0xB8000;
    vga[0] = 0x1F4B; vga[1] = 0x1F21; // "K!"
    // vga_print("X");
}
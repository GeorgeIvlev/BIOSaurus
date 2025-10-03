#pragma once

#include "types.h"

// VGA Register ports
#define VGA_AC_INDEX        0x3C0
#define VGA_AC_WRITE        0x3C0
#define VGA_AC_READ         0x3C1
#define VGA_MISC_WRITE      0x3C2
#define VGA_SEQ_INDEX       0x3C4
#define VGA_SEQ_DATA        0x3C5
#define VGA_GC_INDEX        0x3CE
#define VGA_GC_DATA         0x3CF
#define VGA_CRTC_INDEX      0x3D4
#define VGA_CRTC_DATA       0x3D5
#define VGA_INSTAT_READ     0x3DA

// Framebuffer addresses
#define VGA_TEXT_BUFFER     0xB8000
#define VGA_GFX_BUFFER      0xA0000

void vga_set_mode_13h(void);     // 320x200x256
void vga_set_text_mode(void);    // 80x25 text
void vga_put_pixel(int x, int y, uint8_t color);
void vga_clear_screen(uint8_t color);
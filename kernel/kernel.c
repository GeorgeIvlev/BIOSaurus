#include "types.h"
#include "idt.h"

#include "pic.h"
#include "mouse.h"
#include "vga.h"

// TODO: This is temporary while no VESA or GPU driver
// is implemented
volatile uint16_t* VGA_BUFFER = (uint16_t*)0xB8000;

// Test with various global variable types
int global_counter = 42;           // .data (initialized)
int uninitialized_value;           // .bss (uninitialized)
static int static_value = 100;     // .data (initialized)

void kernel_write(const char* str) {
    static int pos = 0;  // .bss (static local)
    for (int i = 0; str[i] != '\0'; i++) {
        if (str[i] == 10) {
            pos+= 80;
        }
        
        VGA_BUFFER[pos++] = (uint16_t)str[i] | 0x0F00;
    }
}

void print(const char* str) {}
void kernel_main(void) {
    idt_init();

    // volatile int a = 5;
    // volatile int b = 0;
    // volatile int c = a / b;  // This will trigger interrupt 0
    
    kernel_write(" Done!");
    kernel_write("\nKernel running with interrupts enabled!");


    keyboard_init();
    // mouse_init();

    const char* prompt = "Type something: ";
    for (int i = 0; prompt[i]; i++) {
        VGA_BUFFER[i] = 0x0F00 | prompt[i];
    }
    
    int pos = 1440;
    // mouse_state_t last_mouse = {-1, -1, 0};
    // mouse_state_t mouse_state;
    int is_vga_enabled = 0;

    while (1) {
        char c = keyboard_getchar();
        if (c != 0) {
            if (c == 27) {  // ESC
                break;
            }

            if (c == 57 && !is_vga_enabled) {
                is_vga_enabled = 1;
                // Switch to graphical mode
                vga_set_mode_13h();
                
                // Clear screen to blue
                vga_clear_screen(1);

                // Draw some pixels
                // for (int x = 0; x < 320; x++) {
                //     vga_put_pixel(x, 100, 15);  // White horizontal line
                // }
                
                // // Draw a box
                // for (int i = 0; i < 50; i++) {
                //     vga_put_pixel(100 + i, 50, 10);      // Top
                //     vga_put_pixel(100 + i, 100, 10);     // Bottom
                //     vga_put_pixel(100, 50 + i, 10);      // Left
                //     vga_put_pixel(150, 50 + i, 10);      // Right
                // }
            }

            if (c == '\b' && pos > 16) {
                // Backspace
                pos--;
                VGA_BUFFER[pos] = 0x0F20;
            } else if (c == '\n') {
                // Enter - move to next line
                pos = ((pos / 80) + 1) * 80;
            } else if (c >= 32 && c < 127) {
                // Printable character
                VGA_BUFFER[pos++] = 0x0F00 | c;
            }
        }

        // // Handle mouse cursor
        // mouse_state = mouse_get_state();

        // // Display coordinates
        // char coord_buf[20];
        // coord_buf[0] = 'X';
        // coord_buf[1] = ':';
        // coord_buf[2] = '0' + (mouse_state.x / 10);
        // coord_buf[3] = '0' + (mouse_state.x % 10);
        // coord_buf[4] = ' ';
        // coord_buf[5] = 'Y';
        // coord_buf[6] = ':';
        // coord_buf[7] = '0' + (mouse_state.y / 10);
        // coord_buf[8] = '0' + (mouse_state.y % 10);
        
        // for (int i = 0; i < 9; i++) {
        //     VGA_BUFFER[80 * 24 + 70 + i] = 0x0F00 | coord_buf[i];
        // }

        // last_mouse = mouse;

        __asm__ volatile("hlt");
    }

    while (1) {
        __asm__ volatile("hlt");
    }
}
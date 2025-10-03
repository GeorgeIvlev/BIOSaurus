#pragma once

// PIC ports
#define PIC1_COMMAND    0x20
#define PIC1_DATA       0x21
#define PIC2_COMMAND    0xA0
#define PIC2_DATA       0xA1

#define ICW1_ICW4       0x01
#define ICW1_INIT       0x10
#define ICW4_8086       0x01

// PIC commands
#define PIC_EOI         0x20

#define KEYBOARD_DATA_PORT 0x60
#define KEYBOARD_STATUS_PORT 0x64

void pic_clear_mask(uint8_t irq);
void pic_set_mask(uint8_t irq);
void pic_send_eoi(uint8_t irq);
void pic_init(void);

char keyboard_getchar(void);
void keyboard_init(void);
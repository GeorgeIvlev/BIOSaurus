#include "types.h"
#include "io.h"
#include "pic.h"

static uint16_t pic_mask = 0xFFFF; // All IRQs masked by default

void pic_clear_mask(uint8_t irq) {
    uint16_t port;
    
    if (irq < 8) {
        port = PIC1_DATA;
    } else {
        port = PIC2_DATA;
        irq -= 8;
    }
    
    uint8_t value = inb(port) & ~(1 << irq);
    outb(port, value);
}

void pic_set_mask(uint8_t irq) {
    uint16_t port;
    
    if (irq < 8) {
        port = PIC1_DATA;
    } else {
        port = PIC2_DATA;
        irq -= 8;
    }
    
    uint8_t value = inb(port) | (1 << irq);
    outb(port, value);
}

void pic_send_eoi(uint8_t irq) {
    if (irq >= 8) {
        // Send EOI to slave PIC first
        outb(PIC2_COMMAND, PIC_EOI);
    }
    // Send EOI to master PIC
    outb(PIC1_COMMAND, PIC_EOI);
}

void pic_init(void) {
    // Save masks
    uint8_t mask1 = inb(PIC1_DATA);
    uint8_t mask2 = inb(PIC2_DATA);
    
    // Start initialization sequence (ICW1)
    outb(PIC1_COMMAND, ICW1_INIT | ICW1_ICW4);
    io_wait();
    outb(PIC2_COMMAND, ICW1_INIT | ICW1_ICW4);
    io_wait();
    
    // Set vector offsets (ICW2)
    outb(PIC1_DATA, 32);    // Master PIC starts at interrupt 32
    io_wait();
    outb(PIC2_DATA, 40);    // Slave PIC starts at interrupt 40
    io_wait();
    
    // Tell master about slave (ICW3)
    outb(PIC1_DATA, 4);     // Slave is on IRQ2 (bit 2 = 0x04)
    io_wait();
    outb(PIC2_DATA, 2);     // Slave cascade identity
    io_wait();
    
    // Set 8086 mode (ICW4)
    outb(PIC1_DATA, ICW4_8086);
    io_wait();
    outb(PIC2_DATA, ICW4_8086);
    io_wait();
    
    // Restore saved masks
    outb(PIC1_DATA, mask1);
    outb(PIC2_DATA, mask2);
}
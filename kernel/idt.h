#pragma once

#include "types.h"

// IDT entry structure (16 bytes in 64-bit mode)
typedef struct {
    uint16_t offset_low;    // Offset bits 0-15
    uint16_t selector;      // Code segment selector
    uint8_t  ist;          // Interrupt Stack Table offset (0-7), bits 0-2
    uint8_t  type_attr;    // Type and attributes
    uint16_t offset_mid;    // Offset bits 16-31
    uint32_t offset_high;   // Offset bits 32-63
    uint32_t zero;         // Reserved (must be zero)
} __attribute__((packed)) idt_entry_t;

// IDT pointer structure
typedef struct {
    uint16_t limit;        // Size of IDT - 1
    uint64_t base;         // Base address of IDT
} __attribute__((packed)) idt_ptr_t;

// Initialize the IDT
void idt_init(void);

// Set an IDT gate
void idt_set_gate(uint8_t num, uint64_t handler, uint16_t selector, uint8_t flags);
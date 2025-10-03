#include "idt.h"
#include "isr.h"
#include "memory.h"
#include "pic.h"

// IDT with 256 entries
static idt_entry_t idt[256] __attribute__((aligned(16)));
static idt_ptr_t idtp __attribute__((aligned(16)));

// Set an IDT gate
void idt_set_gate(uint8_t num, uint64_t handler, uint16_t selector, uint8_t flags) {
    idt[num].offset_low = handler & 0xFFFF;
    idt[num].offset_mid = (handler >> 16) & 0xFFFF;
    idt[num].offset_high = (handler >> 32) & 0xFFFFFFFF;
    
    idt[num].selector = selector;
    idt[num].ist = 0;              // No IST for now
    idt[num].type_attr = flags;
    idt[num].zero = 0;
}

// Initialize IDT
void idt_init(void) {
    // Clear IDT
    zero_memory(&idt, sizeof(idt_entry_t) * 256);

    // Set up IDT pointer
    idtp.limit = (sizeof(idt_entry_t) * 256) - 1;
    idtp.base = (uint64_t)&idt;

    // Initialize ISRs (will set gates for first 32 interrupts)
    isr_init();
    
    pic_init();

    // for (int i = 0; i < 16; i++) {
    //     pic_set_mask(i);
    // }

    // Load IDT
    __asm__ volatile("lidt %0" : : "m"(idtp) : "memory");

    // Enable interrupts LAST
    // Disable FPU - prevents coprocessor exceptions
    // uint64_t cr0;
    // __asm__ volatile("movq %%cr0, %0" : "=r"(cr0) : : "memory");
    // cr0 |= (1 << 2); // Set EM bit (Emulate FPU)
    // __asm__ volatile("movq %0, %%cr0" :: "r"(cr0) : "memory");
    __asm__ volatile("mov $0xFF, %al; out %al, $0x21");  // Master PIC
    __asm__ volatile("mov $0xFF, %al; out %al, $0xA1");  // Slave PIC
    __asm__ volatile("sti");
}
#include "types.h"
#include "isr.h"
#include "idt.h"
#include "pic.h"

// Array of custom handlers
static isr_t interrupt_handlers[256] = {0};

// Exception messages
static const char* exception_messages[] = {
    "Division By Zero",
    "Debug",
    "Non Maskable Interrupt",
    "Breakpoint",
    "Overflow",
    "Bound Range Exceeded",
    "Invalid Opcode",
    "Device Not Available",
    "Double Fault",
    "Coprocessor Segment Overrun",
    "Invalid TSS",
    "Segment Not Present",
    "Stack-Segment Fault",
    "General Protection Fault",
    "Page Fault",
    "Reserved",
    "x87 Floating-Point Exception",
    "Alignment Check",
    "Machine Check",
    "SIMD Floating-Point Exception",
    "Virtualization Exception",
    "Control Protection Exception",
    "Reserved", "Reserved", "Reserved", "Reserved", "Reserved", "Reserved",
    "Hypervisor Injection Exception",
    "VMM Communication Exception",
    "Security Exception",
    "Reserved"
};

extern volatile uint16_t* VGA_BUFFER;

static void kernel_panic(const char* msg, registers_t* regs) {
    // Clear screen with red background
    for (int i = 0; i < 80 * 25; i++) {
        if (i > 1919) {
            continue;
        }
        VGA_BUFFER[i] = 0x4F20;  // White on red
    }
    
    // Display panic message
    const char* panic_text = "KERNEL PANIC: ";
    int pos = 0;
    while (*panic_text) {
        VGA_BUFFER[pos++] = 0x4F00 | *panic_text++;
    }
    while (*msg) {
        VGA_BUFFER[pos++] = 0x4F00 | *msg++;
    }
    
    // Display interrupt number and error code on next line
    VGA_BUFFER[80] = 0x4F00 | 'I';
    VGA_BUFFER[81] = 0x4F00 | 'N';
    VGA_BUFFER[82] = 0x4F00 | 'T';
    VGA_BUFFER[83] = 0x4F00 | ':';
    VGA_BUFFER[84] = 0x4F00 | ' ';
    VGA_BUFFER[85] = 0x4F00 | ('0' + (regs->int_no / 10));
    VGA_BUFFER[86] = 0x4F00 | ('0' + (regs->int_no % 10));
    
    // Halt forever
    __asm__ volatile("cli");
    __asm__ volatile("hlt");
    while(1);
}

// Common interrupt handler
void isr_handler(registers_t* regs) {
    // Debug: show interrupt number
    // VGA_BUFFER[1960] = 0x0F49;  // 'I'
    // VGA_BUFFER[1961] = 0x0F00 | ('0' + (regs->int_no / 10));
    // VGA_BUFFER[1962] = 0x0F00 | ('0' + (regs->int_no % 10));

    // int pos = 0;
    // VGA_BUFFER[pos++] = 0x0F49;  // 'I'
    // VGA_BUFFER[pos++] = 0x0F4E;  // 'N'
    // VGA_BUFFER[pos++] = 0x0F54;  // 'T'
    // VGA_BUFFER[pos++] = 0x0F3A;  // ':'
    // VGA_BUFFER[pos++] = 0x0F20;  // ' '
    
    // // Display interrupt number (2 digits)
    // if (regs->int_no < 10) {
    //     VGA_BUFFER[pos++] = 0x0F30;  // '0'
    //     VGA_BUFFER[pos++] = 0x0F00 | ('0' + regs->int_no);
    // } else {
    //     VGA_BUFFER[pos++] = 0x0F00 | ('0' + (regs->int_no / 10));
    //     VGA_BUFFER[pos++] = 0x0F00 | ('0' + (regs->int_no % 10));
    // }
    
    // VGA_BUFFER[pos++] = 0x0F20;  // ' '
    
    // // Display error code (4 hex digits)
    // VGA_BUFFER[pos++] = 0x0F45;  // 'E'
    // VGA_BUFFER[pos++] = 0x0F3A;  // ':'
    // for (int i = 3; i >= 0; i--) {
    //     uint8_t nibble = (regs->err_code >> (i * 4)) & 0xF;
    //     char c = nibble < 10 ? ('0' + nibble) : ('A' + nibble - 10);
    //     VGA_BUFFER[pos++] = 0x0F00 | c;
    // }

    // Check if custom handler exists
    if (interrupt_handlers[regs->int_no] != 0) {
        // VGA_BUFFER[1963] = 0x0F46;  // 'F' - Found handler
        isr_t handler = interrupt_handlers[regs->int_no];
        handler(regs);
        // VGA_BUFFER[1964] = 0x0F44;  // 'D' - Done
    } else {
        // VGA_BUFFER[1965] = 0x0F4E;  // 'N' - No handler
        // No handler - panic for CPU exceptions (0-31)
        if (regs->int_no < 32) {
            kernel_panic(exception_messages[regs->int_no], regs);
        }
    }

    // Send EOI for IRQs
    if (regs->int_no >= 32 && regs->int_no <= 47) {
        pic_send_eoi(regs->int_no - 32);
    }
}

// Install custom handler
void isr_install_handler(uint8_t n, isr_t handler) {
    // VGA_BUFFER[1950] = 0x0F48;  // 'H'
    // VGA_BUFFER[1951] = 0x0F00 | ('0' + (n / 10));
    // VGA_BUFFER[1952] = 0x0F00 | ('0' + (n % 10));    
    interrupt_handlers[n] = handler;
}

// Uninstall handler
void isr_uninstall_handler(uint8_t n) {
    interrupt_handlers[n] = 0;
}

// Initialize ISRs
void isr_init(void) {
    // IDT flags: Present | Ring 0 | 64-bit Interrupt Gate
    uint8_t flags = 0x8E;
    
    // Code segment selector (should match your GDT)
    uint16_t code_seg = 0x08;
    
    // Set gates for CPU exceptions (0-31)
    idt_set_gate(0, (uint64_t)isr0, code_seg, flags);
    idt_set_gate(1, (uint64_t)isr1, code_seg, flags);
    idt_set_gate(2, (uint64_t)isr2, code_seg, flags);
    idt_set_gate(3, (uint64_t)isr3, code_seg, flags);
    idt_set_gate(4, (uint64_t)isr4, code_seg, flags);
    idt_set_gate(5, (uint64_t)isr5, code_seg, flags);
    idt_set_gate(6, (uint64_t)isr6, code_seg, flags);
    idt_set_gate(7, (uint64_t)isr7, code_seg, flags);
    idt_set_gate(8, (uint64_t)isr8, code_seg, flags);
    idt_set_gate(9, (uint64_t)isr9, code_seg, flags);
    idt_set_gate(10, (uint64_t)isr10, code_seg, flags);
    idt_set_gate(11, (uint64_t)isr11, code_seg, flags);
    idt_set_gate(12, (uint64_t)isr12, code_seg, flags);
    idt_set_gate(13, (uint64_t)isr13, code_seg, flags);
    idt_set_gate(14, (uint64_t)isr14, code_seg, flags);
    idt_set_gate(15, (uint64_t)isr15, code_seg, flags);
    idt_set_gate(16, (uint64_t)isr16, code_seg, flags);
    idt_set_gate(17, (uint64_t)isr17, code_seg, flags);
    idt_set_gate(18, (uint64_t)isr18, code_seg, flags);
    idt_set_gate(19, (uint64_t)isr19, code_seg, flags);
    idt_set_gate(20, (uint64_t)isr20, code_seg, flags);
    idt_set_gate(21, (uint64_t)isr21, code_seg, flags);
    idt_set_gate(22, (uint64_t)isr22, code_seg, flags);
    idt_set_gate(23, (uint64_t)isr23, code_seg, flags);
    idt_set_gate(24, (uint64_t)isr24, code_seg, flags);
    idt_set_gate(25, (uint64_t)isr25, code_seg, flags);
    idt_set_gate(26, (uint64_t)isr26, code_seg, flags);
    idt_set_gate(27, (uint64_t)isr27, code_seg, flags);
    idt_set_gate(28, (uint64_t)isr28, code_seg, flags);
    idt_set_gate(29, (uint64_t)isr29, code_seg, flags);
    idt_set_gate(30, (uint64_t)isr30, code_seg, flags);
    idt_set_gate(31, (uint64_t)isr31, code_seg, flags);
    // Keyboard
    idt_set_gate(33, (uint64_t)isr33, code_seg, flags);
    // Mouse
    idt_set_gate(44, (uint64_t)isr44, code_seg, flags);
}
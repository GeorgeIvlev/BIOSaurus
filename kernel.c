#include <stdint.h>
#include <stddef.h>

__attribute__((noreturn))
void _kernel(void) {
    __asm__ volatile(
        // Clear entire screen (2000 characters)
        "movq $0xB8000, %%rdi\n"
        "movw $0x0F20, %%ax\n"      // Space with white on black attribute
        "movl $2000, %%ecx\n"
        "rep stosw\n"
        
        // Write "Hello World!" at top-left
        "movq $0xB8000, %%rax\n"
        "movw $0x0F48, (%%rax)\n"       // 'H'
        "movw $0x0F65, 2(%%rax)\n"      // 'e'
        "movw $0x0F6C, 4(%%rax)\n"      // 'l'
        "movw $0x0F6C, 6(%%rax)\n"      // 'l'
        "movw $0x0F6F, 8(%%rax)\n"      // 'o'
        "movw $0x0F20, 10(%%rax)\n"     // ' '
        "movw $0x0F57, 12(%%rax)\n"     // 'W'
        "movw $0x0F6F, 14(%%rax)\n"     // 'o'
        "movw $0x0F72, 16(%%rax)\n"     // 'r'
        "movw $0x0F6C, 18(%%rax)\n"     // 'l'
        "movw $0x0F64, 20(%%rax)\n"     // 'd'
        "movw $0x0F21, 22(%%rax)\n"     // '!'
        
        "cli\n"
        "1: hlt\n"
        "jmp 1b\n"
        :
        :
        : "rax", "rdi", "rcx", "memory"
    );
}
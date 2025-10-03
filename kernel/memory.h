#pragma once

#include "types.h"

inline void zero_memory(void* dest, size_t n) {
    __asm__ volatile(
        "cld\n\t"
        "rep stosb"
        : "+D"(dest), "+c"(n)
        : "a"(0)
        : "memory"
    );
}

void* memcpy(void* dest, const void* src, size_t n);
void* memset(void* dest, int val, size_t n);
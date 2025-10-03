#pragma once

#include "types.h"

typedef struct {
    int32_t x;
    int32_t y;
    uint8_t buttons;  // Bit 0: Left, Bit 1: Right, Bit 2: Middle
} mouse_state_t;

void mouse_init(void);
mouse_state_t mouse_get_state(void);
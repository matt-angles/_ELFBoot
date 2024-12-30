#include <stdint.h>
#include "vga_text.h"

/* VGA Mode 03h (BIOS) */
#define VGA_BUFFER (uint16_t*) 0x000B8000
#define VGA_WIDTH 80
#define VGA_HEIGHT 25

uint8_t vgaColor;
uint16_t cursor;

void vga_setColour(enum VgaColor bg, enum VgaColor fg)
{
    vgaColor = (bg << 4) + fg;
}

void vga_clear(void)
{
    for (uint16_t p = 0; p < VGA_WIDTH*VGA_HEIGHT; p++)
        *(VGA_BUFFER+p) = vgaColor << 8;
    cursor = 0;
}

void vga_putc(char c)
{
    if (cursor == VGA_HEIGHT*VGA_WIDTH)
    {
        vga_clear();
        cursor = 0;
    }

    /* NOTE: Useful characters such as BEL, BS, HT, FF, CR are not handled. */
    if (c == '\n')
        cursor = ((cursor + VGA_WIDTH - 1) / VGA_WIDTH) * VGA_WIDTH;
    else if (c > 31)
        *(VGA_BUFFER+cursor++) = (vgaColor << 8) + c;
}

void vga_puts(char* s)
{
    while (*s)
        vga_putc(*s++);
}
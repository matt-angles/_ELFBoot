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

char* itoa(unsigned long value, char* str)
{
    int i = 0;
    while (value != 0)
    {
        str[i] = value%10 + '0';
        value /= 10;
        i++;
    }
    str[i] = '\0';
    return str;
}

void vga_putul(unsigned long value)
{
    char iBuf[13];
    if (value == 0)
        vga_putc('0');
    else
        vga_puts(itoa(value, iBuf));
    return;
}
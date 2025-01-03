#include <stdint.h>
#include <stdbool.h>
#include "io.h"

#include "vga.h"

/* I/O ports for VGA registers */
#define GRAPHREG_INDEX  0x3CE
#define GRAPHREG_DATA   0x3CF
#define SEQREG_INDEX    0x3C4
#define SEQREG_DATA     0x3C5
#define ATTRREG_INDEXW  0x3C0
#define ATTRREG_READ    0x3C1
#ifdef VGA_MONOCHROME   // NOTE: runtime-defined would be better
    #define CRTREG_INDEX   0x3B4
    #define CRTREG_DATA    0x3B5
#else
    #define CRTREG_INDEX   0x3D4
    #define CRTREG_DATA    0x3D5
#endif
#define MISCREG_R       0x3CC
#define MISCREG_W       0x3C2
enum GraphReg {
    FILL_SET,
    FILL_ENABLE,
    COLORMASK,
    OPERATION,
    READMAP,
    MODE,
    MISC,
    COLORMASK_SET,
    BITMASK
};
enum SeqReg {
    RESET,
    CLOCKING,
    WRITEMAP,
    CHARMAP,
    MEMCONFIG
};
enum AttrReg {
    P0, P1, P2, P3, P4, P5, P6, P7, P8, P9, PA, PB, PC, PD, PE, PF,
    ATTRCONFIG,
    OVERSCAN_COLOR,
    COLORMAP,
    PIXELSHIFT,
    COLORSELECT
};
enum CrtReg {
    HORIZONTAL_TOTAL,
    HORIZONTAL_DISPLAY,
    HORIZONTAL_BLANKING_L, HORIZONTAL_BLANKING_H,
    HORIZONTAL_RETRACE_L, HORIZONTAL_RETRACE_H,
    VERTICAL_TOTAL,
    OVERFLOW,
    ROW_SCANLINE,
    MAX_SCANLINE,
    CURSOR_H, CURSOR_L,
    START_ADDRESS_H, START_ADDRESS_L,
    CURSOR_LOCATION_H, CURSOR_LOCATION_L,
    VERTICAL_RETRACE_L, VERTICAL_RETRACE_H,
    VERTICAL_DISPLAY,
    OFFSET,
    UNDERLINE,
    VERTICAL_BLANKING_L, VERTICAL_BLANKING_H,
    CRTC_CONTROL,
    LINE_COMPARE
};

/* TEXT mode constants */
#define TEXT_MMAP (uint16_t*) 0x000B8000

struct VgaInfo {
    enum VgaMode mode;
    uint16_t* mmap;
    uint16_t resolution;
    bool tColor;
};
struct VgaInfo vgaInfo;


static uint8_t read_attrreg(enum AttrReg index)
// From SeaBIOS VGA implementation
{
    inb(0x3DA);
    uint8_t orig = inb(ATTRREG_INDEXW);
    outb(ATTRREG_INDEXW, index);
    uint8_t v = inb(ATTRREG_READ);
    inb(0x3DA);
    outb(ATTRREG_INDEXW, orig);
    return v;
}

static void write_attrreg(enum AttrReg index, uint8_t value)
// From SeaBIOS VGA implementation
{
    inb(0x3DA);
    uint8_t orig = inb(ATTRREG_INDEXW);
    outb(ATTRREG_INDEXW, index);
    outb(ATTRREG_INDEXW, value);
    outb(ATTRREG_INDEXW, orig);
}

int vga_set_mode(enum VgaMode mode)
/* VGA presets */
{
    vgaInfo.mode = mode;
    // NOTE: Turn off display before altering registers

    outb(CRTREG_INDEX, VERTICAL_RETRACE_H);
    outb(CRTREG_DATA, 0);   // Unlock CRT registers
    if (mode == TEXT)
    {
        vgaInfo.mmap = TEXT_MMAP;
        vgaInfo.resolution = 80*25*2;
        
        // NOTE: Quite ugly. Use a port,index,value table (except for ATTRREG)
        outb(GRAPHREG_INDEX, FILL_ENABLE);
        outb(GRAPHREG_DATA, 0);
        outb(GRAPHREG_INDEX, OPERATION);
        outb(GRAPHREG_DATA, 0);
        outb(GRAPHREG_INDEX, READMAP);
        outb(GRAPHREG_DATA, 0);
        outb(GRAPHREG_INDEX, MODE);
        outb(GRAPHREG_DATA, 0b00010000);
        outb(GRAPHREG_INDEX, MISC);
        outb(GRAPHREG_DATA, 0b1110);
        outb(GRAPHREG_INDEX, BITMASK);
        outb(GRAPHREG_DATA, 255);

        outb(SEQREG_INDEX, CLOCKING);
        outb(SEQREG_DATA, 0);
        outb(SEQREG_INDEX, WRITEMAP);
        outb(SEQREG_DATA, 0b0011);
        outb(SEQREG_INDEX, CHARMAP);
        outb(SEQREG_DATA, 0);
        outb(SEQREG_INDEX, MEMCONFIG);
        outb(SEQREG_DATA, 0b0010);

        outb(CRTREG_INDEX, HORIZONTAL_RETRACE_L);
        outb(CRTREG_DATA, 0x55);
        outb(CRTREG_INDEX, HORIZONTAL_RETRACE_H);
        outb(CRTREG_DATA, 0x81);
        outb(CRTREG_INDEX, VERTICAL_TOTAL);
        outb(CRTREG_DATA, 0xBF);
        outb(CRTREG_INDEX, OVERFLOW);
        outb(CRTREG_DATA, 0x1F);
        outb(CRTREG_INDEX, MAX_SCANLINE);
        outb(CRTREG_DATA, 0x4F);
        outb(CRTREG_INDEX, VERTICAL_RETRACE_L);
        outb(CRTREG_DATA, 0x9C);
        outb(CRTREG_INDEX, VERTICAL_RETRACE_H);
        outb(CRTREG_DATA, 0x0E);
        outb(CRTREG_INDEX, VERTICAL_DISPLAY);
        outb(CRTREG_DATA, 0x8F);
        outb(CRTREG_INDEX, UNDERLINE);
        outb(CRTREG_DATA, 0x1F);
        outb(CRTREG_INDEX, VERTICAL_BLANKING_L);
        outb(CRTREG_DATA, 0x96);
        outb(CRTREG_INDEX, VERTICAL_BLANKING_H);
        outb(CRTREG_DATA, 0xB9);
        outb(CRTREG_INDEX, MODE);
        outb(CRTREG_DATA, 0xA3);

        outb(MISCREG_W, 0x67);

        // Attribute registers preset (finicky)
        write_attrreg(ATTRCONFIG, 0b1100);
        write_attrreg(OVERSCAN_COLOR, 0);
        write_attrreg(COLORMAP, 0b1111);
        write_attrreg(PIXELSHIFT, 0x08);
        write_attrreg(COLORSELECT, 0);

        //vgat_load_font();
    }
    else
        return -1;

    outb(CRTREG_INDEX, VERTICAL_RETRACE_H);
    outb(CRTREG_DATA, inb(CRTREG_DATA) | 0x80); // Lock CRT registers
    return 0;
}


int vgat_put(uint8_t row, uint8_t column, char ch, uint8_t color)
{
    if (vgaInfo.mode != TEXT)
        return -1;
    if (vgaInfo.tColor) // Disable optimizations
    {
        outb(GRAPHREG_INDEX, MODE);
        outb(GRAPHREG_DATA, 0b10000);
        outb(GRAPHREG_INDEX, MISC);
        outb(GRAPHREG_DATA, 0b1110);
        outb(SEQREG_INDEX, MEMCONFIG);
        outb(SEQREG_DATA, 0b0010);
        outb(SEQREG_INDEX, WRITEMAP);
        outb(SEQREG_DATA, 0b0011);

        vgaInfo.tColor = false;
    }
    if (row > 24 || column > 79)
        return 1;

    uint16_t offset = row*80 + column;
    *(TEXT_MMAP+offset) = (color << 8) + ch;
    return 0;
}

void vgat_setcolor(uint8_t color)
/* Optimize writing without changing colors
   by pre-writing on the attribute plane and disabling it */
{
    // Disable Odd/Even addressing
    outb(GRAPHREG_INDEX, MODE);
    outb(GRAPHREG_DATA, 0);
    outb(GRAPHREG_INDEX, MISC);
    outb(GRAPHREG_DATA, 0b1100);
    outb(SEQREG_INDEX, MEMCONFIG);
    outb(SEQREG_DATA, 0b0110);

    outb(SEQREG_INDEX, WRITEMAP);
    outb(SEQREG_DATA, 0b0010);      // Write to color plane

    // NOTE: vga_fill function isn't general enough!
    for (int i = 0; i < 80*25; i++)
        *((uint8_t*) TEXT_MMAP + i) = color;

    outb(SEQREG_INDEX, WRITEMAP);
    outb(SEQREG_DATA, 0b0001);      // Write to character plane

    vgaInfo.tColor = true;
}

int vgat_putf(uint8_t row, uint8_t column, char ch)
/* Write directly to the character plane */
{
    if (vgaInfo.mode != TEXT || !vgaInfo.tColor)
        return -1;
    if (row > 24 || column > 79)
        return 1;
    
    uint16_t offset = row*80 + column;
    *((uint8_t*) TEXT_MMAP+offset) = ch;
    return 0;
}

void vgat_cursor_toggle(bool enabled)
{
    outb(CRTREG_INDEX, CURSOR_H);
    uint8_t val = enabled ? inb(CRTREG_DATA) & ~(1 << 5) : inb(CRTREG_DATA) | (1 << 5);
    outb(CRTREG_DATA, val);
    return;
}

int vgat_cursor_move(uint8_t row, uint8_t column)
{
    if (row > 24 || column > 79)
        return 1;

    uint16_t offset = row*80 + column;
    outb(CRTREG_INDEX, CURSOR_LOCATION_L);
    outb(CRTREG_DATA, offset);
    outb(CRTREG_INDEX, CURSOR_LOCATION_H);
    outb(CRTREG_DATA, offset >> 8);
    return 0;
}

int vgat_underline(uint8_t row, uint8_t column, bool enabled)
{
    //TODO
}

int vgat_blink(uint8_t row, uint8_t column, bool enabled)
{
    //TODO
}

void vgat_load_font()
{
    //TODO
}


void vga_display(char* frame)
/* Disable screen while rendering to maximize bandwidth */
{
    outb(SEQREG_INDEX, CLOCKING);
    outb(SEQREG_DATA, 0b100000);        // Screen Disable

    for (int i = 0; i < vgaInfo.resolution; i++)
        *((uint8_t*) vgaInfo.mmap+i) = *(frame+i);

    outb(SEQREG_DATA, 0b000000);
}

int vga_fill(char ch, uint8_t color)
/* Taking advantage of VGA's write mode 01 to fast fill */
{
    if (vgaInfo.mode == TEXT)
    {
        vgat_put(0, 0, ch, color);
    }
    else
        return -1;
    
    volatile uint32_t _ = *(vgaInfo.mmap);  // Load latch register
    (void) _;                               // (Suppress _ warning)
    outb(GRAPHREG_INDEX, MODE);
    outb(GRAPHREG_DATA, 0b00010001);        // Go into write mode 01
    vga_display((char*) 0);                 // Write from latch. Parameter doesn't matter.
    outb(GRAPHREG_DATA, 0b00010000);
    return 0;
}

#include <stdint.h>
#include <stdbool.h>
#include "asm/io.h"

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

#define TEXT_MMAP (uint16_t*) 0x000B8000
#define TEXT_PRESET_SIZE 22

#define COLOR256_MMAP (uint8_t*) 0x000A0000
#define COLOR256_PRESET_SIZE 21

static struct VgaInfo {
    enum VgaMode mode;
    uint8_t* mmap;
    uint16_t resolution;
    bool tColor;
} vgaInfo;
typedef struct RegisterCfg {
    uint16_t port;
    uint8_t index;
    uint8_t value;
} RegisterCfg;
static struct RegisterCfg textPreset[TEXT_PRESET_SIZE] = 
{
    {GRAPHREG_INDEX, FILL_ENABLE, 0},
    {GRAPHREG_INDEX, OPERATION, 0},
    {GRAPHREG_INDEX, READMAP, 0},
    {GRAPHREG_INDEX, MODE, 0b00010000},
    {GRAPHREG_INDEX, MISC, 0b1110},
    {GRAPHREG_INDEX, BITMASK, 255},
    {SEQREG_INDEX, CLOCKING, 0},
    {SEQREG_INDEX, WRITEMAP, 0b0011},
    {SEQREG_INDEX, CHARMAP, 0},
    {SEQREG_INDEX, MEMCONFIG, 0b0010},
    {CRTREG_INDEX, HORIZONTAL_RETRACE_L, 85},
    {CRTREG_INDEX, HORIZONTAL_RETRACE_H, 0x81},
    {CRTREG_INDEX, VERTICAL_TOTAL, 191},
    {CRTREG_INDEX, OVERFLOW, 0x1F},
    {CRTREG_INDEX, MAX_SCANLINE, 79},
    {CRTREG_INDEX, VERTICAL_RETRACE_L, 0x9C},
    {CRTREG_INDEX, VERTICAL_RETRACE_H, 0x0E},
    {CRTREG_INDEX, VERTICAL_DISPLAY, 0x8F},
    {CRTREG_INDEX, UNDERLINE, 0x1F},
    {CRTREG_INDEX, VERTICAL_BLANKING_L, 0x96},
    {CRTREG_INDEX, VERTICAL_BLANKING_H, 0xB9},
    {CRTREG_INDEX, CRTC_CONTROL, 0b10100011}
};
static struct RegisterCfg color256Preset[COLOR256_PRESET_SIZE] = 
{
    {GRAPHREG_INDEX, FILL_ENABLE, 0},
    {GRAPHREG_INDEX, OPERATION, 0},
    {GRAPHREG_INDEX, READMAP, 0},
    {GRAPHREG_INDEX, MODE, 0b01000000},
    {GRAPHREG_INDEX, MISC, 0b0101},
    {GRAPHREG_INDEX, BITMASK, 255},
    {SEQREG_INDEX, CLOCKING, 1},
    {SEQREG_INDEX, WRITEMAP, 0b1111},
    {SEQREG_INDEX, MEMCONFIG, 0b1110},
    {CRTREG_INDEX, HORIZONTAL_RETRACE_L, 0x54},
    {CRTREG_INDEX, HORIZONTAL_RETRACE_H, 0x80},
    {CRTREG_INDEX, VERTICAL_TOTAL, 0xBF},
    {CRTREG_INDEX, OVERFLOW, 0x1F},
    {CRTREG_INDEX, MAX_SCANLINE, 0x41},
    {CRTREG_INDEX, VERTICAL_RETRACE_L, 0x9C},
    {CRTREG_INDEX, VERTICAL_RETRACE_H, 0x0E},
    {CRTREG_INDEX, VERTICAL_DISPLAY, 0x8F},
    {CRTREG_INDEX, UNDERLINE, 0x40},
    {CRTREG_INDEX, VERTICAL_BLANKING_L, 0x96},
    {CRTREG_INDEX, VERTICAL_BLANKING_H, 0xB9},
    {CRTREG_INDEX, CRTC_CONTROL, 0b10100011}
};


/*
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
*/

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
        vgaInfo.mmap = (uint8_t*) TEXT_MMAP;
        vgaInfo.resolution = 80*25*2;

        for (int i = 0; i < TEXT_PRESET_SIZE; i++)
        {
            outb(textPreset[i].port, textPreset[i].index);
            outb(textPreset[i].port+1, textPreset[i].value);
        }

        // Attribute registers preset (finicky)
        write_attrreg(ATTRCONFIG, 0b0100);
        write_attrreg(OVERSCAN_COLOR, 0);
        write_attrreg(COLORMAP, 0b1111);
        write_attrreg(PIXELSHIFT, 0x08);
        write_attrreg(COLORSELECT, 0);

        outb(MISCREG_W, 0x67);

        //vgat_load_font();
        vga_fill(0);
    }
    else if (mode == COLOR256)
    {
        vgaInfo.mmap = COLOR256_MMAP;
        vgaInfo.resolution = 320*200;

        for (int i = 0; i < COLOR256_PRESET_SIZE; i++)
        {
            outb(color256Preset[i].port, color256Preset[i].index);
            outb(color256Preset[i].port+1, color256Preset[i].value);
        }

        write_attrreg(ATTRCONFIG, 0b01000001);
        write_attrreg(PIXELSHIFT, 0);

        outb(MISCREG_W, 0b01100011);
        //vga_fill
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

void vgat_load_font()
{
    //TODO
}


int vgac_put(uint16_t x, uint16_t y, uint8_t color)
{
    if (0 && vgaInfo.mode != COLOR256)
        return -1;
    if (x > 320 || y > 200)
        return 1;

    uint16_t offset = y * 320 + x;
    *(COLOR256_MMAP+offset) = color;
    return 0;
}


void vga_display(char* frame)
/* Disable screen while rendering to maximize bandwidth */
{
    outb(SEQREG_INDEX, CLOCKING);
    outb(SEQREG_DATA, inb(SEQREG_DATA) | 0x80);        // Screen Disable

    for (int i = 0; i < vgaInfo.resolution; i++)
        *(vgaInfo.mmap+i) = *(frame+i);

    outb(SEQREG_DATA, inb(SEQREG_DATA) & ~0x80);
}

int vga_fill(char color)
/* Taking advantage of VGA's write mode 01 to fast fill */
{
    if (vgaInfo.mode == TEXT)
    {
        vgat_put(0, 0, 0, color);
    }
    else if (vgaInfo.mode == COLOR256)
    {
        // Write mode 01 optimisation isn't possible in non-planar modes
        // According to personal experimentation and ChatGPT, I should say
        
        // NOTE: in theory, it should be completly possible to go in a planar mode
        // and fill the planes this way
        outb(SEQREG_INDEX, CLOCKING);
        outb(SEQREG_DATA, inb(SEQREG_DATA) | 0x80);
        for (int y = 0; y < 200; y++)
            for (int x = 0; x < 320; x++)
                vgac_put(x, y, color);
        outb(SEQREG_DATA, inb(SEQREG_DATA) & ~0x80);
        return 0;
    }
    else
        return -1;
    
    volatile uint32_t _ = *(vgaInfo.mmap);  // Load latch register
    (void) _;                               // (Suppress _ warning)
    outb(GRAPHREG_INDEX, MODE);
    outb(GRAPHREG_DATA, inb(GRAPHREG_DATA) | 0x01);     // Go into write mode 01
    vga_display((char*) 0);                             // Write from latch. Parameter doesn't matter.
    outb(GRAPHREG_DATA, inb(GRAPHREG_DATA) & ~0x01);
    return 0;
}

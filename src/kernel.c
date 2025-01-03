#include <stdint.h>
#include "vga.h"

void puts(uint8_t row, uint8_t column, char* str, uint8_t color)
{
    while (*(str))
        vgat_put(row, column++, *str++, color);
}

void main(void)
{
    vga_set_mode(TEXT);
    vgat_cursor_toggle(0);

    char text0[] = " Windows ";
    char text1[] = "A fatal exception OE has occurred at 0028:C004D86F in VXD VFAT(01) +";
    char text2[] = "0000B897. The current application will be terminated.";
    char text3[] = "* Press any key to terminate the current application";
    char text4[] = "* Press CTRL+ALT+DEL again to restart your computer. You will";
    char text5[] = "  lose any unsaved information in all applications.";
    char text6[] = "Press any key to continue";
    vga_fill(0, 0x1F);
    puts(7, 35, text0, 0xF1);
    puts(9, 6, text1, 0x1F);
    puts(10, 6, text2, 0x1F);
    puts(12, 6, text3, 0x1F);
    puts(13, 6, text4, 0x1F);
    puts(14, 6, text5, 0x1F);
    puts(16, 27, text6, 0x1F);
    return;
}
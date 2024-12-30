#include <stdint.h>

#include "vga_text.h"

void main(void)
{
    vga_clear();
    for (enum VgaColor bg = BLACK; bg < WHITE; bg++)
        for (enum VgaColor fg = BLACK; fg < WHITE; fg++)
        {
            vga_setColour(bg, fg);
            vga_putc(' ');
        }

    vga_setColour(BLACK, WHITE);
    vga_puts("\nString Quintet in E Major, Op. 11 No. 5, G 275: III. Minuetto\n");
    return;
}
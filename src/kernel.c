#include <stdint.h>

void main(void)
{
    uint16_t* vga = (uint16_t*) 0xB8000;

    char s[] = "Hello World!";
    for (int i = 0; s[i] != 0; i++)
    {
        *vga = (0x0F << 8) + s[i];
        vga++;
    }
    return;
}
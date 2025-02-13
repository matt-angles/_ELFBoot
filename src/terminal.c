#include <stdint.h>
#include <stdarg.h>
#include "vga.h"

#include "terminal.h"

static struct ttyInfo
{
    uint8_t color;
    uint8_t cursorX;
    uint8_t cursorY;
} tty;


static int itoa(long value, unsigned int radix, int unsig, char *buffer)
// From mini-printf by mludvig
{
    char *pbuffer = buffer;
    int	negative = 0;
    int	i, len;

    /* No support for unusual radixes */
    if (radix > 16)
        return 0;

    if (value < 0 && !unsig)
    {
        negative = 1;
        value = -value;
    }

    /* This builds the string back to front ... */
    do
    {
        int digit = value % radix;
        *(pbuffer++) = (digit < 10 ? '0' + digit : 'a' + digit - 10);
        value /= radix;
    } while (value > 0);

    if (negative)
        *(pbuffer++) = '-';
    *(pbuffer) = '\0';

    /* ... now we reverse it */
    len = (pbuffer - buffer);
    for (i = 0; i < len / 2; i++) {
        char j = buffer[i];
        buffer[i] = buffer[len-i-1];
        buffer[len-i-1] = j;
    }

    return len;
}

void tty_init(uint8_t color)
{
    tty.color = color;
    tty.cursorX = 0;
    tty.cursorY = 0;

    vga_set_mode(TEXT);
    vgat_setcolor(tty.color);
    vgat_cursor_toggle(1);
    vgat_cursor_move(0, 0);
}

void tty_clear(void)
{
    vga_fill(tty.color);     // NOTE: disables 1-plane mode
    vgat_setcolor(tty.color);
    tty.cursorX = tty.cursorY = 0;
}

char tty_putc(char c)
{
    if (tty.cursorX >= 80)
    {
        tty.cursorY++;
        tty.cursorX = 0;
    }
    if (tty.cursorY >= 25)
        tty_clear();

    // NOTE: Useful characters such as BEL, BS, HT, LF, FF or CR are not handled
    if (c == '\n')
    {
        tty.cursorY++;
        tty.cursorX = 0;
    }
    else if (c > 31)
        vgat_putf(tty.cursorY, tty.cursorX, c);
    vgat_cursor_move(tty.cursorY, tty.cursorX);
    tty.cursorX++;

    return c;
}

void tty_puts(char* s)
{
    while (*s)
    {
        tty_putc(*s++);
    }
}

void tty_printf(char* format, ...)
{
    va_list argv;
    va_start(argv, format);

    while (*format)
    {
        if (*format == '%')
        {
            char iBuf[11];      // Largest 32 bit number is 10 digits
            switch (*(++format))
            {
            case 'c':
                tty_putc((char) va_arg(argv, int));
                break;
            case 's':
                tty_puts(va_arg(argv, char*));
                break;
            case 'u':
                itoa(va_arg(argv, int), 10, 1, iBuf);
                tty_puts(iBuf);
                break;
            case 'd':
            case 'i':
                itoa(va_arg(argv, int), 10, 0, iBuf);
                tty_puts(iBuf);
                break;
            case 'b':
            case 'B':
                tty_puts("0b");
                itoa(va_arg(argv, int), 2, 1, iBuf);
                tty_puts(iBuf);
                break;
            case 'x':
            case 'X':
                tty_puts("0x");
                itoa(va_arg(argv, int), 16, 1, iBuf);
                tty_puts(iBuf);
                break;
            case 'n':
                break;
            case '%':
                tty_putc('%');
                break;
            }
            format++;
        }
        else
            tty_putc(*format++);
    }

    va_end(argv);
}

unsigned int tty_tell(void)
{
    return tty.cursorY*80 + tty.cursorX;
}

int tty_seek(unsigned int offset)
{
    if (offset > 80*25)
        return -1;
    
    tty.cursorY = offset / 80;
    tty.cursorX = offset % 80;
    return 0;
}

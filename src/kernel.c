#include "terminal.h"

void main(void)
{
    tty_init(0x0F);
    tty_printf("> ");
    return;
}
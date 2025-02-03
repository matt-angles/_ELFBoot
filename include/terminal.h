#ifndef H_TERMINAL
#define H_TERMINAL

#include <stdint.h>
#include <stdarg.h>

/* Initialize the terminal */
void tty_init(uint8_t color);

/* Clear the terminal screen */
void tty_clear(void);

/* Output a printable ASCII character */
char tty_putc(char c);

/* Output a string */
void tty_puts(char* c);

/* Output a formatted string */
void tty_printf(char* format, ...);

/* Return the current absolute cursor position */
unsigned int tty_tell(void);

/* Set the cursor at a specific offset */
int tty_seek(unsigned int offset);

#endif
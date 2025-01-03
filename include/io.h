#ifndef H_IO
#define H_IO

#include <stdint.h>

/* Read from I/O port (IN instruction) */
uint8_t inb(uint16_t port);
uint16_t inw(uint16_t port);
uint32_t indw(uint16_t port);

/* Write to I/O port (OUT instruction) */
void outb(uint16_t port, uint8_t value);
void outw(uint16_t port, uint16_t value);
void outdw(uint16_t port, uint32_t value);

#endif
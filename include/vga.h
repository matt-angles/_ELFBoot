#ifndef H_VGA
#define H_VGA

#include <stdint.h>
#include <stdbool.h>

/* Select a VGA preset between 3 supported modes */
enum VgaMode {OFF, TEXT, COLOR16, COLOR256};
int vga_set_mode(enum VgaMode mode);

// NOTE: TEXT mode colors have to be defined manually :/


// TEXT mode only functions
/* Put a character on the screen */
int vgat_put(uint8_t row, uint8_t column, char ch, uint8_t color);

/* Set a constant color to use with vgat_putf */
int vgat_setcolor(uint8_t color);

/* Put a character on the screen without specifying color.
   vgat_setcolor must be called before. if used, vgat_put must be
   called before vgat_setcolor, otherwise optimizations would be disabled */
int vgat_putf(uint8_t row, uint8_t column, char ch);

/* Toggle the cursor */
void vgat_cursor_toggle(bool enabled);

/* Move the cursor in a specified position */
int vgat_cursor_move(uint8_t row, uint8_t column);

/* Underline a character */
int vgat_underline(uint8_t row, uint8_t column, bool enabled);

/* Set the blinking state of a character */
int vgat_blink(uint8_t row, uint8_t column, bool enabled);

/* TODO: Not implemented! */
void vgat_load_font();


// ALL modes functions
/* Render a full frame on screen */
void vga_display(char* frame);

/* Fill the screen with a specified value */
int vga_fill(char ch, uint8_t color);

#endif
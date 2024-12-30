#ifndef H_VGA_TEXT
#define H_VGA_TEXT

enum VgaColor {BLACK, BLUE, GREEN, CYAN, RED, PURPLE, BROWN, GRAY, DARK_GRAY,
               LIGHT_BLUE, LIGHT_GREEN, LIGHT_CYAN, LIGHT_RED, LIGHT_PURPLE,
               YELLOW,WHITE};

/* Set the current background and foreground color. */
void vga_setColour(enum VgaColor bg, enum VgaColor fg);

/* Fill the screen with the background color, and reset the cursor. */
void vga_clear(void);

/* Insert character at the cursor. Standard ASCII only. */
void vga_putc(char c);

/* Insert character string at the cursor, using putc. */
void vga_puts(char* s);

#endif
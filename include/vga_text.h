#ifndef H_VGA_TEXT
#define H_VGA_TEXT

enum VgaColor {BLACK, BLUE, GREEN, CYAN, RED, PURPLE, BROWN, GRAY, DARK_GRAY,
               LIGHT_BLUE, LIGHT_GREEN, LIGHT_CYAN, LIGHT_RED, LIGHT_PURPLE,
               YELLOW,WHITE};

void vga_setColour(enum VgaColor bg, enum VgaColor fg);
void vga_clear(void);
void vga_putc(char c);
void vga_puts(char* s);
void vga_putul(unsigned long value);

#endif
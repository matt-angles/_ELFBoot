ENTRY(main)
SECTIONS
{
	. = 0x201000;
	.text :
	{
		*(.text)
	}
    .rodata :
	{
		*(.rodata)
	}
    .data :
	{
		*(.data)
	}
    .bss :
	{
		*(COMMON)
		*(.bss)
	}
}

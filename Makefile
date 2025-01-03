# Crude Makefile to build the OS and manually install
# it on a virtual drive (in raw image format)
# Dependencies: qemu, gcc-cross, binutils-cross, nasm, coreutils, xxd, awk

# If you change this, re-create part_table.txt (fdisk -H16)
DISK_SIZE=64M
ELF_ADDRESS=$(shell echo $$((512*2048)))

CC := `realpath ./cross/bin/i686-elf-gcc`
CFLAGS := -ffreestanding -O2 -Wall -Wextra -std=gnu99 -Iinclude/
LDFLAGS := -T src/link.ld -ffreestanding -nostdlib -lgcc -O2
NASM_OPTS := -Ox -Wall -Werror -w-reloc

OBJECTS := obj/kernel.o obj/io.o obj/vga.o obj/vga_text.o

bin/acceptableOS.img: bin/kernel.bin boot/loader.bin boot/boot.bin bin/part_table.bin
	@qemu-img create bin/acceptableOS.img $(DISK_SIZE)
	dd if=boot/boot.bin of=bin/acceptableOS.img conv=notrunc status=none
	dd if=bin/part_table.bin of=bin/acceptableOS.img oflag=seek_bytes seek=446 conv=notrunc status=none
	dd if=boot/loader.bin of=bin/acceptableOS.img oflag=seek_bytes seek=512 conv=notrunc status=none
	dd if=bin/kernel.bin of=bin/acceptableOS.img oflag=seek_bytes seek=$(ELF_ADDRESS) conv=notrunc status=none

obj/%.o: src/%.c
	$(CC) -c $(CFLAGS) -o $@ $^

obj/%.o: src/%.nasm
	nasm $(NASM_OPTS) -f elf -o $@ $^

bin/kernel.bin: $(OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $^

boot/loader.bin: boot/loader.nasm
	macros="-DELF_SIZE=`wc -c < bin/kernel.bin`"; \
	nasm $(NASM_OPTS) $$macros -f bin -o $@ $^

boot/boot.bin: boot/boot.nasm
	macros="-DLOADER_SIZE=`wc -c < boot/loader.bin` \
			-DLOADER_CHECK=`xxd -e -l 4 boot/loader.bin | awk '{printf \"0x\"$$2}'`"; \
	nasm $(NASM_OPTS) $$macros -f bin -o $@ $^

bin/part_table.bin: bin/part_table.txt
	cd bin; xxd -r -p part_table.txt part_table.bin

.PHONY: clean
clean:
	rm -f ./bin/acceptableOS.img
	find . -type f -name '*.bin' -delete
	find . -type f -name '*.o' -delete

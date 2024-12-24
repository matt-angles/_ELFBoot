# Crude Makefile to build the OS and manually install
# it on a virtual drive (in raw image format)
# Dependencies: qemu, nasm, coreutils, xxd, awk

# If you change this, re-create part_table.txt (fdisk -H16)
DISK_SIZE=64M

NASM_OPTS := -Ox -Wall -Werror -w-reloc

bin/acceptableOS.img: boot/loader.bin boot/boot.bin bin/part_table.bin
	@qemu-img create bin/acceptableOS.img $(DISK_SIZE)
	dd if=boot/boot.bin of=bin/acceptableOS.img conv=notrunc status=none
	dd if=bin/part_table.bin of=bin/acceptableOS.img oflag=seek_bytes seek=446 conv=notrunc status=none
	dd if=boot/loader.bin of=bin/acceptableOS.img oflag=seek_bytes seek=512 conv=notrunc status=none
# Write the kernel at the beginning of your bootable partition

bin/part_table.bin: bin/part_table.txt
	cd bin; xxd -r -p part_table.txt part_table.bin

boot/loader.bin: boot/loader.nasm
	nasm $(NASM_OPTS) -f bin -o $@ $^

boot/boot.bin: boot/boot.nasm
	macros="-DLOADER_SIZE=`wc -c < boot/loader.bin` \
			-DLOADER_CHECK=`xxd -e -l 4 boot/loader.bin | awk '{printf \"0x\"$$2}'`"; \
	nasm $(NASM_OPTS) $$macros -f bin -o $@ $^

.PHONY: clean
clean:
	rm -f ./bin/acceptableOS.img
	rm -f ./bin/part_table.bin
	rm -f ./boot/loader.bin
	rm -f ./boot/boot.bin
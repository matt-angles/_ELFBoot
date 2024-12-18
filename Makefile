# Crude Makefile to build the OS and manually install
# it on a virtual drive (in raw image format)
# Dependencies: qemu, nasm, dd, xxd

# If you change this, re-create part_table.txt (-H16)
DISK_SIZE=64M

NASM_TGTS := boot/boot.bin boot/loader.bin
NASM_OPTS := -Ox -Wall -Werror -w-reloc

bin/acceptableOS.img: $(NASM_TGTS) bin/part_table.bin
	@qemu-img create bin/acceptableOS.img $(DISK_SIZE)
	dd if=boot/boot.bin of=bin/acceptableOS.img conv=notrunc status=none
	dd if=bin/part_table.bin of=bin/acceptableOS.img oflag=seek_bytes seek=446 conv=notrunc status=none
	dd if=boot/loader.bin of=bin/acceptableOS.img oflag=seek_bytes seek=512 conv=notrunc status=none

bin/part_table.bin: bin/part_table.txt
	cd bin; xxd -r -p part_table.txt part_table.bin

$(NASM_TGTS): %.bin: %.nasm
	nasm $(NASM_OPTS) -f bin -o $@ $^

.PHONY: clean
clean:
	rm -f ./bin/acceptableOS.img
	rm -f ./bin/part_table.bin
	rm -f $(NASM_TGTS)
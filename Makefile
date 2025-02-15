# Makefile to build the OS and flash it on a raw image file
# Dependencies: qemu, gcc-cross, binutils-cross, nasm, coreutils, xxd, awk, python3

# !* Modify parameters here *!
DISK_SIZE=64M


CC := $(shell realpath ./cross/bin/x86_64-elf-gcc)
CFLAGS := -Iinclude -ffreestanding -mgeneral-regs-only -O2 -Wall -Wextra
LDFLAGS := -T src/link.ld -ffreestanding -nostdlib -lgcc -O2
NASM_FLAGS := -Ox -Wall -Werror -w-reloc

SRCS := $(shell find src -name '*.c' -or -name '*.nasm')
OBJECTS := $(patsubst src/%, obj/%, $(SRCS))
OBJECTS := $(OBJECTS:.c=.o)
OBJECTS := $(OBJECTS:.nasm=.o)
LISTINGS := $(OBJECTS:.o=.s)

# Targets
.PHONY: all, pre_build, assembly, clean
all: pre_build bin/os.img
pre_build:
	@if [ ! -d "bin" ]; then mkdir "bin"; fi
	@if [ ! -d "obj" ]; then mkdir "obj"; fi
assembly: pre_build $(LISTINGS) bin/boot.s
clean:
	rm -rf bin obj

# 'all' target
bin/os.img: bin/kernel.bin bin/loader.bin bin/boot.bin
	@qemu-img create bin/os.img $(DISK_SIZE)
	python3 tools/part_table.py bin/os.img
	dd if=bin/boot.bin of=bin/os.img conv=notrunc status=none
	dd if=bin/part_table.bin of=bin/os.img oflag=seek_bytes seek=446 conv=notrunc status=none
	dd if=bin/loader.bin of=bin/os.img oflag=seek_bytes seek=512 conv=notrunc status=none
	dd if=bin/kernel.bin of=bin/os.img oflag=seek_bytes seek=1048576 conv=notrunc status=none

obj/%.o: src/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $^

obj/%.o: src/%.nasm
	@mkdir -p $(dir $@)
	nasm $(NASM_FLAGS) -f elf64 -o $@ $^

bin/kernel.bin: $(OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $^

bin/loader.bin: boot/bios/loader.nasm boot/bios/inc/*.nasm
	nasm $(NASM_FLAGS) -iboot/bios/ -f bin -o $@ boot/bios/loader.nasm

bin/boot.bin: bin/loader.bin
	macros="-DLOADER_SIZE=`stat -c%s bin/loader.bin` \
			-DLOADER_CHECK=`xxd -e -l 4 bin/loader.bin | awk '{printf \"0x\"$$2}'`"; \
	nasm $(NASM_OPTS) $$macros -f bin -o $@ boot/bios/boot.nasm
	@if [ $$(stat -c%s $@) -gt 440 ]; then			 \
		rm -f $@; echo "error: booter is larger than 440 bytes"; exit 1; fi

# 'assembly' target
obj/%.s: src/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -S -o $@ $^

obj/%.s: src/%.nasm
	@mkdir -p $(dir $@)
	nasm $(NASM_FLAGS) -f elf64 -l $@ $^

bin/loader.s: boot/bios/*.nasm
	nasm $(NASM_FLAGS) -iboot/bios/ -f bin -l $@ -o bin/loader.bin boot/bios/loader.nasm

bin/boot.s: bin/loader.s
	macros="-DLOADER_SIZE=`stat -c%s bin/loader.bin` \
			-DLOADER_CHECK=`xxd -e -l 4 bin/loader.bin | awk '{printf \"0x\"$$2}'`"; \
	nasm $(NASM_OPTS) $$macros -f bin -l $@ -o bin/boot.bin boot/bios/boot.nasm
	@if [ $$(stat -c%s bin/boot.bin) -gt 440 ]; then			 \
		rm -f $@; echo "error: booter is larger than 440 bytes"; exit 1; fi

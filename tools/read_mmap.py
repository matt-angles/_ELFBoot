# Read the memory map from a 0x0500 memory dump
# Usage: qemu: pmemsave 0x0500 4096 mmap.mem
#        read_mmap.py mmap.mem

import sys

# NOTE: would be better to wrap mmap in a class
def fmt_size(num, suffix='B'):
    for unit in ("", "Ki", "Mi", "Gi", "Ti", "Pi", "Ei", "Zi"):
        if abs(num) < 1024.0:
            return f"{num:3.1f} {unit}{suffix}"
        num /= 1024.0
    return f"{num:.1f} Yi{suffix}"

def fmt_mmapType(entry):
    match entry:
        case 1:
            return "Available (1)"
        case 2:
            return "Reserved  (2)"
        case 3:
            return "ACPI Data (3)"
        case 4:
            return "Reserved  (4)"
        case _:
            return f"Bad       ({entry})"

def read_mmap(dump: bytes):
    if dump[0:3] != b"MEM":
        print("read_mmap: MMAP not found (invalid file?)")
        return
    if len(dump) < dump[3]*20:
        print("read_mmap: dump too small")
        return

    mmap = []
    for i in range(dump[3]):
        offset = 4 + 20*i

        base    = int.from_bytes(dump[offset:offset+8], 'little')
        limit   = int.from_bytes(dump[offset+8:offset+16], 'little')
        identif = int.from_bytes(dump[offset+16:offset+20], 'little')
        mmap.append(tuple([base, limit, identif]))
    mmap.sort()
    return mmap

def print_mmap(mmap):
    print("Base Address     | Length (in hex)  | Length    | Type")
    for entry in mmap:
        print(f"{entry[0]:#016x} | {entry[1]:#016x} |",
              f"{fmt_size(entry[1]):9} | {fmt_mmapType(entry[2])}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Missing argument: MMAP dump file")
        exit(1)

    with open(sys.argv[1], "rb") as file:
        mmap = read_mmap(file.read())
        if mmap is not None:
            print_mmap(mmap)

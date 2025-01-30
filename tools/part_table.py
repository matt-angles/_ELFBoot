# Read, create and manipulate **MBR** partition tables
# Usage: part_table.py DISK_IMAGE

import sys
import os
from dataclasses import dataclass

@dataclass
class PartitionEntry:
    bootable: bool  = False
    chsStart: tuple = (0, 0, 0)
    identif: int    = 0
    chsEnd: tuple   = (0, 0, 0)
    lbaStart: int   = 0
    lbaSize: int    = 0

class PartitionTable:
    @staticmethod
    def _lba2chs(lba):
        cylinder = lba // (16 * 63)
        head = (lba // 63) % 16
        sector = (lba % 63) + 1
        return (cylinder, head, sector)

    @staticmethod
    def _fmt_identif(identif):
        match identif:
            case 0x00:
                return "Unused"
            case 0x07:
                return "Windows NT NTFS"
            case 0x83:
                return "Linux native partition"
            case 0xA8:
                return "Mac OS-X"
            case 0xAC:
                return "AcceptableOS partition"
            case _:
                return f"Unknown ({_:#02x})"

    def __init__(self, size):
        self.partitions = [PartitionEntry() for _ in range(4)]
        self.size = size

    def __bytes__(self):
        b = bytearray(16*4)
        for i in range(4):
            p = self.partitions[i] ; o = i*16
            b[o+0] = 0x80 if p.bootable else 0
            b[o+1] = p.chsStart[1]
            b[o+2] = p.chsStart[2] | (p.chsStart[0] & 0xC0)
            b[o+3] = p.chsStart[0] % 255
            b[o+4] = p.identif
            b[o+5] = p.chsEnd[1]
            b[o+6] = p.chsEnd[2] | (p.chsEnd[0] & 0xC0)
            b[o+7] = p.chsEnd[0] % 255
            b[o+8:o+0xC] = p.lbaStart.to_bytes(4, 'little')
            b[o+0xC:o+0x10] = p.lbaSize.to_bytes(4, 'little')
        return bytes(b)

    def __repr__(self):
        b = self.__bytes__() ; r = []
        for i in range(len(b)):
            if i % 16 == 0 and i != 0: r.append('\n')
            r.extend(f"{b[i]:02x} ")
        return ''.join(r)

    def __str__(self):
        s = []
        for i in range(4):
            p = self.partitions[i]
            s.extend(f"Partition Entry #{i}")
            s.extend(" - Bootable\n" if p.bootable else "\n")
            if p.identif == 0:
                s.extend("\tEmpty\n")
                continue
            s.extend(f"\tType: {self._fmt_identif(p.identif)}\n")
            s.extend(f"\tStart (CHS): {p.chsStart}\n")
            s.extend(f"\tStart (LBA): {p.lbaStart}\n")
            s.extend(f"\tEnd  (CHS): {p.chsEnd}\n")
            s.extend(f"\tSize (LBA): {p.lbaSize}\n")
        s.pop()
        return ''.join(s)

    def create_partition(self, index, start=None, size=None):
        if start is None:
            start = max([p.lbaStart for p in self.partitions] + [2048])
        if size is None:
            size = self.size - start*512
        size = (size+511)//512

        partition = PartitionEntry()
        partition.lbaStart = start
        partition.lbaSize = size
        partition.chsStart = self._lba2chs(start)
        partition.chsEnd = self._lba2chs(start+size-1)

        self.partitions[index] = partition

    def set_bootable(self, index):
        for i in range(4):
            val = i==index
            self.partitions[i].bootable = val

    def set_type(self, index, value):
        self.partitions[index].identif = value

    def read_from(self, b: bytes):
        raise NotImplementedError


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Missing argument: Disk image")
        exit(1)

    diskSize = os.path.getsize(sys.argv[1])
    diskTable = PartitionTable(diskSize)
    diskTable.create_partition(0)
    diskTable.set_bootable(0)
    diskTable.set_type(0, 0xAC)
    
    outputFile = os.path.dirname(os.path.abspath(sys.argv[1]))
    outputFile += "/part_table.bin"
    with open(outputFile, 'wb') as f:
        f.write(bytes(diskTable) + b'\x55\xAA')
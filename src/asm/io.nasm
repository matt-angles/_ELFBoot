; x86_64 port I/O wrapper functions
; ABI: System V AMD64 (Version 1.0)

GLOBAL inb,  inw,  ind, \
       outb, outw, outd

inb:
    mov dx, di
    in al, dx
    ret
inw:
    mov dx, di
    in ax, dx
    ret
ind:
    mov dx, di
    in eax, dx
    ret

outb:
    mov dx, di
    mov ax, si
    out dx, al
    ret
outw:
    mov dx, di
    mov ax, si
    out dx, ax
    ret
outd:
    mov dx, di
    mov eax, esi
    out dx, eax
    ret

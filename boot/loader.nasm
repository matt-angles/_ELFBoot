ORG 0x0500
BITS 16

jmp start

msg_stage2: db "Stage 2 loaded"
msgl_stage2: equ $ - msg_stage2

start:
    mov ax, 0x1301      ; AH=0x13: write string - AL=0x01: update cursor
    mov bx, 0x0002      ; BH=0x00: page number  - BL=0x04: green color
    mov dx, 0x0200      ; write at 2,0
    mov cx, msgl_stage2 ; set string length
    mov bp, msg_stage2  ; set string pointer ([0x0000:Eff_Addr])
    int 0x10            ; BIOS Interrupt 10: Video

    jmp $
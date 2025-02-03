;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MBR (BIOS) BootLoader for an x86_64 ELF ;
; executable                              ;
;                                         ;
; Function: Load executable in memory     ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

msg noELF, "ELF not found."
disk_pkt:
           dw 0x0010        ; 0x0010: disk packet identifier
    .size: dw 1             ; 1: size in blocks to transfer
    .addr: dd 0x7E00        ; 0x0000:0x7E00 - transfer address
    .lba:  dq 0             ; 0: LBA absolute start address


load_elf:
; Function: load the ELF executable into high memory
; Argument: EAX = LBA of kernel partition
;           STACK = drive number
; Return  : nothing
elf_header:
    .read:
    mov [disk_pkt.lba], eax ; set LBA from argument
    mov ax, 0x4200          ; AH=0x42: extended read
    mov bp, sp
    mov dx, [ss:bp+4]       ; DL = drive number from argument
    mov si, disk_pkt        ; DS:SI = 0x00:disk_pkt
    int 0x13                ; BIOS Interrupt 0x13 - Disk

    .parse:
    mov bx, 0x7E00          ; 0x7E00: ELF header address
    cmp [bx], dword 0x464C457F
                            ; 0x464C457F ("ELF"): ELF magic number
    mov cx, msgl_noELF
    mov bp, msg_noELF
    jne error

    .program_header:
    movzx ecx, word [bx+0x38]
                            ; +0x38: program header number of entries
    add bx, [bx+0x20]       ; +0x20: program header offset
    mov dword [disk_pkt.addr], 0x0800_0000
                            ; 0x0800:0000 - segment load address

elf_segment:
    cmp dword [bx], 1           ; +0x00: type of segment - must be 1=loadable
    jne .loop

    .makePkt:
        ; disk_pkt.lba
        push dword [disk_pkt.lba]; save base LBA for future segments
        xor edx, edx            ; EDX=0
        mov eax, [bx+0x08]      ; EAX=+0x08: segment offset (in bytes)
        mov ebp, 512            ; EBP=512: block size
        div ebp                 ; segment offset (in LBA) = EDX:EAX / EDI
        add [disk_pkt.lba], eax ; segment LBA = base + offset

        ; disk_pkt.size
        mov eax, [bx+0x20]      ; EAX=+0x20: segment size (in bytes)
        div ebp
        inc eax                 ; segment size (LBA) = EDX:EAX / EDI + 1
        mov [disk_pkt.size], ax

    .read:
        ; Read: BIOS 0x13
        mov ax, 0x4200          ; AH=0x42: extended read
        mov bp, sp
        mov dx, [ss:bp+8]       ; DL = drive number from argument
        mov si, disk_pkt
        int 0x13                ; BIOS Interrupt 0x13 - Disk
        pop dword [disk_pkt.lba]; restore base LBA

        ; Copy: rep movsw
        mov eax, 256            ; EAX=256: size of a block (in words)
        mov dx, [disk_pkt.size] ; DX=disk_pkt.size: number of blocks
        mul edx                 ; *word*s to copy = 256 * disk_pkt.size

        ; NOTE: unreal mode might be needed (outside 1MB)
        push ecx                ; save ecx for outer loop
        mov ecx, eax
        mov esi, 0x8000         ; Current address
        mov edi, [bx+0x10]      ; New address += offset
        a32 rep movsw           ; Copy segment!
        pop ecx

    .loop:
        loop elf_segment
        ret
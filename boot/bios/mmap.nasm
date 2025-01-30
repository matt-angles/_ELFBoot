;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MBR (BIOS) BootLoader for an x86_64 ELF ;
; executable                              ;
;                                         ;
; Function: obtain and parse memory map   ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

msg mmapError, "MMAP read fail / unsupported."

mmap:
; Function: verify whether required memory is available (NOTE: no flexible loading)
; Argument: nothing
; Return:   nothing
    mov di, 0x0500
    mov dword [di], "MEM0"
                        ; 0x0500-0x0600: memory map table
    add di, 4           ; ES:DI = 0x00:0x0504 - mmap address
    xor si, si          ; SI: mmap number of entries
    xor ebx, ebx        ; EBX=0: mmap offset (start)
.read:
    mov eax, 0x0000E820 ; AX=0xE820: get system memory map
    mov ecx, 20         ; ECX=20: number of bytes to copy
    mov edx, 0x534D4150 ; required ("SMAP")
    int 0x15            ; BIOS Interrupt 15: System
    jc .error

    add di, 20          ; read next entry (20 bytes farther)
    inc si
    test ebx, ebx       ; if ebx=0, read finished
    jnz .read

    ; TODO: have to verify memory is available (my old code broke :(
    mov ax, si
    mov byte [0x0503], al
    ret

.error:
    mov cx, msgl_mmapError
    mov bp, msg_mmapError
    jmp error
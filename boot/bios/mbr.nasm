;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MBR (BIOS) BootLoader for an x86_64 ELF    ;
; executable                                 ;
;                                            ;
; Function: Parse MBR, find kernel partition ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

msg noBoot, "No bootable partition found."
msg noOS, "Operating System not found"

mbr:
; Function: parse the MBR to find kernel partition
; Argument: nothing
; Return  : EAX = LBA address of kernel partition
    mov bx, 0x7C00+0x01BE   ; address of first partition entry
    mov cx, 4               ; 4 entries to parse

    .bootable:
        bt word [bx], 7     ; bit 7: bootable flag
        jc .os              ; if bootable, assume it is the kernel partition
        add bx, 0xF+1       ; else parse the next entry (16 bytes farther)
        loop .bootable

        mov cx, msgl_noBoot
        mov bp, msg_noBoot
        jmp error

    .os:
        cmp byte [bx+4],0xAC; check partition type for OS signature (0xAC)
        je .found

        mov cx, msg_noOS
        mov bp, msgl_noOS
        jmp error

    .found:
        mov eax, [bx+8]
        ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MBR (BIOS) BootLoader for an x86_64 ELF ;
; executable                              ;
;                                         ;
; Function: Find kernel on disk           ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%define OS_DISKSIG 0xAC

SECTION .data
msg noBoot, "No bootable partition found."
msg noOS, "Operating System not found."

SECTION .text
find_elf:
; Function: parse the MBR to find kernel partition
; Argument: nothing
; Return  : EAX = LBA address of kernel partition
    mov bx, 0x7C00+0x01BE   ; BX: address of first partition entry
    mov cx, 4               ; CX: number of entries to parse

    .bootable:
        bt word [bx], 7     ; bit 7: bootable flag
        jc .os              ; if bootable, assume it is the kernel partition
        add bx, 0xF+1       ; else, parse the next entry 16 bytes farther
        loop .bootable

        mov cx, msgl_noBoot
        mov bp, msg_noBoot
        jmp error

    .os:
        cmp byte [bx+4], OS_DISKSIG
                            ; check partition type for OS signature
        je .found

        mov cx, msg_noOS
        mov bp, msgl_noOS
        jmp error

    .found:
        mov eax, [bx+8]
        ret

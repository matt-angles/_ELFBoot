;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MBR (BIOS) BootLoader for an x86_64 ELF ;
; executable                              ;
;                                         ;
; Function: get and access all memory     ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SECTION .data
msg a20Warn, "warn: A20 disabled"
msg a20Error, "Unable to activate A20 line."
msg mmapError, "MMAP read fail / unsupported."

SECTION .text
enable_a20:
; Function: ensure the a20 line is enabled
; Argument: nothing
; Return:   nothing
    mov bp, sp          ; create stack frame
    mov ax, 0xFFFF
    mov fs, ax          ; create a segment that uses the A20 line (above 1MB)

    mov si, word [0x7C00]
    cmp [fs:0x7C10], si
    jne .done           ; if addresses contain different values, A20 is enabled
    call .check         ; otherwise, might be a coincidence, do another check

    mov di, bp          ; save stack frame (warn does not preserve BP)
    mov cx, msgl_a20Warn
    mov bp, msg_a20Warn
    call warn
    mov bp, di          ; restore SF

    call a20_bios
    call .check
    call a20_keyboard
    call .check

    mov cx, msgl_a20Error
    mov bp, msg_a20Error
    jmp error

    .check:
        inc si
        mov word [0x7C00], si
        cmp [fs:0x7C10], si
                        ; if only a single one updates, A20 is enabled
        jne .done
        ret

    .done:
        mov sp, bp      ; destroy stack frame
        ret
a20_bios:
; Enable the A20 line using the BIOS
    mov ax, 0x2403      ; AX=0x2403: query a20 gate support
    int 0x15            ; BIOS Interrupt 0x15: System
    jc .done

    test bl, 1          ; bit 1 indicate if fast a20 is supported
    jnz .fast

    mov ax, 0x2401      ; AX=0x2401: enable a20 gate
    int 0x15            ; BIOS Interrupt 0x15: System
    jmp .done

    .fast:
    in al, 0x92         ; AL=0x92: system control port A
    or al, 2            ; bit 2: a20 gate
    and al, ~1          ; bit 1: machine reset
    out 0x92, al        ; write back

    .done: ret


a20_keyboard:
; From https://aeb.win.tue.nl/linux/kbd/A20.html
    call    .wait
    mov     al, 0xD1
    out     0x64, al
    call    .wait
    mov     al, 0xDF
    out     0x60, al
    call    .wait
    ret

    .wait:
        in al, 0x64
        test al, 2
        jnz .wait
    ret


get_mmap:
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MBR (BIOS) BootLoader for an x86_64 ELF ;
; executable                              ;
;                                         ;
; Function: ensure the a20 line is active ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

msg a20Warn, "warn: A20 disabled"
msg a20Error, "Unable to activate A20 line."

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


a20:
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
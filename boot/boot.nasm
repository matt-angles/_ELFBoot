;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Custom BIOS BootLoader for an ELF x86    ;
; executable.                              ;
;                                          ;
; Stage 1: Wake up and load bigger stage 2 ;
; Size: limited to 446 bytes               ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Expected macros: LOADER_SIZE, LOADER_CHECK
%if LOADER_SIZE >= 255*512
    %error "loader is too big to be read by the BIOS!"
%endif

ORG 0x7C00      ; Binary loaded by the BIOS at memory address 0x7C00
BITS 16         ; Processor started in real address mode
jmp start       ; skip (don't execute) data section

SECTION data
msg_wakeUp:     db "Waking up..."
msgl_wakeUp:    equ $ - msg_wakeUp
msg_diskFail:   db "Cannot read disk!"
msgl_diskFail:  equ $ - msg_diskFail
msg_fail:       db "Stage 2 invalid!"
msgl_fail:      equ $ - msg_fail
msg_success:    db "Stage 2 loaded"
msgl_success:   equ $ - msg_success

SECTION text
start:
    cli                     ; Disable interrupts
    in   al, 0x92           ; Read port 0x92
    and  al, 0xFE           ; Clear bit 1 (A20 enable bit)
    out  0x92, al           ; Write back to port 0x92
    sti                     ; Re-enable interrupts
    
    ; 1. Set up a stack (+ any other initialization)
    mov ax, 0x0000      ; using the first 64 KiB of memory (segment 0)
    mov ss, ax          ; initialize the stack segment
    mov es, ax          ; initialize the extra segment, used by BIOS functions
    mov sp, 0x7C00      ; set stack address
    push dx             ; save the current drive number for later
    push 0x0202         ; 0x0202: default FLAGS value (IF set, others cleared)
    popf                ; ensure FLAGS is initialized by loading the default

    ; 2. Display booting message
    mov ax, 0x0003          ; AH=0x00: set video mode - AL=0x02: VGA 80x25 text mode
    int 0x10                ; BIOS Interrupt 10: Video

    mov ax, 0x1301      ; AH=0x13: write string - AL=0x01: update cursor
    mov bx, 0x000F      ; BH=0x00: page number  - BL=0x0F: white color
    mov cx, msgl_wakeUp ; set string length
    mov dx, 0x0000      ; write at 0,0
    mov bp, msg_wakeUp  ; set string pointer (ES:addr)
    int 0x10            ; BIOS Interrupt 10: Video

    ; 3. Load Stage 2 from disk to memory address 0x0500
    mov cx, 3           ; 3 read attempts
    jmp disk_read

disk_retry:
    mov ah, 0x00        ; AH=0x00: reset disk system
    int 13              ; BIOS Interrupt 13: Disk

disk_read:
    push cx             ; store attempt counter (no extra register available)
    mov bp, sp          ; use GP to manipulate stack

    mov ax, 0x0200 + (LOADER_SIZE/512)+1
                        ; AH=0x02: read sectors into memory - AL=n: read n sectors
    mov bx, 0x0500      ; target memory address
    mov cx, 0x0002      ; CH=0x00: cylinder 0 - CL=0x02: sector 2
    mov dx, [bp+2]      ; get drive number from stack
    mov dh, 0           ; head 0
    int 0x13            ; BIOS Interrupt 13: Disk

    pop cx              ; get CX back
    jnc success         ; if no errors, stage 1 is done
    loop disk_retry     ; retry (NOTE: untested)

    mov ax, 0x1301          ; AH=0x13: write string - AL=0x01: update cursor
    mov bx, 0x000F          ; BH=0x00: page number  - BL=0x0F: white color
    mov dx, 0x0100          ; write at 1,0
    mov cx, msgl_diskFail   ; set string length
    mov bp, msg_diskFail    ; set string pointer (ES:addr)
    int 0x10                ; BIOS Interrupt 10: Video
    jmp $                   ; stop

load_invalid:
    mov ax, 0x1301      ; AH=0x13: write string - AL=0x01: update cursor
    mov bx, 0x000F      ; BH=0x00: page number  - BL=0x0F: white color
    mov dx, 0x0200      ; write at 1,0
    mov cx, msgl_fail   ; set string length
    mov bp, msg_fail    ; set string pointer (ES:addr)
    int 0x10            ; BIOS Interrupt 10: Video
    jmp $               ; stop

success:
    mov ax, 0x1301      ; AH=0x13: write string - AL=0x01: update cursor
    mov bx, 0x000F      ; BH=0x00: page number  - BL=0x0F: white color
    mov dx, 0x0100      ; write at 1,0
    mov cx, msgl_success; set string length
    mov bp, msg_success ; set string pointer (ES:addr)
    int 0x10            ; BIOS Interrupt 10: Video

    cmp dword [0x500], LOADER_CHECK
    jne load_invalid    ; quick sanity check of what's loaded
    jmp 0x0050:0x0000   ; Far jump to stage 2
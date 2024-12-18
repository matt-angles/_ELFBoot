;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Custom BIOS BootLoader for the           ;
; Acceptable Operating System (x86/x86_64) ;
;                                          ;
; Stage 1: Wake up and load bigger stage 2 ;
; Size: limited to 446 bytes               ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ORG 0x7C00      ; Binary is loaded by the BIOS at memory address 0x7C00
BITS 16         ; Processor starts in real adress mode

jmp start       ; skip (don't execute) data section

SECTION data
msg_wakeUp:     db "Waking up..."
msgl_wakeUp:    equ $ - msg_wakeUp
msg_diskFail:   db "Cannot read disk!"
msgl_diskFail:  equ $ - msg_diskFail
msg_success:    db "Found boot stage 2"
msgl_success:   equ $ - msg_success

SECTION text
start:
    ; 1. Set up a stack (+ any other initialisation)
    mov ax, 0x7C0-0x40  ; 1 KiB from the top of our memory (0x0500 - 0x7C00 usable)
    mov ss, ax          ; segment of new full descending stack at that address (*0xF)
    mov sp, 0x400       ; set starting offset (empty stack)
    push dx             ; save the current drive number for later
    push 0x0202         ; 0x0202: default FLAGS value (IF set, others cleared)
    popf                ; ensure FLAGS is initialized by loading the default
    mov ax, 0           ; indirect assignment to ES
    mov es, ax          ; reset the ES segment for using BIOS functions

    ; 2. Display booting message
    mov ax, 0x0700      ; AH=0x07: clear/scroll screen - AL=0x00: select clear
    mov bh, 0           ; do not write blank lines
    mov cx, 0x0000      ; set window upper left corner at 0,0
    mov dx, 0xFFFF      ; set window lower right corner at FF,FF
    int 0x10            ; BIOS Interrupt 10: Video

    mov ax, 0x1301      ; AH=0x13: write string - AL=0x01: update cursor
    mov bx, 0x000F      ; BH=0x00: page number  - BL=0x0F: white color
    mov cx, msgl_wakeUp ; set string length
    mov dx, 0x0000      ; write at 0,0
    mov bp, msg_wakeUp  ; set string pointer ([ES(0):Eff_Addr])
    int 0x10            ; BIOS Interrupt 10: Video

    ; 3. Load Stage 2 from disk to memory address 0x0500
    mov cx, 3           ; Maximum 3 read attempts
    jmp disk_read

disk_retry:
    mov ah, 0x00        ; AH=0x00: reset disk system
    int 13              ; BIOS Interrupt 13: Disk

disk_read:
    push cx             ; store attempt counter (no extra register available)
    mov bp, sp          ; use GP to manipulate stack

    mov ax, 0x0201      ; AH=0x02: read sectors into memory - AL=n: read n sectors
    mov bx, 0x0500      ; target memory address
    mov cx, 0x0002      ; CH=0x00: cylinder 0 - CL=0x02: sector 2
    mov dx, [ss:bp+2]   ; get drive number from stack
    mov dh, 0           ; head 0
    int 0x13            ; BIOS Interrupt 13: Disk

    pop cx              ; get CX back
    jnc success         ; if no errors, we finished stage 1
    loop disk_retry     ; retry (NOTE: untested code)

    mov ax, 0x1301          ; AH=0x13: write string - AL=0x01: update cursor
    mov bx, 0x000F          ; BH=0x00: page number  - BL=0x0F: white color
    mov dx, 0x0100          ; write at 1,0
    mov cx, msgl_diskFail   ; set string length
    mov bp, msg_diskFail    ; set string pointer ([0x0000:Eff_Addr])
    int 0x10                ; BIOS Interrupt 10: Video
    jmp $                   ; stop

success:
    mov ax, 0x1301      ; AH=0x13: write string - AL=0x01: update cursor
    mov bx, 0x000F      ; BH=0x00: page number  - BL=0x0F: white color
    mov dx, 0x0100      ; write at 1,0
    mov cx, msgl_success; set string length
    mov bp, msg_success ; set string pointer ([0x0000:Eff_Addr])
    int 0x10            ; BIOS Interrupt 10: Video

    jmp 0x0050:0x0000   ; Far jump to stage 2 :yay:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MBR (BIOS) BootLoader for an x86_64 ELF ;
; executable                              ;
;                                         ;
; Stage 1: Init and load bigger loader    ;
; Size: maximum 440 bytes                 ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%if LOADER_SIZE <= 0
    %error "invalid LOADER_SIZE (<=0)"
%endif
%if LOADER_SIZE >= (0x7C00 - 0x0500)
    %error "LOADER_SIZE too big for given memory"
%endif
%if LOADER_SIZE >= 255*512
    %error "LOADER_SIZE too big for one BIOS read"
%endif
%if LOADER_CHECK = 0
    %error "invalid LOADER_CHECK (=0)"
%endif


ORG 0x7C00
BITS 16
jmp 0x00:start          ; begin execution at start, and enforce valid CS:IP

SECTION data
msg_diskError:  db "Cannot read disk."
msgl_diskError: equ $ - msg_diskError
msg_noLoader:   db "Invalid stage 2."
msgl_noLoader:  equ $ - msg_noLoader

SECTION text
error:
    mov ax, 0x1301      ; AH=0x13: write string - AL=0x01: update cursor
    mov bx, 0x000F      ; BH=0x00: page 0 - BL=0x0F: white on black color
    xor dx, dx          ; DH=0x00: row 0 - DL=0x00: column 0
    mov es, dx          ; ES:BP = 0x00:str - string address
    int 0x10            ; BIOS Interrupt 10: Video

    .stop:
    cli                 ; disable software interrupts
    hlt                 ; halt until next interrupt (not happening)
    jmp .stop           ; in case of hardware interrupts

start:
    mov ax, 0x0003      ; AH=0x00: set video mode - AL=0x03: VGA 80x25 text mode
    int 0x10            ; BIOS Interrupt 0x10: Video

    .readLoader:
    mov ax, 0x0200 + (LOADER_SIZE+511)/512
                        ; AH=0x02: read n sectors into memory - AL=n
    mov cx, 0x0002      ; CH=0x00: cylinder 0 - CL=0x02: sector 2
    mov dh, 0x00        ; DH=0x00: head 0 - DL: drive code (passed from BIOS)
    xor bx, bx
    mov es, bx
    mov bx, 0x0600      ; ES:BX = 0x00:0x0500 - target memory address
    int 0x13            ; BIOS Interrupt 0x13: Disk

    jnc .jumpLoader     ; if carry clear, read succeeded
    mov cx, msgl_diskError
    mov bp, msg_diskError
    jmp error

    .jumpLoader:
    cmp dword [0x0600], LOADER_CHECK
                        ; check that the loader is actually there

    je 0x0600           ; if it is, jump to it
    mov cx, msgl_noLoader
    mov bp, msg_noLoader
    jmp error           ; otherwise, crash

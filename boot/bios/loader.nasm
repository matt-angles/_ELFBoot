;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MBR (BIOS) BootLoader for an x86_64 ELF  ;
; executable                               ;
;                                          ;
; Stage 2: Set up, load and run executable ;
; Size: maximum 30.19 KiB (w/ ~1KiB stack) ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ORG 0x0600
BITS 16
jmp start               ; begin execution at start

%macro msg 2
    msg_%1:  db %2
    msgl_%1: equ $ - msg_%1
%endmacro
%include "inc/memory.nasm"
%include "inc/disk.nasm"
%include "inc/elf.nasm"
%include "inc/cpu.nasm"

SECTION .text
warn:
; Function: display a warning message
; Argument: CX = message length
;           BP = message address
; Return:   nothing
    mov ax, 0x1301      ; AH=0x13: write string - AL=0x01: update cursor
    mov bx, 0x000F      ; BH=0x00: page 0 - BL=0x0F: white on black color
    mov dh, [.curLine]  ; DH=.curLine
    xor dl, dl          ; DL=0x00: column 0
    int 0x10            ; BIOS Interrupt 0x10: Video
    inc byte [.curLine] ; update .curLine
    ret

    .curLine: db 0      ; line to write at (maximum 24)

error:
; Function: display an error message and stop execution
; Argument: CX = message length
;           BP = message address
    call warn

    .stop:
    cli                 ; disable software interrupts
    hlt                 ; halt until next interrupt (not happening)
    jmp .stop           ; in case of hardware interrupts

start:
    ; Environment initialization
    xor eax, eax
    mov ds, ax
    mov es, ax          ; ES=0x00: needed by warn & error
    mov ss, ax
    mov sp, 0x7DBE      ; full descending stack from 0x7DBE
    push 0x0202         ; 0x0202: default FLAGS value
    popf                ; load default FLAGS to ensure valid state
    mov cr4, eax        ; disable all CPU extensions
    mov eax, 0x60000010 ; default CR0 value
    mov cr0, eax
    push dx             ; save drive number (preserved by booter)

    call enable_a20
    call get_mmap
    call find_elf
    call load_elf
    jmp cpu_conf        ; code will resume at end


BITS 64
end:
    ; Jump to ELF address
    mov rdi, qword [0x7E00 + 0x18]
    call rdi
    jmp $               ; How Did We Get Here?

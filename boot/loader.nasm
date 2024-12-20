;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Custom BIOS BootLoader for the           ;
; Acceptable Operating System (x86/x86_64) ;
;                                          ;
; Stage 2: Set up, load and run ELF kernel ;
; Size: maximum 28.75 KiB (should be fine) ;
; Memory: 1 KiB                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ORG 0x0500      ; Binary loaded by stage 1 at memory address 0x0500
BITS 16         ; Processor is still in real address mode

jmp start

SEGMENT .data
msg_stage2:  db "Stage 2 loaded"
msgl_stage2: equ $ - msg_stage2
msg_noBoot:  db "No bootable partition found!"
msgl_noBoot: equ $ - msg_noBoot
msg_noOS:    db "Operating System not found!"
msgl_noOS:   equ $ - msg_noOS
msg_loadFail:   db "Cannot read disk!"
msgl_loadFail:  equ $ - msg_loadFail
msg_loadSuccess:  db "Successfully loaded kernel"
msgl_loadSuccess: equ $ - msg_loadSuccess
msg_enterPE:  db "Entering PE. See you on the other side..."
msgl_enterPE: equ $ - msg_enterPE

lod_gdt:            ; Flat memory model GDT
     ; Null descriptor
    dq 0

    ; Code descriptor
    dw 0xFFFF       ; Segment size / 4 KiB [00:15]
    dw 0x0000       ; Base address [00:15]
    db 0x00         ; Base address [16:23]
    db 0b10011010   ; Flags (P, DPL=0, S) + Type (Execute/Read)
    db 0b11001111   ; Flags (G, 32b, ~64b) + Unused + Segment size [16:19] 
    db 0x00         ; Base address [24:31]

    ; Data descriptor
    dw 0xFFFF       ; Segment size / 4 KiB [00:15]
    dw 0x0000       ; Base address [00:15]
    db 0x00         ; Base address [16:23]
    db 0b10010010   ; Flags (P, DPL=0, S) + Type (Read/Write)
    db 0b11001111   ; Flags (G, 32b, ~64b) + Unused + Segment size [16:19] 
    db 0x00         ; Base address [24:31]

lim_gdt: equ $ - lod_gdt - 1

ptr_gdt:
    dw lim_gdt
    dd lod_gdt


SEGMENT .text
stop:
    hlt
    jmp stop

print_str:
; void print_str(char* str, word len) - does not preserve state
; displays a string of characters on the screen. **real address mode only!**
; NOTE: special calling convention. This weird BIOS function uses the BP register!
; Hence, there is no need to free the parameters after calling
    pop ax              ; temporarily get return address out of stack
    pop cx              ; set string length
    pop bx              ; save string pointer to temporary register BX
    push ax             ; store back return address
    push bp             ; store back stack frame
    mov bp, bx          ; set string pointer

    mov ax, 0x1301          ; AH=0x13: write string - AL=0x01: update cursor
    mov bx, 0x000F          ; BH=0x00: page number  - BL=0x0F: white color
    xor dx, dx              ; DL=0x00: write at column 0
    mov dh, [currentLine]   ; DH: write at line currentLine
    int 0x10                ; BIOS Interrupt 10: Video
    inc byte [currentLine]  ; update currentLine

    pop bp              ; restore stack pointer
    ret

find_partition:
; dword find_partition(void) - does not preserve state
; parse the MBR and return the starting CHS address of the target partition
; return: AH=C, AL=H, BH=S 
    mov bp, sp              ; prologue - create new stack frame pointer
    mov bx, 0x7C00+0x01BE   ; address of first partition entry
    mov cx, 4               ; 4 entries to iterate through

    parse_bootable:
        cmp byte [bx], 0x80 ; 0x80: bootable flag. NOTE: CMP is not appropriate here!
        je parse_os         ; if bootable, assume it is the target partition
        add bx, 0xF+1       ; else, parse the next entry (16 bytes farther)
        loop parse_bootable

        push msg_noBoot
        push msgl_noBoot
        call print_str
        jmp stop

    parse_os:
        cmp byte [bx+4],0xAC; check OS signature (0xAC)
        je parse_success    ; partition must be valid!

        push msg_noOS
        push msgl_noOS
        call print_str
        jmp stop

    parse_success:
        mov ah, byte [bx+3] ; cylinder low bits
        mov al, byte [bx+1] ; head
        mov bh, byte [bx+2] ; head + sector & cylinder high bits
        mov sp, bp        ; epilogue - restore stack
        ret

load_partition:
; void load_partition(AH=C, AL=H, BH=S, word drive) - does not preserve state
; load the ELF kernel from CHS to memory address 0x7E00
    mov bp, sp              ; prologue - create new stack frame pointer
    mov cx, 3               ; try reading the disk at most 3 times
    jmp load_read
    
    load_retry:
        mov ah, 0x00        ; AH=0x00: reset disk system
        int 13              ; BIOS Interrupt 13: Disk

    load_read:
        push cx             ; store attempt counter (no extra register available)

        mov ch, ah          ; set cylinder
        mov cl, bh          ; set sector
        mov bx, sp          ; manipulate SP with general purpose register BX
        mov dx, [ss:bx+4]   ; drive number was in stack all along!
        mov dh, al          ; set head
        mov ax, 0x0209      ; AH=0x02: read sectors into memory - AL=n: read n sectors
        mov bx, 0x8000      ; target memory address
        int 0x13            ; BIOS Interrupt 13: Disk

        pop cx              ; get CX back
        jnc load_success    ; if no errors, we finished stage 1
        loop load_retry     ; retry (NOTE: untested code)

        push msg_loadFail
        push msgl_loadFail
        call print_str

        jmp stop

    load_success:
        push msg_loadSuccess
        push msgl_loadSuccess
        call print_str
        mov sp, bp              ; epilogue - restore stack
        ret

begin_protected_mode:
    push msg_enterPE
    push msgl_enterPE
    call print_str
    
    cli             ; disable Maskable Hardware Interrupts
                    ; NOTE: assuming no NMIs occur during mode switch
    lgdt [ptr_gdt]  ; load flat model GDT at 0x7C00
    mov eax, 0x00000011
    mov cr0, eax    ; load CR0 with PE enabled
    jmp 0x08:protected_mode     ; jump to protected mode code

start:
    mov byte [currentLine], 2   ; initialize currentLine

    push msg_stage2
    push msgl_stage2
    call print_str

    call find_partition
    call load_partition
    add sp, 2                   ; stack is clear

    jmp begin_protected_mode    ; no coming back


BITS 32         ; Processor is now in Protected Mode
read_elf:
; dword_ptr read_elf(void) - does not preserve state
; parse the kernel's ELF headers and return the entry point
; return: EAX=entry point
    ; NOTE: Extremely basic and specific loader. Doesn't check for anything.
    mov bp, sp
    mov ebx, 0x8000     ; start of 'file'
    add ebx, [ebx+28]   ; start of Program header ; specified 28 bytes into ELF header
    mov eax, [ebx+4]    ; entry offset, specified 4 bytes into Program header
    add eax, 0x8000     ; add the base
    mov sp, bp
    ret

protected_mode:
    ; Welcome to Protected Mode! We have now access to 4 GiB of memory
    ; NOTE: Segment registers haven't been reset yet
    ; NOTE: A20 line hasn't been checked (though enabled in QEMU)
    ; NOTE: Interrupts are not set up yet. The program is unresponsive
    call read_elf
    jmp eax             ; jump to ELF program :sunglasses:

SEGMENT .bss
currentLine: resb 1     ; static variable for print_str

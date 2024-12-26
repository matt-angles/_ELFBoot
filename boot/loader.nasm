;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Custom BIOS BootLoader for an ELF x86    ;
; executable.                              ;
;                                          ;
; Stage 2: Set up, load and run ELF kernel ;
; Size: max 29.75 KiB                      ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%if ELF_SIZE >= 255*512
    %error "kernel is too big to be read by the BIOS!"
%endif
%macro msg 2
    msg_%1:  db %2
    msgl_%1: equ $ - msg_%1
%endmacro

ORG 0x0500          ; Binary loaded by stage 1 at memory address 0x0500
BITS 16             ; Processor is still in real address mode
jmp start

SEGMENT .data
msg stage2, "Stage 2 started"
msg noBoot, "No bootable partition found!"
msg noOS, "No operating system found!"
msg loadFail, "Cannot read disk!"
msg loadSuccess, "Kernel loaded"
msg elfInvalid, "Invalid ELF!"
msg enterPM, "Entering PM. See you on the other side..."
gdt_con:            ; Flat memory model GDT
    ; 0x00: Null descriptor
    dq 0

    ; 0x08: Code descriptor
    dw 0xFFFF       ; Segment size [00:15] (divided by 4 KiB)
    dw 0x0000       ; Base address [00:15]
    db 0x00         ; Base address [16:23]
    db 0b10011010   ; Flags (P, DPL=0, S) + Type (Execute/Read)
    db 0b11001111   ; Flags (G, 32b, ~64b) + Unused + Segment size [16:19]
    db 0x00         ; Base address [24:31]

    ; 0x10: Data descriptor
    dw 0xFFFF       ; Segment size [00:15] (divided by 4 KiB)
    dw 0x0000       ; Base address [00:15]
    db 0x00         ; Base address [16:23]
    db 0b10010010   ; Flags (P, DPL=0, S) + Type (Read/Write)
    db 0b11001111   ; Flags (G, 32b, ~64b) + Unused + Segment size [16:19]
    db 0x00         ; Base address [24:31]
gdt_lim: equ $ - gdt_con - 1
gdt_ptr:
    dw gdt_lim
    dd gdt_con

SEGMENT .text
stop:               ; lock the processor in case of an error
    hlt
    jmp stop

print_msg:
; void print_msg(char* str, uint16_t len) - does not preserve state
; display a string of characters on the screen. **real address mode only!**
; NOTE: special calling convention. This weird BIOS function uses the BP register!
;       There is no need to free the parameters after calling.
    pop ax                  ; temporarily get return address out of stack
    pop cx                  ; set string length
    pop bx                  ; temporarily set string pointer to register BX
    push ax                 ; store back return address
    push bp                 ; store stack frame
    mov bp, bx              ; set string pointer

    mov ax, 0x1301          ; AH=0x13: write string - AL=0x01: update cursor
    mov bx, 0x000F          ; BH=0x00: page number  - BL=0x0F: white color
    xor dx, dx              ; DL=0x00: write at column 0
    mov dh, [currentLine]   ; DH=currentLine: write at line currentLine
    int 0x10                ; BIOS Interrupt 10: Video

    inc byte [currentLine]  ; update currentLine
    pop bp                  ; restore stack frame
    ret

find_partition:
; dword find_partition(void) - does not preserve state
; parse the MBR and return the CHS address of the target partition
; return: AH=C, AL=H, BH=S
    mov bp, sp              ; prologue - create new stack frame pointer
    mov bx, 0x7C00+0x01BE   ; address of first partition entry
    mov cx, 4               ; 4 entries to iterate through

    part_bootable:
        bt word [bx], 7     ; bit 7 indicate if the partition is bootable
        jc part_os          ; if bootable, assume it is the target partition
        add bx, 0xF+1       ; otherwise, parse the next entry (16 bytes farther)
        loop part_bootable

        push msg_noBoot
        push msgl_noBoot
        call print_msg
        jmp stop

    part_os:
        cmp byte [bx+4],0xAC; check partition type for OS signature (0xAC)
        je part_found       ; partition must be valid

        push msg_noOS
        push msgl_noOS
        call print_msg
        jmp stop

    part_found:
        mov ah, byte [bx+3] ; cylinder low bits
        mov al, byte [bx+1] ; head
        mov bh, byte [bx+2] ; head + sector & cylinder high bits
        mov sp, bp          ; epilogue - restore stack
        ret

load_partition:
; void load_partition(AH=C, AL=H, BH=S, uint16_t drive) - does not preserve state
; load the ELF kernel from CHS to memory address 0x7E00
    mov bp, sp              ; prologue - create new stack frame pointer
    mov cx, 3               ; 3 read attempts
    jmp load_read
    
    load_retry:
        mov ah, 0x00        ; AH=0x00: reset disk system
        int 13              ; BIOS Interrupt 13: Disk

    load_read:
        push cx             ; store attempt counter (no extra register available)

        mov ch, ah          ; set cylinder
        mov cl, bh          ; set sector
        mov bx, sp          ; manipulate SP with General Purpose register BX
        mov dx, [bx+4]      ; drive number was in stack all along!
        mov dh, al          ; set head
        mov ax, 0x0200+(ELF_SIZE/512)+1
                            ; AH=0x02: read sectors into memory - AL=n: read n sectors
        mov bx, 0x8000      ; target memory address
                            ; NOTE: assuming there is enough memory!
        int 0x13            ; BIOS Interrupt 13: Disk

        pop cx              ; get CX back
        jnc load_success    ; if no errors, we finished stage 1
        loop load_retry     ; retry (NOTE: untested code)

        push msg_loadFail
        push msgl_loadFail
        call print_msg

        jmp stop

    load_success:
        push msg_loadSuccess
        push msgl_loadSuccess
        call print_msg
        mov sp, bp          ; epilogue - restore stack
        ret

begin_protected_mode:
    push msg_enterPM
    push msgl_enterPM
    call print_msg
    
    cli                     ; disable Maskable Hardware Interrupts
                            ; NOTE: assuming no NMIs occur during mode switch
    lgdt [gdt_ptr]          ; load flat memory model GDT located at 0x7C00
    mov eax, 0x00000011
    mov cr0, eax            ; load CR0 with Protected Mode enabled
    jmp 0x08:protected_mode ; far jump to PM code

start:
    mov byte [currentLine], 2   ; initialize currentLine

    push msg_stage2
    push msgl_stage2
    call print_msg

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
    mov ebp, esp
    mov ebx, 0x8000     ; start of 'file'
    cmp dword [ebx], 0x464C457F
                        ; verify ELF magic
    jne invalid_elf
    add ebx, [ebx+28]   ; start of Program header ; specified 28 bytes into ELF header
    mov eax, [ebx+4]    ; entry offset, specified 4 bytes into Program header
    add eax, 0x8000     ; add the base
    mov esp, ebp
    ret

    invalid_elf:
        mov eax, 0xAAAAAAAA
        jmp stop

protected_mode:
    ; Welcome to Protected Mode! We have now access to 4 GiB of memory
    ; NOTE: A20 line hasn't been enabled, though QEMU does it automatically
    ;       I was unable to disable it, need to find an emulator that can do it
    ; NOTE: Interrupts are not set up yet. The program is unresponsive

    ; Initialize the segment registers with 32-bit descriptors
    mov eax, 0x00       ; 0x00: null descriptor
    mov es, eax
    mov fs, eax
    mov gs, eax
    mov eax, 0x10       ; 0x10: data descriptor
    mov ds, eax
    mov ss, eax

    call read_elf
    call eax            ; jump to ELF program :sunglasses:
    jmp stop

SEGMENT .bss
currentLine: resb 1     ; static variable for print_str

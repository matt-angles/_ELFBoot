;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MBR (BIOS) BootLoader for an x86_64 ELF  ;
; executable                               ;
;                                          ;
; Function: Configure the CPU for 64 bit   ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

gdt:
; Global Descriptor Table for 64-bit segmentation
; (the 64-bit code segment flags are set at runtime)
    .null:
    dq 0

    .code:
    dw 0xFFFF           ; Segment size [0:15]
    dw 0x0000           ; Base address [0:15]
    db 0x00             ; Base address [16:23]
    db 0b10011010       ; Flags (P, DPL=0, S) + Type (execute/read)
    db 0b11001111       ; Flags (G, 32b, ~64b) + Unused + Segment size [16:19]
    db 0x00             ; Base addres [24:31]

    .data:
    dw 0xFFFF           ; Segment size [0:15]
    dw 0x0000           ; Base address [0:15]
    db 0x0000           ; Base address [16:23]
    db 0b10010010       ; Flags (P, DPL=0, S) + Type (read/write)
    db 0b11001111       ; Flags (G, 32b, ~64b) + Unused + Segment size [16:19]
    db 0x00             ; Base addres [24:31]
gdt_ptr:
    dw $ - gdt - 1      ; GDT size
    dq gdt              ; GDT address (64-bit, truncated when used in PM)


unreal_mode:
    ; Temporarily modify GDT to make CS segment 16-bit compatible
    push word [gdt.code+6]
    mov [gdt.code+6], byte 0

    cli
    push gs             ; save real mode segment
    lgdt [gdt_ptr]
    mov eax, cr0
    or ax, 1
    mov cr0, eax        ; set CR0.PM
    jmp 0x08:($+5)      ; jump to next instruction (16-bit far JMP is 5 bytes)
    BITS 32
    mov ebx, 0x10
    mov gs, bx          ; GS=0x10: unreal mode segment
    and al, ~1
    mov cr0, eax        ; clear CR0.PM
    jmp 0x00:($+7)      ; jump to next instruction (32-bit far JMP is 7 bytes)
    BITS 16
    pop gs              ; voilà! gs is now our unreal mode segment
    sti

    pop word [gdt.code+6]
    ret

cpu_conf:
protected_mode:
    cli
    lgdt [gdt_ptr]
    mov eax, cr0
    or ax, 1
    mov cr0, eax        ; set CR0.PM
    jmp 0x08:($+5)      ; jump to next instruction (16-bit far JMP is 5 bytes)

; NOTE: need to verify 64-bit support
BITS 32
write_pagetable:
    ; Allocate the 1MB-2MB memory for page tables
    mov edi, 0x100000   ; 0x10000: start address
    mov esi, edi        ; for later
    xor eax, eax        ; 0x0000: copy value
    mov ecx, 8192       ; 0x20000: end address
    rep stosd

    mov dword [esi], 0x101003
    add esi, 0x1000     ; PML4 (512 GB)
    mov dword [esi], 0x102003
    add esi, 0x1000     ; PDPT (1 GB)
    mov dword [esi], 0x0083
    add esi, 8          ; PD   (2 MB)
    mov dword [esi], 0x200083

long_mode:
    mov eax, cr4
    or eax, (1 << 5)
    mov cr4, eax        ; set CR4.PAE

    mov eax, 0x100000
    mov cr3, eax        ; set CR3 to PML4 address

    mov eax, 0x100
    mov ecx, 0xC0000080
    wrmsr               ; set IA32_EFER.LME
    ; NOTE: could (should) verify if IA32_EFER.LMA

    mov eax, cr0
    or eax, (1 << 31)
    mov cr0, eax        ; set CR0.PG

    or byte [gdt.code+6], (1 << 5)
    and byte [gdt.code+6], ~(1 << 6)
    lgdt [gdt_ptr]      ; Modify the GDT to set the 64-bit code flags
    jmp 0x08:($+7)      ; far jump to next instruction

BITS 64
done:
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    jmp entry

BITS 16
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MBR (BIOS) BootLoader for an x86_64 ELF ;
; executable                              ;
;                                         ;
; Function: Configure the processor       ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%define PAGET_ADDR 0x100000
%define PAGET_SIZE 0x100000

%define ERR_CPUID  '0'
%define ERR_ECPUID '1'
%define ERR_NO64B  '2'
%define ERR_TO64B  '3'


SECTION .data
gdt:
; Global Descriptor Table for 64-bit segmentation
    .null:
    dq 0

    .code:
    dw 0xFFFF           ; Segment size [0:15]
    dw 0x0000           ; Base address [0:15]
    db 0x00             ; Base address [16:23]
    db 0b10011010       ; Flags (P, DPL=0, S) + Type (execute/read)
    db 0b11001111       ; Flags (G, 32b, ~64b) + Unused + Segment size [16:19]
                        ; (The 64b code flag is set at runtime)
    db 0x00             ; Base addres [24:31]

    .data:
    dw 0xFFFF           ; Segment size [0:15]
    dw 0x0000           ; Base address [0:15]
    db 0x00             ; Base address [16:23]
    db 0b10010010       ; Flags (P, DPL=0, S) + Type (read/write)
    db 0b11001111       ; Flags (G, 32b, ~64b) + Unused + Segment size [16:19]
    db 0x00             ; Base addres [24:31]
gdtPtr:
    dw $ - gdt - 1      ; GDT size - 1
    dq gdt              ; GDT address (truncated when used in 32-bit)


SECTION .text
unreal_mode:
; Function: make the GS segment an Unreal Mode segment
; Argument: none
; Return  : nothing
    ; Temporarily alter the GDT to retain CS 16-bit compatibility
    push word [gdt.code+6]
    mov byte [gdt.code+6], 0
                        ; Flags (~G, ~32b, ~64b) + Unused + Segment size [16:19]

    ; Switch to protected mode
    cli
    push gs             ; save real mode segment
    lgdt [gdtPtr]
    mov eax, cr0
    or al, 1
    mov cr0, eax        ; set CR0.PE
    jmp 0x08:($+5)      ; jump to next instruction (16-bit far JMP is 5 bytes)
    BITS 32

    ; Load GS's cache with a 32-bit size
    mov bx, 0x10
    mov gs, bx

    ; Switch back to real mode
    and al, ~1
    mov cr0, eax        ; clear CR0.PE
    jmp 0x00:($+7)      ; jump to next instruction (32-bit far JMP is 7 bytes)
    BITS 16
    pop gs              ; voilà! GS is an Unreal Mode segment
    sti

    ; Restore the 64-bit GDT
    pop word [gdt.code+6]
    ret


BITS 32
cpu_error:
; Function: display an error message and stop execution outside Real Mode
; Argument: DX = error char
    mov ax, 0x0400
    add ax, dx
    mov word [0xB8000], ax
                        ; 0xB8000: vga vram - 0x04: red color
    .stop:
        cli             ; disable software interrupts
        hlt             ; halt until next interrupt (not happening)
        jmp .stop       ; in case of hardware interrupts
BITS 16


cpu_conf:
; Function: do the necessary CPU configuration for 64-bit operation
; Argument: none
; Return  : does not return. jumps to the 'end' label
protected_mode:
    cli
    lgdt [gdtPtr]
    mov eax, cr0
    or al, 1
    mov cr0, eax        ; set CR0.PE
    jmp 0x08:($+5)      ; jump to next instruction (16-bit far JMP is 5 bytes)

BITS 32
check_64b:
    ; Check CPUID availability
    ; CPUID is available if EFLAGS.ID is modifiable
    pushfd              ; get EFLAGS value on stack
    mov eax, [esp]      ; EAX: old EFLAGS
    xor dword [esp], (1 << 21)
    popfd               ; toggle EFLAGS.ID
    pushfd              ; [ESP]: new EFLAGS
    cmp [esp], eax

    mov dx, ERR_CPUID   ; set error char, if needed
    je cpu_error        ; if [ESP]=EAX, EFLAGS.ID is not modifiable
    popfd               ; clear stack

    ; Check Extended CPUID availability
    mov eax, 0x80000000 ; EAX: maximum CPUID value (MAX)
    cpuid
    cmp eax, 0x80000001
    mov dx, ERR_ECPUID  ; set error char, if needed
    jb cpu_error        ; if EAX<=MAX, ECPUID is not supported

    ; Check Long Mode availability
    mov eax, 0x80000001 ; 0x80000001: extended processor signature & feature
    cpuid
    bt edx, 29          ; bit 29: long mode availability
    mov dx, ERR_NO64B   ; set error char, if needed
    jnc cpu_error       ; if clear, 64-bit not available

write_pagetable:
    ; Allocate memory for page tables
    mov edi, PAGET_ADDR ; EDI: address
    xor eax, eax        ; EAX=0: value
    mov ecx, (PAGET_SIZE+3)/4
                        ; ECX: size (in DWORDs)
    rep stosd           ; allocate ECX DWORDs at EDI

    ; Create two 2 MB pages
    mov esi, PAGET_ADDR
    mov dword [esi], PAGET_ADDR + 0x1003
    add esi, 0x1000     ; PML4 (512 GB)
    mov dword [esi], PAGET_ADDR + 0x2003
    add esi, 0x1000     ; PDPT (1 GB)
    mov dword [esi], 0x0083
    add esi, 8          ; PD   (2 MB)
    mov dword [esi], 0x200083

long_mode:
    mov eax, cr4
    or al, (1 << 5)
    mov cr4, eax        ; set CR4.PAE

    mov eax, PAGET_ADDR
    mov cr3, eax        ; set CR3 to PML4 address

    mov eax, 0x100
    mov ecx, 0xC0000080
    wrmsr               ; set IA32_EFER.LME

    mov eax, cr0
    or eax, (1 << 31)
    mov cr0, eax        ; set CR0.PG

    rdmsr
    mov dx, ERR_TO64B   ; set error char, if needed
    bt eax, 10          ; check IA32_EFER.LMA
    jnc cpu_error

    or byte [gdt.code+6], (1 << 5)
    and byte [gdt.code+6], ~(1 << 6)
    lgdt [gdtPtr]       ; modify the GDT to set the 64-bit code flags
    jmp 0x08:($+7)      ; jump to next instruction (32-bit far JMP is 7 bytes)

BITS 64
done:
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    jmp end

BITS 16

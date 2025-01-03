; x86 I/O wrapper functions

GLOBAL inb, inw, indw,  \
       outb, outw, outdw

%macro Prologue 0
    push ebp        ; Save the parent stack frame
    mov ebp, esp    ; Create a new stack frame for the current function
%endmacro
%macro Epilogue 0
    mov esp, ebp    ; Restore the stack from the stack frame
    pop ebp         ; Restore the parent stack frame
%endmacro

inb:
; uint8_t inb(uint16_t port) - GCC calling convention
    Prologue
    mov dx, [ebp+8]
    in al, dx
    Epilogue
    ret
inw:
; uint16_t inb(uint16_t port) - GCC calling convention
    Prologue
    mov dx, [ebp+8]
    in ax, dx
    Epilogue
    ret
indw:
; uint32_t inb(uint16_t port) - GCC calling convention
    Prologue
    mov dx, [ebp+8]
    in eax, dx
    Epilogue
    ret

outb:
; void outb(uint16_t port, uint8_t value) - GCC calling convention
    Prologue
    mov dx, [ebp+8]
    mov al, [ebp+12]
    out dx, al
    Epilogue
    ret
outw:
; void outw(uint16_t port, uint16_t value) - GCC calling convention
    Prologue
    mov dx, [ebp+8]
    mov ax, [ebp+12]
    out dx, ax
    Epilogue
    ret
outdw:
; void outw(uint16_t port, uint32_t value) - GCC calling convention
    Prologue
    mov dx, [ebp+8]
    mov eax, [ebp+12]
    out dx, eax
    Epilogue
    ret

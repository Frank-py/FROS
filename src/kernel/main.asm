org 0x7c00
bits 16

%define ENDL 0x0D, 0x0A

start:
    jmp main

; - ds:si points to string iterates until null character is reacher
puts:
    push si
    push ax
.loop:
    lodsb ; loads next charcter - load a byte from ds:si into al, then increment si
    or al, al 
    jz .done

    mov ah, 0x0e
    mov bh, 0
    int 0x10
    jmp .loop

.done:
    pop ax
    pop si
    ret 
    

main:
    mov ax, 0
    mov ds, ax
    mov es, ax


    ;stack
    mov ss, ax
    mov sp, 0x7c00

    mov si, msg_hello
    call puts

    hlt

.halt:
    jmp .halt

msg_hello: db 'Hello World', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h

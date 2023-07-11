org 0x7c00
bits 16

%define ENDL 0x0D, 0x0A
jmp short start
nop

; make fat work -> https://wiki.osdev.org/FAT
bdb_oem:                    db 'MSWIN4.1'
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                    ;2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5 inch floppy disk
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0
                            db 0
ebr_signature:              db 29h
ebr_volume_id:              db 13h, 31h, 54h, 23h       ; doesnt matter
ebr_volume_label:           db 'DANIEL OS  '
ebr_system_id:              db 'FAT12   '

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

    mov [ebr_drive_number], dl
    mov ax, 1               ; LBA = 1, second sector from disk
    mov cl, 1               ; 1 sector to read
    mov bx, 0x7E00          ; data should be after bootloader
    call disk_read



    mov si, msg_hello
    call puts

    cli                 ; disable interrups, cpu can't get out of halt state
    hlt

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot
    hlt

wait_key_and_reboot:
    mov ah, 0
    int 16h
    jmp 0FFFFh:0

.halt:
    cli                 ; disable interrups, cpu can't get out of halt state
    jmp .halt

; Disk routines

; Convert an LBA Logical block adress to CHS Cylinder HEAD SECTOR reading from disk(needed because bios only providess CBSSS functionality)
; Parameters:
;   - ax: LBA Adress
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
lba_to_chs:

    push ax
    push dx

    xor dx, dx          ; dx = 0
    div word [bdb_sectors_per_track]
    inc dx
    mov cx, dx ; Word = LBA = LBA/SECTORPTRACK + 1 in cx

    xor dx, dx
    div word [bdb_heads] ; ax = (lba/sectors) / *heads* = cylinder
                         ; dx = (lba/sectors) % *heads* = head

    
    mov dh, dl           ; dh = head
    mov ch, al           ; ch = cylinder (lower 8 bits) cx = CH(cylinder (8)) CL((2) + sector (6))  = 2 bytes
    shl ah, 6
    or cl, ah

    pop ax
    mov dl, al
    pop ax
    ret


; Reads sectors from a disk
;   - ax: LBA adress
;   - cl: number of sectors to read (up to 128)
;   - dl; drive number 
;   - es:bx: memory address where to store read data
disk_read:

    push ax
    push bx
    push cx
    push dx
    push di


    push cx
    call lba_to_chs
    pop ax                 ; AL(rechts weil klein endian) = number of sectors to read

    mov ah, 02h
    mov di, 3              ; We don't live in perfect worldd reading from floppy unreliable -> retry n times (min 3)

.retry:
    pusha                  ; save all registers, we dont know what bios modifies 
    stc                    ; carry flag must be set, sometimes doesn't work
    int 13h
    jnc .done                    ; if cleared meaning not carry

    popa
    call disk_reset

    dec di
    test di, di            ; checks if equal, sets Z flag, 
    jnz .retry             ; Während nicht 0, also 3 mal

.fail:
    ;   all attemps are exhausted
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret


msg_hello:          db 'Hello World', ENDL, 0
msg_read_failed:    db 'READ FAILED', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h

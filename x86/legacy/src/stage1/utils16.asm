%ifndef UTILS16_ASM
%define UTILS16_ASM

BITS 16                             ; use 16-bit Real Mode

%include "gdt.asm"
%include "bpb.asm"

; MACROS
; memory
%define START_STAGE2 0x7E00

; ascii
%define NL 0x0A                      ; '\n'
%define CR 0x0D                      ; CR

; writing string to the display
%macro write_string 1
    mov si, %1                       ; si = address of string aka %1
%%repeat:
    lodsb                            ; load a byte pointed by si
    cmp al, 0                        ; check for null terminated string
    je %%exit                        ; if true end procedure
    call write_char                  ; call sub procedure
    jmp %%repeat                     ; jump to repeat
%%exit:
%endmacro

; FUNCTIONS

; reak 64K from disk for the next stage
disk_read_64K:
    pusha
    xor di, di                      ; reset retry counter
    mov bx, START_STAGE2            ; set buffer for sector
    mov ax, 0x0280                  ;
    mov cx, 0x0002                  ; Set up registers for reading 64K from disk
    mov dx, 0x0080                  ;
.retry:
    int 0x13                        ; call BIOS interrupt
    jnc .ok                         ; if no carry (success), jump to success
    inc di                          ; increment retry counter
    cmp di, 3                       ; check if retried 3 times
    jne .retry                      ; if not, retry
    call print_disk_read_fail
    jmp .exit                       ; exit on failure after 3 retries
.ok:
    call print_disk_read_ok
.exit:
    popa
    ret

; enable a20 line
ena20:
    push ax
    in al, 0x93                     ; switch A20 gate via fast A20 port 92
    or al, 2                        ; set A20 Gate bit 1
    and al, ~1                      ; clear INIT_NOW bit
    out 0x92, al
    pop ax
    ret

; enable 32-bit Protected Mode
enpm:
    pusha
    cli                             ; disable interrupts
    lgdt [gdtr]                     ; load GDT

    mov eax, cr0
    or eax, 0x01                    ; enable protection bit in (Control reg)
    mov cr0, eax

    popa
    jmp CODE_SEG:_pstart            ; jump to the next stage

; writes char from string buffer which si points to
write_char:
    pusha
    mov ah, 0x0E                    ; display char in AL
    int 0x10                        ; call BIOS
    popa
    ret

; PRINT MESSAGES

print_disk_read_ok:
    pusha
    write_string disk_read_ok_str
    popa
    ret

print_disk_read_fail:
    pusha
    write_string disk_read_fail_str
    popa
    ret

print_disk_lba_sup_fail:
    pusha
    write_string disk_lba_sup_fail_str
    popa
    ret

; DATA
disk_read_ok_str:       db "Reading disk...OK",NL,CR,0
disk_read_fail_str:     db "Reading disk...FAIL",NL,CR,0
disk_lba_sup_fail_str:  db "LBA extensions not supported",NL,CR,0

%endif ; UTILS16_ASM
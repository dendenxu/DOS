;=========================================================
;copyright (c) Black White
;email: iceman@zju.edu.cn
;------------Structure of Descriptor----------------------
desc struc
lim_0_15   dw 0; +0-1 lower 16 bits for segment limit(total 20 bits)
bas_0_15   dw 0; +2-3 lower 16 bits for segment's base address(total 32 bits)
bas_16_23  db 0; +4   16-23 bits for segment's base address
access     db 0; +5   access right byte; P(B7) DPL(B65) S(B4) T(B321) A(B0)
gran       db 0; +6   granularity byte; G(B7) D(B6) 0(B5) AVL(B4) lim_16_19
bas_24_31  db 0; +7   higher 8 bits for segment's base address
;---------------------
;access:
;       P(B7)    Present bit(whether this segment exists)
;       DPL(B65) Descriptor Privilege Level bits(varies from 0 to 3)
;       S(B4)    Segment bit(segment's attr:1 for data/code segment descriptor;
;            0 for system descriptor(i.e. LDT and TSS desc.) and gate 
;            descriptor(i.e. task, call, interrupt, and trap gates' desc.))
;       T(B321)  Type bits:
;                1. if S==1(data/code segment)
;           B3: Execute bit(1 for code, 0 for data)
;           B2: Expand-down bit for data, Conform bit for code
;                   B1: Writable bit for data, Readable bit for code
;        2. if S==0(system desc. and gate desc.)
;           B3210: type for system desc. and gate desc.
;             00h: Undefined           08h: Undefined
;             01h: 286 TSS desc.       09h: 386 TSS desc.
;             02h: LDT desc.           0Ah: Undefined
;             03h: busy 286 TSS desc.  0Bh: busy 386 TSS desc.
;             04h: 286 call gate desc. 0Ch: 386 call gate desc.
;             05h: task gate desc.     0Dh: Undefined
;             06h: 286 intr gate desc. 0Eh: 386 intr gate desc.
;             07h: 286 trap gate desc. 0Fh: 386 trap gate desc.
;       A(B0)    Access bit: 1 for accessed, 0 for not accessed
;gran:
;     granularity byte.
;     G(B7)      Granularity bit: 1 for page granularity,
;                 0 for byte granularity
;     D(B6)      Data attr bit: 1 for 32-bit addr, 0 for 16-bit addr
;     0(B5)      Reserved bit: should be kept 0
;     AVL(B4)    Available bit: kept for user
;     lim_16-19(B3210) higher 4 bits for segment limit
;-------------------------
desc ends
;-----------End of Structure of descriptor---------

;----------Structure of gdtr-----------------------
_gdtr struc
_gdtr_lim       dw 0
_gdtr_bas_0_15  dw 0
_gdtr_bas_16_31 dw 0
_gdtr ends
;---------End of Structure of gdtr-----------------

stack segment stack
      dw 400h dup(0)
stack ends

data segment
gdt _gdtr <gdt_len, 0, 0>
fill_two_bytes db 0, 0
vram_sele equ $-gdt; 08h
vram_desc desc <0FFFFh,8000h,0Ah,93h,0Fh,00h> ; 0F or 4F
road_sele equ $-gdt; 10h
road_desc desc <0FFFFh,0000h,00h,9Bh,00h,00h>
pseg_sele equ $-gdt; 18h
pseg_desc desc <pseg_len,0000h,00h,9Bh,40h,00h>
gdt_len equ $-offset gdt
succ_msg db 'Success!',0Dh,0Ah,'$'
fail_msg db 'Failure!',0Dh,0Ah,'$'
data ends

.386P
pseg segment
assume cs:pseg
protect:
    cld
    mov ax,vram_sele; offset vram_desc
    mov ds,ax
    mov es,ax
    mov ecx,80*25
    mov esi,10000h
    mov edi,esi
reverse_color:
    lodsw; AX=DS:[ESI], ESI+=2
    ror ah,4
    stosw
    loop reverse_color
    mov eax,cr0
    and eax,7FFFFFFEh
    db 0EAh     ; JMP FAR PTR
    dd offset road
    dw road_sele
pseg_len equ $-protect
pseg ends

road_seg segment
assume cs:road_seg
road:
    mov cr0,eax; Return to real mode!
    db 0EAh    ; Now return to real mode! Use real mode address!
    dw offset back_real
    dw code
road_seg_len equ $-offset road
road_seg ends

.286P
code segment
assume cs:code,ds:data,ss:stack
main:
    call enable_addr
    jz open_addr_ok
    jmp error
open_addr_ok:
    mov dx,data
    mov ds,dx
    mov cx,offset gdt
    call form_addr
    mov gdt._gdtr_lim, gdt_len
    mov gdt._gdtr_bas_0_15, dx
    mov gdt._gdtr_bas_16_31, cx
    mov dx,pseg
    xor cx,cx
    call form_addr
    mov pseg_desc.bas_0_15,dx
    mov pseg_desc.bas_16_23,cl
    mov dx,road_seg
    xor cx,cx
    call form_addr
    mov road_desc.bas_0_15,dx
    mov road_desc.bas_16_23,cl
    lgdt fword ptr gdt
    cli
    smsw ax    ; save machine status word
    and ax,1Fh
    or al,1
    lmsw ax; enable PE bit of MSW or CR0
    db 0EAh; JMP FAR PTR
    dw 00h 
    dw pseg_sele; pseg's segment selector

form_addr proc; DX=1002h, CX=0034h
    rol dx,4    ; DX=0021h
    mov ax,dx
    and dl,0F0h ; DX=0020h
    and ax,0Fh  ; AX=0001h
    add dx,cx   ; DX=0054h
    mov cx,ax   ; CX=0001h
    adc cl,ch   ; CX=0001h 
    xor ch,ch   ; CX:DX=0001 0054h
    ret
form_addr endp

enable_addr proc
    call test_64h
    jnz enable_exit
    mov al,0D1h
    out 64h,al
    call test_64h
    jnz enable_exit
    mov al,0B7h
    call test_cmos
    and al,0Ch
    or al,0D3h
    out 60h,al
    call test_64h
enable_exit:
    ret
enable_addr endp

disable_addr proc
    call test_64h
    jnz disable_exit
    mov al,0D1h
    out 64h,al
    call test_64h
    jnz disable_exit
    mov al,0B7h
    call test_cmos
    and al,0Ch
    or al,0D1h
    out 60h,al
    call test_64h
disable_exit:
    ret
disable_addr endp

test_64h proc
    push cx
    xor cx,cx
test_again:
    in al,64h
    jmp $+2
    test al,2
    loopnz test_again
    jz test_64h_ret
test_next:
    in al,64h
    jmp $+2
    test al,2
    loopnz test_next
test_64h_ret:
    pop cx
    ret
test_64h endp

test_cmos proc
    out 70h,al
    jmp $+2
    jmp $+2
    in al,71h
    ret
test_cmos endp

back_real:
    mov ax,data
    mov ds,ax
    call disable_addr
    sti
    mov ax,data
    mov ds,ax
    mov dx,offset succ_msg
    jmp exit
error:
    mov dx,offset fail_msg
exit:
    mov ah,9
    int 21h
    mov ah,4Ch
    int 21h
code ends
end main

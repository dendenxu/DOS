data segment
fp dw 0 ; file pointer
file_len dw 2 dup(0) ; file length
location dw 2 dup(0) ; location of the found pattern
read_len dw buf_size
remained_len dw 0
processed_len dw 0
raw_len dw 0
buf_len dw 0
raw db 0ffh dup(0) ; raw hexadecimal value read from input
; this area is used along with int 21h ah = 0ah
hex_len db hex_size
hex_re db 0
hex db 0ffh dup(0) ; hexadecimal temp storage
hex_size equ $-hex
filename_len db filename_size
filename_re db 0
filename db 0ffh dup(0) ; filename temp storage
filename_size equ $-filename
buf db 400h dup(0) ; buffer for reading the file
buf_size equ $-buf ; buffer size
; 24h is '$'
unable_to_open_file_msg db "ERROR: unable to open the file specified, check that the file exists", 0dh, 0ah, "The program will now exit...", 24h
illegal_input_msg db "ERROR: unable to process your hexadecimal input, check that the number of chars you input is even and ABCDEF are upper-case", 0dh, 0ah, "The program will now exit...", 24h
not_found_msg db "not found", 24h
data ends

code segment
assume cs:code, ds:data
main proc
    ; initializing ds
    mov ax, data
    mov ds, ax
    mov es, ax
    ; read in the filename
    mov ah, 0ah
    mov dx, offset filename_len
    int 21h
    ; clear the 0dh read by int 21h ah=0ah
    xor bx, bx
    mov bl, filename_re
    mov byte ptr [filename+bx], 0
    ; add a new line
    mov dl, 0ah
    mov ah, 02h
    int 21h
    ; try opening the file
    call open_file
    jc unable_to_open_file
    ; try getting the file length
    call get_file_len
    ; read in hexadecimal to be searched on
    mov ah, 0ah
    mov dx, offset hex_len
    int 21h
    ; clear the 0dh read by int 21h ah=0ah
    xor bx, bx
    mov bl, hex_re
    mov byte ptr [hex+bx], 0
    ; add a new line
    mov dl, 0ah
    mov ah, 02h
    int 21h
    
    call convert_hex
    jc illegal_input

    call search_in_file
    jc not_found

    ; quit the program
quit:
    mov al, 0
    mov ah, 4ch
    int 21h
unable_to_open_file:
    mov dx, offset unable_to_open_file_msg
    mov ah, 09h
    int 21h
    jmp quit
illegal_input:
    mov dx, offset illegal_input_msg
    mov ah, 09h
    int 21h
    jmp quit
not_found:
    mov dx, offset not_found_msg
    mov ah, 09h
    int 21h
    jmp quit
main endp

; @param [raw] raw value to be searched on
; @param [fp] file pointer of the file to be operated on
; the cursor is guaranteed to be at the start of the file
; @return [location] the location of the first found char
; note that if there's multiple matches, only the first one will be considered
; if found, carry flag is cleared
; if not found, carry flag is set
search_in_file proc
    ; bear in mind that the length of the file
    ; or the location can be 32-bit
    ; but we made sure the buffer is no more than 16-bit
next_buf:
    mov ax, [location]
    add ax, [processed_len]
    mov [location], ax
    mov ax, [location+2]
    adc ax, 0
    mov [location+2], ax
    mov cx, [file_len+2]
    cmp cx, 0
    jnz buf_all
    mov cx, [file_len]
    cmp cx, buf_size
    ja buf_all
    jmp read_in
buf_all:
    mov cx, [read_len]
read_in:
    mov [read_len], cx
    mov ah, 3Fh
    mov bx, [fp]
    mov dx, offset buf
    add dx, [remained_len]
    int 21h
    call update_file_len
    mov ax, [remained_len]
    add ax, [read_len]
    mov [buf_len], ax
    cmp ax, [raw_len]
    jb never_occur
    call check_buffer
    jnc return
    call update_processed_remained
    call memcpy
    neg ax
    add ax, [buf_len]
    mov [read_len], ax
    mov cx, [file_len+2]
    cmp cx, 0
    jnz next_buf
    mov cx, [file_len]
    cmp cx, 0
    jnz next_buf ; relative jump may be out of range, be careful
never_found_here:
    stc
return:
    ret
update_processed_remained:
    mov ax, 0
    adc ax, [buf_len]
    sub ax, [raw_len]
    mov [processed_len], ax
    mov ax, [raw_len]
    dec ax
    mov [remained_len], ax
    ret
memcpy:
    cld
    mov di, offset buf
    mov si, offset buf
    add si, [processed_len]
    mov cx, [remained_len]
    rep movsb
    ret
update_file_len:
    mov ax, [file_len]
    sub ax, [read_len]
    mov [file_len], ax
    mov ax, [file_len+2]
    sbb ax, 0
    mov [file_len+2], ax
    ret
search_in_file endp

; @param cx set to the length of the string
check_buffer proc
    xor si, si
    lea di, [raw+1]
    mov al, [raw]
check_next:
    inc si
    cmp al, buf[si]
    jz might_equal
    dec cx
    jcxz never_occur
    jmp check_next
never_occur:
    stc
    ret
might_equal:
    push cx
    mov cx, [raw_len]
    dec cx
    repe cmpsb
    jcxz found
    pop cx
    dec cx
    jmp check_next
found:
    add si, [location]
    mov [location+2], si
    mov ax, [location+2]
    adc ax, 0
    mov [location+2], ax
    clc
    ret
check_buffer endp

; @param [hex] the buffer hex to be converted on
; @return [raw] raw value of the converted hexadecimal chars
; if the input is illegal, carry flag is set, otherwise carry flag is cleared
convert_hex proc
    mov si, 0
    mov di, 0
trim_next:
    mov al, hex[si]
    cmp al, 0
    jz trim_done
    inc si
    cmp al, 20h
    jz trim_next
    mov hex[di], al
    inc di
    jmp trim_next
trim_done:
    ; size of bytes after trimming white space is di
    mov cx, di
    mov ax, di
    shr ax, 1
    mov [raw_len], ax
    test cl, 00000001b
    jnz error
    xor si, si
    xor di, di
next_byte:
    xor bx, bx
    xor dl, dl
next_4_bit:
    mov al, hex[si+bx]
    cmp al, '9'
    jbe is_digit
    sub al, 'A' - '0' - 10; the added '0' will be trimmed in the following instruction
    cmp al, '0' + 0fh
    ja error
is_digit:
    sub al, '0'
    jb error
    shl dl, 4 ; This instruction is expanded to four shl dl, 1 in TASM
              ; and is not accepted in MASM
    add dl, al
    inc bx
    cmp bx, 2
    jnz next_4_bit
    ; byte processed
    mov raw[di], dl
    add si, 2
    inc di
    cmp si, cx
    jnz next_byte
    clc
    ret
error:
    stc
    ret

convert_hex endp

; @param [filename] the name of the file to be opened
; @return [fp] file pointer if file is successfully opened, error code if failed to open
; and carry flag is set if failed to open
open_file proc
    mov ah, 3Dh
    mov al, 0
    mov dx, offset filename
    int 21h
    mov [fp], ax
    ret
open_file endp


; @param [fp] the file pointer
; @return [file_len] the length of the file(double word:32-bit)
; file pointer is moved to the start after calculation
get_file_len proc
    mov ah, 42h
    ; AL = origin of move
    ; 00h start of file
    ; 01h current file position
    ; 02h end of file
    mov al, 2
    mov bx, [fp]
    ; CX:DX = (signed) offset from origin of new file position
    ; set to zero to go to the end of the file
    xor cx, cx
    xor dx, dx
    int 21h; lseek - set current file position
    mov word ptr file_len[0], ax
    mov word ptr file_len[2], dx
    ; reset file pointer to the start
    mov ah, 42h
    mov al, 0
    xor dx, dx
    int 21h
    ret
get_file_len endp

code ends
end main
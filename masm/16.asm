; Some major functions are wrapped with proc and endp
; smaller functions are implemented with label only
; some small functions exist for code readability and for avoiding far jmp with comparison
data segment
; this section is used to store some important information during the life cycle of the program
fp dw 0 ; file pointer
file_len dw 2 dup(0) ; file length
location dw 2 dup(0) ; location of the found pattern
read_len dw buf_size ; the length to be read next time, initially it is the size of the whole buffer
remained_len dw 0 ; remained length to be omitted on next read, usually it is the length of the hex code minus one
processed_len dw 0
raw_len dw 0
buf_len dw 0
raw db 0ffh dup(0) ; raw hexadecimal value read from input

; this section of memory is used along with int 21h ah = 0ah
; the previous section is used to store useful debug info and is relatively short, easy to read in tb's dump window
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

; this section is used for storing output information, including some error message and the temp storage for the found address in ASCII
; 24h is '$'
unable_to_open_file_msg db "ERROR: unable to open the file specified, check that the file exists", 0dh, 0ah, "The program will now exit...", 24h
illegal_input_msg db "ERROR: unable to process your hexadecimal input, check that the number of chars you input is even and ABCDEF are upper-case", 0dh, 0ah, "The program will now exit...", 24h
not_found_msg db "not found", 24h
found_msg db "found at ", 24h
output_16_char db 4 dup(0), '$'
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
    ; communication is constructed based on carry flag
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
    ; try converting the read hexadecimal string to raw hexadecimal value
    ; it checks parity of the input, and for simplicity it can only process upper case in hexadecimal
    ; however, multiple white space between two byte is allowed (ASCII: 20h)
    ; don't worry, if your input is illegal the program will prompt and automatically exit
    call convert_hex
    jc illegal_input
    ; try to search for the hexadecimal string in the file specified
    call search_in_file
    jc not_found
    ; found a match
    ; output: found at
    mov dx, offset found_msg
    mov ah, 09h
    int 21h
    ; sequentially output the hexadecimal of the location of the first found match
    ; here I used the code written in the previous homework
    mov ax, [location+2]
    call output_16
    mov ax, [location]
    call output_16
    ; output 0dh 0ah (line break)
    xor al, al
    ; quit the program
quit:
    ; calling int 21h (ah = 4Ch)
    mov ah, 4ch
    int 21h
unable_to_open_file:
    mov dx, offset unable_to_open_file_msg
    mov ah, 09h
    int 21h
    mov al, 1
    jmp quit
illegal_input:
    mov dx, offset illegal_input_msg
    mov ah, 09h
    int 21h
    mov al, 2
    jmp quit
not_found:
    mov dx, offset not_found_msg
    mov ah, 09h
    int 21h
    mov al, 3
    jmp quit
main endp

; @param no param
; @return return nothing
; @function print a line break to console
crlf:
    mov ah, 02h
    mov dl, 0dh
    int 21h
    mov dl, 0ah
    int 21h
    ret

; @param eax the hexadecimal to be printed on the screen
; @function output a 2-byte (word) hexadecimal value to console
; @note modifies the value of result_char to store the 16-bit string
output_16:
    mov cx, 4
    xor di, di
out16_again:
    push cx
    mov cl, 4
    rol ax, cl
    push ax
    and ax, 0fh ; Get only the least four bits of ax
    cmp ax, 10
    jb is_digit
is_alpha:
    sub al, 10
    add al, 'A' ; Print hexadecimal in uppercase
    jmp finish_4bits
is_digit:
    add al, '0'
finish_4bits:
    mov output_16_char[di], al
    pop ax
    pop cx
    inc di
    dec cx
    jnz out16_again
    mov ah, 09h
    mov dx, offset output_16_char
    int 21h
    ret

; @param [raw] raw value to be searched on
; @param [fp] file pointer of the file to be operated on
; @prerequisite the cursor should be at the start of the file
; @return [location] the location of the first found char
; @return if found, carry flag is cleared
; @return if not found, carry flag is set
; @note if there's multiple matches, only the first one will be considered
search_in_file proc
    ; bear in mind that the length of the file
    ; or the location can be 32-bit (meaning the file can be almost 4GB at most)
    ; but we made sure the buffer is no more than 16-bit (which is 64k)
    ; and the registers we use are all 2-byte long
    ; here we use a 400h byte buffer, and it could be set larger
next_buf:
    call set_up_location ; this exists to reduce relative jump distance
    ; determine the bytes to read ([read_len])
    mov cx, [file_len+2]
    cmp cx, 0
    jnz buf_all
    mov cx, [file_len]
    cmp cx, [read_len]
    ja buf_all
    jmp read_in
buf_all:
    mov cx, [read_len]
read_in:
    mov [read_len], cx
    ; read information in buffer using int 21h (ah = 3fh)
    ; cx is already set above
    mov ah, 3fh
    mov bx, [fp]
    mov dx, offset buf
    add dx, [remained_len]
    int 21h
    ; update the length of the file (how many bytes to read?)
    call update_file_len
    ; check whether remained buffer size is too small and update buffer size
    mov ax, [remained_len]
    add ax, [read_len]
    mov [buf_len], ax
    cmp ax, [raw_len]
    jb never_found_here
    mov cx, [buf_len]
    sub cx, [raw_len]
    add cx, 2
    call check_buffer
    jnc return
    call update_processed_remained
    ; use movsb to imitate memcpy
    call memcpy
    ; ax is set to remained_len in the call of update_processed_remained
    neg ax
    add ax, buf_size
    mov [read_len], ax
    ; check that the the file is still left to read
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
    ; this line shouldn't be xor ax, ax because we have to preserve carry flag
    ; or you can manually set carry flag
    xor ax, ax
    stc
    ; we need to add 1 here
    ; and carry flag is guaranteed to be set here
    ; so by using adc we can use less line
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
set_up_location:
    mov ax, [location]
    add ax, [processed_len]
    mov [location], ax
    mov ax, [location+2]
    adc ax, 0
    mov [location+2], ax
    ret
search_in_file endp

; @param cx set to the length of the string
check_buffer proc
    xor si, si
    mov al, [raw]
check_next:
    lea di, [raw+1]
    push di
    mov di, si
    add di, offset buf
    cld
    repne scasb
    sub di, offset buf
    mov si, di
    pop di
    jcxz never_occur
    jmp might_equal
never_occur:
    stc
    ret
might_equal:
    cld
    push cx
    cmp cx, 1
    jz found
    push si
    add si, offset buf
    mov cx, [raw_len]
    repe cmpsb
    pop si
    jcxz found
    pop cx
    jmp check_next
found:
    pop cx
    dec si
    add si, [location]
    mov [location], si
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
    xor si, si
    xor di, di
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
    jbe is_a_digit
    sub al, 'A' - '0' - 10; the added '0' will be trimmed in the following instruction
    cmp al, '0' + 0fh
    ja error
is_a_digit:
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
    mov raw[di], 0
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
    xor al, al
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
    xor al, al
    xor dx, dx
    int 21h
    ret
get_file_len endp

code ends
end main
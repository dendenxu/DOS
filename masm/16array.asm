data segment
a db "ABC"
s db "Hello$world!", 0Dh, 0Ah, 0
data ends
code segment
assume cs:code, es:data
opt db "Hey You!", 0Dh, 0Ah, 0
main:
comment #
This is Multiline Comment
#
again:
	mov dl, opt[bx]
	cmp dl, 0
	je part1_end
	mov ah, 2
	int 21h
	add bx, 1
	jmp again
part1_end:
	;�ε�ַ�����Գ�����ʽ��ֵ
   	mov ax, data
   	mov es, ax
   	mov bx, 0
next:
   	mov dl, s[bx]; �����������mov dl, ds:[3+bx]
   	cmp dl, 0
   	je exit
   	mov ah, 2
   	int 21h
   	add bx, 1
   	jmp next
exit:
   	mov ah, 4Ch
   	int 21h
code ends
end main

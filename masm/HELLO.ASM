data segment
abc db "hello, world!", 0Dh, 0Ah, "$"
data ends
code segment
assume cs:code, ds:data
main:
   mov ax, data
   mov ds, ax
   mov ah, 9
   mov dx, offset abc
   int 21h
   mov ah, 4Ch
   int 21h
code ends
end main

.386
.model flat, stdcall
option casemap :none            ; 标准头格式

include D:\masm32\include\windows.inc     ; 同C中#include
include D:\masm32\include\kernel32.inc
include D:\masm32\include\user32.inc

includelib D:\masm32\lib\kernel32.lib     ;
includelib D:\masm32\lib\user32.lib

.data                       ; 标志数据定义开始
result db 100 dup(0)        ; dup:duplicate重复;
; char result[100]={0};
format db "%d", 0           ; db: define byte字节类型
; char format[] = "%d";
prompt db "The Result", 0   ; 0: '\0'
; char prompt[] = "The Result";

.code
main:               ;标号(Label)
    mov eax, 0
    mov ebx, 1
next:
    add eax, ebx
    add ebx, 1
    cmp ebx, 100    ; cmp: Compare
    jbe next        ; jbe: Jumpif Below / Equal

    invoke wsprintf, offset result, offset format, eax      
    invoke MessageBox, 0, offset result, offset prompt, 0   

end main            ; 指定程序的起始执行点
                    ; end后面的标号决定了程序刚开始运行时的eip值
#include <mem.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

long find(FILE *fp, long n, char s[])
{
    unsigned char hex[100];
    unsigned char buf[0x400];
    unsigned char *p, *q;
    int i, hex_len, buf_len, read_len, processed_len, remained_len, distance;
    long offset = 0;
    hex_len = (strlen(s) + 1) / 3; /* 求十六进制串中包含的字节数, 如
                                 "68 3E 0D 0A"包含4个字节
                               */
    for (i = 0; i < hex_len; i++)  /* 把十六进制串转化成字节值, 如"41 42 43"转化成41h,42h,43h */
        sscanf(s + i * 3, "%x", &hex[i]);
    read_len = sizeof(buf); /* 本次要读的字节数 */
    processed_len = 0;      /* 上次已搜索过的字节数 */
    remained_len = 0;       /* 上次搜索时余下没搜的字节数 */
    while (n != 0) {
        offset += processed_len;
        /* processed_len是上次已搜索过的字节数,
          offset为buf[0]中的那个字节距离文件开端的偏移量
        */
        read_len = n < read_len ? n : read_len;     /* read_len是本次要读的字节数 */
        fread(buf + remained_len, 1, read_len, fp); /* 读取read_len字节到buf+remained_len中 */
        /* 汇编语言读文件步骤:
         mov ah, 3Fh
         mov bx, [fp]
         mov cx, read_len
         mov dx, offset buf
         add dx, remained_len
         int 21h
       */
        n -= read_len; /* n为文件中剩余未读的字节数 */
        buf_len = remained_len + read_len;
        if (buf_len < hex_len) /* 若buf中的字节数不足, 则n一定为0, 于是回上去结束循环 */
            continue;
        q = buf; /* q为本次搜索起点 */       /*   |    假定在"ABCDE"中搜"CDE", 则      */
        while (q <= buf + buf_len - hex_len) /* ABCDE  竖线处为最后一个搜索点, 共搜3次 */
        {
            distance = (buf + buf_len - hex_len) - q + 1;
            p = memchr(q, hex[0], distance); /* 在[q, q+distance-1]范围内寻找hex[0] */
            /* 汇编语言可以用repne scasb指令实现memchr()的功能 */
            if (p == NULL) /* 若没有找到, 则放弃当前buf中的内容 */
                break;
            if (memcmp(p, hex, hex_len) != 0) /* 比较p和hex指向的hex_len字节是否相同 */
            {                                 /* 汇编语言可以用repne cmpsb实现memcmp()的功能 */
                q = p + 1;                    /* 若不相同, 则下个搜索点=p+1 */
                continue;
            }
            return offset + (p - buf); /* 若相同, 则返回偏移量 */
        }
        processed_len = buf_len - hex_len + 1;
        q = buf + processed_len;
        remained_len = hex_len - 1;
        memcpy(buf, q, remained_len);
        /* 汇编语言中可以用rep movsb实现memcpy()的功能 */
        read_len = sizeof(buf) - remained_len; /* 计算下次要读的最大字节数 */
    }
    return -1; /* 若搜遍整个文件没有找到, 则返回-1 */
}

main()
{
    FILE *fp;
    char filename[16];
    char s[100];
    long int n, offset;
    puts("Input file name:");
    gets(filename);
    puts("Input a hex string, e.g. 41 42 43 0D 0A");
    gets(s);
    fp = fopen(filename, "rb");
    /* 汇编语言打开文件步骤:
      mov ah, 3Dh
      mov al, 0
      mov dx, offset filename
      int 21h
      jc error
      mov [fp], ax; 数据段中要事先定义fp dw 0
      ...
    error:
     */
    if (fp == NULL)
        exit(0);
    fseek(fp, 0, SEEK_END); /* 移动文件指针到EOF */
    /* 汇编语言移动文件指针到EOF:
      mov ah, 42h
      mov al, 2
      mov bx, [fp]
      xor cx, cx
      xor dx, dx
      int 21h; 返回DX:AX为文件长度
    */
    n = ftell(fp); /* 获取当前文件指针离文件开端的距离即文件长度 */
    /* 汇编语言把文件长度保存到变量n中:
      mov word ptr n[0], ax
      mov word ptr n[2], dx
    */
    fseek(fp, 0, SEEK_SET); /* 移动文件指针到文件开端, 以便后面读取文件内容 */
    /* 汇编语言移动文件指针到开端:
      mov ah, 42h
      mov al, 0
      mov bx, [fp]
      xor cx, cx
      xor dx, dx
      int 21h
     */
    offset = find(fp, n, s); /* 在长度为n字节的文件中搜索十六进制串s, 若找到
                               则返回该串在文件内的偏移量, 否则返回-1
                             */
    fclose(fp);
    if (offset != -1)
        printf("found at %08lX\n", offset);
    else
        puts("Not found!");
    getchar();
}

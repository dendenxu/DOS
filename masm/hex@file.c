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
    hex_len = (strlen(s) + 1) / 3; /* ��ʮ�����ƴ��а������ֽ���, ��
                                 "68 3E 0D 0A"����4���ֽ�
                               */
    for (i = 0; i < hex_len; i++)  /* ��ʮ�����ƴ�ת�����ֽ�ֵ, ��"41 42 43"ת����41h,42h,43h */
        sscanf(s + i * 3, "%x", &hex[i]);
    read_len = sizeof(buf); /* ����Ҫ�����ֽ��� */
    processed_len = 0;      /* �ϴ������������ֽ��� */
    remained_len = 0;       /* �ϴ�����ʱ����û�ѵ��ֽ��� */
    while (n != 0) {
        offset += processed_len;
        /* processed_len���ϴ������������ֽ���,
          offsetΪbuf[0]�е��Ǹ��ֽھ����ļ����˵�ƫ����
        */
        read_len = n < read_len ? n : read_len;     /* read_len�Ǳ���Ҫ�����ֽ��� */
        fread(buf + remained_len, 1, read_len, fp); /* ��ȡread_len�ֽڵ�buf+remained_len�� */
        /* ������Զ��ļ�����:
         mov ah, 3Fh
         mov bx, [fp]
         mov cx, read_len
         mov dx, offset buf
         add dx, remained_len
         int 21h
       */
        n -= read_len; /* nΪ�ļ���ʣ��δ�����ֽ��� */
        buf_len = remained_len + read_len;
        if (buf_len < hex_len) /* ��buf�е��ֽ�������, ��nһ��Ϊ0, ���ǻ���ȥ����ѭ�� */
            continue;
        q = buf; /* qΪ����������� */       /*   |    �ٶ���"ABCDE"����"CDE", ��      */
        while (q <= buf + buf_len - hex_len) /* ABCDE  ���ߴ�Ϊ���һ��������, ����3�� */
        {
            distance = (buf + buf_len - hex_len) - q + 1;
            p = memchr(q, hex[0], distance); /* ��[q, q+distance-1]��Χ��Ѱ��hex[0] */
            /* ������Կ�����repne scasbָ��ʵ��memchr()�Ĺ��� */
            if (p == NULL) /* ��û���ҵ�, �������ǰbuf�е����� */
                break;
            if (memcmp(p, hex, hex_len) != 0) /* �Ƚ�p��hexָ���hex_len�ֽ��Ƿ���ͬ */
            {                                 /* ������Կ�����repne cmpsbʵ��memcmp()�Ĺ��� */
                q = p + 1;                    /* ������ͬ, ���¸�������=p+1 */
                continue;
            }
            return offset + (p - buf); /* ����ͬ, �򷵻�ƫ���� */
        }
        processed_len = buf_len - hex_len + 1;
        q = buf + processed_len;
        remained_len = hex_len - 1;
        memcpy(buf, q, remained_len);
        /* ��������п�����rep movsbʵ��memcpy()�Ĺ��� */
        read_len = sizeof(buf) - remained_len; /* �����´�Ҫ��������ֽ��� */
    }
    return -1; /* ���ѱ������ļ�û���ҵ�, �򷵻�-1 */
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
    /* ������Դ��ļ�����:
      mov ah, 3Dh
      mov al, 0
      mov dx, offset filename
      int 21h
      jc error
      mov [fp], ax; ���ݶ���Ҫ���ȶ���fp dw 0
      ...
    error:
     */
    if (fp == NULL)
        exit(0);
    fseek(fp, 0, SEEK_END); /* �ƶ��ļ�ָ�뵽EOF */
    /* ��������ƶ��ļ�ָ�뵽EOF:
      mov ah, 42h
      mov al, 2
      mov bx, [fp]
      xor cx, cx
      xor dx, dx
      int 21h; ����DX:AXΪ�ļ�����
    */
    n = ftell(fp); /* ��ȡ��ǰ�ļ�ָ�����ļ����˵ľ��뼴�ļ����� */
    /* ������԰��ļ����ȱ��浽����n��:
      mov word ptr n[0], ax
      mov word ptr n[2], dx
    */
    fseek(fp, 0, SEEK_SET); /* �ƶ��ļ�ָ�뵽�ļ�����, �Ա�����ȡ�ļ����� */
    /* ��������ƶ��ļ�ָ�뵽����:
      mov ah, 42h
      mov al, 0
      mov bx, [fp]
      xor cx, cx
      xor dx, dx
      int 21h
     */
    offset = find(fp, n, s); /* �ڳ���Ϊn�ֽڵ��ļ�������ʮ�����ƴ�s, ���ҵ�
                               �򷵻ظô����ļ��ڵ�ƫ����, ���򷵻�-1
                             */
    fclose(fp);
    if (offset != -1)
        printf("found at %08lX\n", offset);
    else
        puts("Not found!");
    getchar();
}

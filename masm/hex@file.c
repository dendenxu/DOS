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
    hex_len = (strlen(s) + 1) / 3; /* ÇóÊ®Áù½øÖÆ´®ÖÐ°üº¬µÄ×Ö½ÚÊý, Èç
                                 "68 3E 0D 0A"°üº¬4¸ö×Ö½Ú
                               */
    for (i = 0; i < hex_len; i++)  /* °ÑÊ®Áù½øÖÆ´®×ª»¯³É×Ö½ÚÖµ, Èç"41 42 43"×ª»¯³É41h,42h,43h */
        sscanf(s + i * 3, "%x", &hex[i]);
    read_len = sizeof(buf); /* ±¾´ÎÒª¶ÁµÄ×Ö½ÚÊý */
    processed_len = 0;      /* ÉÏ´ÎÒÑËÑË÷¹ýµÄ×Ö½ÚÊý */
    remained_len = 0;       /* ÉÏ´ÎËÑË÷Ê±ÓàÏÂÃ»ËÑµÄ×Ö½ÚÊý */
    while (n != 0) {
        offset += processed_len;
        /* processed_lenÊÇÉÏ´ÎÒÑËÑË÷¹ýµÄ×Ö½ÚÊý,
          offsetÎªbuf[0]ÖÐµÄÄÇ¸ö×Ö½Ú¾àÀëÎÄ¼þ¿ª¶ËµÄÆ«ÒÆÁ¿
        */
        read_len = n < read_len ? n : read_len;     /* read_lenÊÇ±¾´ÎÒª¶ÁµÄ×Ö½ÚÊý */
        fread(buf + remained_len, 1, read_len, fp); /* ¶ÁÈ¡read_len×Ö½Úµ½buf+remained_lenÖÐ */
        /* »ã±àÓïÑÔ¶ÁÎÄ¼þ²½Öè:
         mov ah, 3Fh
         mov bx, [fp]
         mov cx, read_len
         mov dx, offset buf
         add dx, remained_len
         int 21h
       */
        n -= read_len; /* nÎªÎÄ¼þÖÐÊ£ÓàÎ´¶ÁµÄ×Ö½ÚÊý */
        buf_len = remained_len + read_len;
        if (buf_len < hex_len) /* ÈôbufÖÐµÄ×Ö½ÚÊý²»×ã, ÔònÒ»¶¨Îª0, ÓÚÊÇ»ØÉÏÈ¥½áÊøÑ­»· */
            continue;
        q = buf; /* qÎª±¾´ÎËÑË÷Æðµã */       /*   |    ¼Ù¶¨ÔÚ"ABCDE"ÖÐËÑ"CDE", Ôò      */
        while (q <= buf + buf_len - hex_len) /* ABCDE  ÊúÏß´¦Îª×îºóÒ»¸öËÑË÷µã, ¹²ËÑ3´Î */
        {
            distance = (buf + buf_len - hex_len) - q + 1;
            p = memchr(q, hex[0], distance); /* ÔÚ[q, q+distance-1]·¶Î§ÄÚÑ°ÕÒhex[0] */
            /* »ã±àÓïÑÔ¿ÉÒÔÓÃrepne scasbÖ¸ÁîÊµÏÖmemchr()µÄ¹¦ÄÜ */
            if (p == NULL) /* ÈôÃ»ÓÐÕÒµ½, Ôò·ÅÆúµ±Ç°bufÖÐµÄÄÚÈÝ */
                break;
            if (memcmp(p, hex, hex_len) != 0) /* ±È½ÏpºÍhexÖ¸ÏòµÄhex_len×Ö½ÚÊÇ·ñÏàÍ¬ */
            {                                 /* »ã±àÓïÑÔ¿ÉÒÔÓÃrepne cmpsbÊµÏÖmemcmp()µÄ¹¦ÄÜ */
                q = p + 1;                    /* Èô²»ÏàÍ¬, ÔòÏÂ¸öËÑË÷µã=p+1 */
                continue;
            }
            return offset + (p - buf); /* ÈôÏàÍ¬, Ôò·µ»ØÆ«ÒÆÁ¿ */
        }
        processed_len = buf_len - hex_len + 1;
        q = buf + processed_len;
        remained_len = hex_len - 1;
        memcpy(buf, q, remained_len);
        /* »ã±àÓïÑÔÖÐ¿ÉÒÔÓÃrep movsbÊµÏÖmemcpy()µÄ¹¦ÄÜ */
        read_len = sizeof(buf) - remained_len; /* ¼ÆËãÏÂ´ÎÒª¶ÁµÄ×î´ó×Ö½ÚÊý */
    }
    return -1; /* ÈôËÑ±éÕû¸öÎÄ¼þÃ»ÓÐÕÒµ½, Ôò·µ»Ø-1 */
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
    /* »ã±àÓïÑÔ´ò¿ªÎÄ¼þ²½Öè:
      mov ah, 3Dh
      mov al, 0
      mov dx, offset filename
      int 21h
      jc error
      mov [fp], ax; Êý¾Ý¶ÎÖÐÒªÊÂÏÈ¶¨Òåfp dw 0
      ...
    error:
     */
    if (fp == NULL)
        exit(0);
    fseek(fp, 0, SEEK_END); /* ÒÆ¶¯ÎÄ¼þÖ¸Õëµ½EOF */
    /* »ã±àÓïÑÔÒÆ¶¯ÎÄ¼þÖ¸Õëµ½EOF:
      mov ah, 42h
      mov al, 2
      mov bx, [fp]
      xor cx, cx
      xor dx, dx
      int 21h; ·µ»ØDX:AXÎªÎÄ¼þ³¤¶È
    */
    n = ftell(fp); /* »ñÈ¡µ±Ç°ÎÄ¼þÖ¸ÕëÀëÎÄ¼þ¿ª¶ËµÄ¾àÀë¼´ÎÄ¼þ³¤¶È */
    /* »ã±àÓïÑÔ°ÑÎÄ¼þ³¤¶È±£´æµ½±äÁ¿nÖÐ:
      mov word ptr n[0], ax
      mov word ptr n[2], dx
    */
    fseek(fp, 0, SEEK_SET); /* ÒÆ¶¯ÎÄ¼þÖ¸Õëµ½ÎÄ¼þ¿ª¶Ë, ÒÔ±ãºóÃæ¶ÁÈ¡ÎÄ¼þÄÚÈÝ */
    /* »ã±àÓïÑÔÒÆ¶¯ÎÄ¼þÖ¸Õëµ½¿ª¶Ë:
      mov ah, 42h
      mov al, 0
      mov bx, [fp]
      xor cx, cx
      xor dx, dx
      int 21h
     */
    offset = find(fp, n, s); /* ÔÚ³¤¶ÈÎªn×Ö½ÚµÄÎÄ¼þÖÐËÑË÷Ê®Áù½øÖÆ´®s, ÈôÕÒµ½
                               Ôò·µ»Ø¸Ã´®ÔÚÎÄ¼þÄÚµÄÆ«ÒÆÁ¿, ·ñÔò·µ»Ø-1
           ÿ                 */
    fclose(fp);
    if (offset != -1)
        printf("found at %08lX\n", offset);
    else
        puts("Not found!");
    getchar();
}
ÿ
; û��ָ��������ʼ��ַ����Ĭ�ϴӵ�ַ 0x00000000 �Ͽ�ʼ
    jmp near start    
    ;message db '1','+','2','+','3','+','.','.','.','+','1','0','0',' ','=',' '
    message db '1+2+3+...+100 = '
        
start: 
    mov ax, 0xB800    ; ��Ƶ������ʼ��ַ��0x0B800 
    mov es, ax
    mov ax, 0x07C0
    mov ds, ax

    xor ax, ax         ; ��� message�ַ��� 
    mov si, message
    xor di, di 
    mov ah, 0x07
    mov cx, (start - message)       
show1:
    mov al, byte [si]
    mov [es:di], ax
    add di, 2
    inc si
    loop show1

    mov cx, 1           ; ����1��100�ĺ� 
    xor ax, ax
sum:
    add ax, cx
    inc cx
    cmp cx, 100
    jna sum
    
    xor cx, cx          ; ���ͽ��зֽ� 
    mov ss, cx
    mov sp, 0x7c00
    
    mov si, 10
digit:
    xor dx, dx
    div si
    or dl, 0x30
    push dx
    inc cx
    cmp ax, 0
    jne digit
    
show2:                  ; ���͵Ľ����������� 
    pop dx
    mov dh, 0x04
    mov [es:di], dx
    add di, 2
    loop show2           
    
    mov byte [es:di], 'd' ; ���������ĸd����ʾ10���� 
    inc di
    mov byte [es:di], 0x04
    
infi:
    jmp near infi
;    jmp near $                 
    
    times 510 - ($-$$) db 0
    db 0x55, 0xaa
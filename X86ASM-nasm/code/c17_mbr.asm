;
; MBR, Prgram loader 
;
; �������ߵĴ��룬������ģʽ�Ĵ���λ���ַ����Ϊ0x7c00������������Ϊ0x1FF��512�ֽ�
; ���ʹ�����ߵ���ʽ�����ﲻ�ܶ���vstart=0x7C00������η��ʻ����
; ���Ҫ�����vstart=0x7c00����ô���뽫����ε��������޸�һ�£��������ַ0��������64K

core_code_lba     equ   0x00000001
core_load_addr    equ   0x00040000
 
SECTION mbr align=16 vstart=0x7C00

[bits 16]
    jmp near start    
                
start: 
    xor ax, ax   
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00
    
    ; install gdt
    mov eax, [pgdt + 2] ; + 0x7c00
    xor edx, edx
    mov ebx, 0x10
    div ebx
    mov ebx, edx
    
    push ds
    mov ds, eax
    ;descriptor 0
    mov dword [bx + 4*0], 0x0
    mov dword [bx + 4*1], 0x0
    
    ; descriptor 1 code segment   0000_0000 0000_1000   0x0008
    mov dword [bx + 4*2], 0x0000FFFF
    mov dword [bx + 4*3], 0x00CF9800
    
    ; descriptor 2  code segment  0000_0000 0001_0000   0x0010
    mov dword [bx + 4*4], 0x0000FFFF
    mov dword [bx + 4*5], 0x00CF9200
    
    pop ds
    mov word [pgdt], 23 ; + 0x7c00    
    lgdt [pgdt]  ; + 0x7c00
    
    in al, 0x92     ; A20 Address Line
    or al, 0x02
    out 0x92, al
    
    cli      
    
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax
    
    jmp dword 0x0008:flush
    
    [bits 32]
flush: 
    mov eax, 0x0010
    mov ds, eax
    mov fs, eax
    mov gs, eax
    mov es, eax    
    mov ss, eax
    mov esp, 0x7000
        
    ; load core
    mov eax, core_code_lba
    mov edi, core_load_addr
    call read_hard_disk_section
    
    mov eax, [core_load_addr]
    xor edx, edx
    mov ebx, 512
    div ebx
    or edx, edx
    jnz readmore
    dec eax
  
 readmore:
    or eax, eax
    jz setgdt
    
    mov ecx, eax
    mov eax, core_code_lba    
  readsec:        
    inc eax
    add edi, 512  
    call read_hard_disk_section  
    loop readsec
    
 setgdt: 
    
    ; ����ϵͳ�ں˵�ҲĿ¼��PDT
    mov ebx, 0x00020000
    
    ; ��ҳĿ¼�ڴ���ָ��ҳĿ¼���Լ���Ŀ¼��
    mov dword [ebx+4092], 0x00020003
    
    mov edx, 0x00021003
    ; ��ҳĿ¼�ڴ��������Ե�ַ0x00000000��Ӧ��Ŀ¼��
    mov [ebx + 0x000], edx
    ; ���������Ե�ַ0x80000000��Ӧ��Ŀ¼�� 
    mov [ebx + 0x800], edx
    
    ; ����������Ŀ¼���Ӧ��ҳ��
    mov ebx, 0x21000 
    xor eax, eax
    xor esi, esi
 .b1:
    mov edx, eax
    or edx, 0x00000003
    mov [ebx + esi*4], edx
    add eax, 0x1000
    inc esi
    cmp esi, 256
    jl .b1
    
    ; CR3�Ĵ���ָ��ҳĿ¼��������ҳ����
    mov eax, 0x00020000  ; PCD=PWT=0
    mov cr3, eax 
    
    ; GDT���Ե�ַӳ�䵽��0x80000000��ʼ����ͬλ��
    sgdt [pgdt]
    mov ebx, [pgdt + 2]
    add dword [pgdt + 2], 0x80000000
    lgdt [pgdt]
    
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax
    
    ; ����ջӳ�䵽�߶˵�ַ
    ; ���ں˵����г���ӳ�䵽�߶�
    add esp, 0x80000000
    
    jmp [0x80040004]
     
    hlt       
 
;----------------------------------------------------------------------
; Functions
;
; read a section from disk
; EAX: section no.  EDI: memory buffer
read_hard_disk_section:
    push eax
    push ecx
    push edx
    push edi

    push eax
    ;mov ebx, eax
    ;mov ecx, eax

    mov dx, 0x1F2      ; �ӿڱ��� ��ȡ��������
    mov al, 0x01
    out dx, al

    ; Start Section No
    inc dx  ; mov dx, 0x1F3      ; 0x1F3/0x1F4/0x1F5/0x1F6������ʼ������
    ;mov al, cl
    pop eax
    out dx, al

    inc dx             ; 0x1F4
    mov cl, 8
    shr eax, cl
    out dx, al

    inc dx             ; 0x1F5
    shr eax, cl
    ;mov al, cl
    out dx, al

    inc dx             ; 0x1F6
    ;mov al, ch
    shr eax, cl
    ;and al, 0x0F
    or al, 0xE0        ; 0x1F6�˿� �����ֽ� 1X1Y  X��ʾCHS(0)/LBA Y��ʾ��(0)/������
    out dx, al         ; 1110 - 0xE0 ������ LBA��ʽ��ȡ

    ; Read Command
    ;mov dx, 0x1F7
    inc dx
    mov al, 0x20       ; 0x1F7 port 0x20 read disk
    out dx, al

    ; Test Ready
    ;mov dx, 0x1F7
 .waits:
    in al, dx
    and al, 0x88
    cmp al, 0x08
    jnz .waits

    ; Read data
    mov dx, 0x1F0     ; 0x1F0 ���˿ڣ�0x1F1 Ϊ����Ĵ����������������һ�β���״̬��
    mov ecx, 256
 .readw:
    in ax, dx
    mov word [edi], ax
    add edi, 2
    loop .readw

    pop edi
    pop edx
    pop ecx
    pop eax
    ret     

    pgdt      dw  23
              dd  0x00008000
    
    times 510 - ($-$$) db 0
    db 0x55, 0xaa
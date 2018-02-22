;
; Core
;

app_prog_lba       equ     20   ; Ӧ�ó������ڵ���ʼ������
app_prog_startoff  equ     0x10 ; Ӧ�ó�����ʼƫ�� 

core_code_seg_sel   equ    0x38
core_data_seg_sel   equ    0x30
sys_routine_seg_sel equ    0x28
video_ram_seg_sel   equ    0x20
core_stack_seg_sel  equ    0x18
mem_0_4_gb_seg_sel  equ    0x08

    core_length     dd  core_end
    sys_funcs_off   dd  section.sys_routine.start    
    coredata_off    dd  section.core_data.start
    corecode_off    dd  section.core_code.start
    entry_off       dd  start    
    enty_seg        dw  core_code_seg_sel

[bits 32]      
SECTION sys_routine align=16 vstart=0

;
; BX ��������ֵ
;
far_set_cursor_pos:
    push edx
    push eax
    mov dx, 0x3d4   ; ���ù��λ��
    mov al, 0x0e
    out dx, al
    mov dx, 0x3d5
    mov al, bh
    out dx, al
    mov dx, 0x3d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x3d5
    mov al, bl
    out dx, al
    pop eax
    pop edx
    retf

;
; BX ��������ֵ 
; 
set_cursor_pos:
    push edx
    push eax
    mov dx, 0x3d4   ; ���ù��λ��
    mov al, 0x0e
    out dx, al
    mov dx, 0x3d5    
    mov al, bh
    out dx, al
    mov dx, 0x3d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x3d5
    mov al, bl
    out dx, al
    pop eax
    pop edx
    ret
;
; ax return pos info
;
get_cursor_pos:
    push edx
    mov dx, 0x3d4   ; ��ȡ���λ��
    mov al, 0x0e
    out dx, al
    mov dx, 0x3d5
    in al, dx
    mov ah, al
    mov dx, 0x3d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x3d5
    in al, dx
    pop edx
    ret

;
; Show a char on screen
; cl : output char value
put_char:
    push es
    push ds 
    push esi
    push edi
    push edx
    push ebx
    push eax
    
    mov eax, video_ram_seg_sel
    mov es, eax
    mov ds, eax
    
    xor eax, eax    
    call get_cursor_pos
    mov ebx, eax
    
    cmp cl, 0x0d
    jz put_0d
    cmp cl, 0x0a
    jz put_0a
    
    shl ebx, 1  ; ��������ַ�
    mov [es:ebx], cl
    shr ebx, 1
    inc ebx
    jmp crll_screen  ; �Ƿ���� 
     
  put_0d:    
    mov ax, bx
    mov bl, 80
    div bl
    mul bl
    mov bx, ax   
    jmp reset_cur  
  put_0a:
    add ebx, 80
  crll_screen:
    cmp ebx, 2000
    jb reset_cur

    xor edi, edi  ; ����
    mov esi, 0xa0
    mov ecx, 1920
    rep movsw

    mov eax, 0x20
    mov ecx, 80
  cls_ln:
    mov byte [edi], al
    add edi, 2
    loop cls_ln

    mov ebx, 1920   ; ���ù��λ��

  reset_cur: 
    call set_cursor_pos

    pop eax
    pop ebx    
    pop edx
    pop edi
    pop esi
    pop ds
    pop es
    ret      
;
; Show a string(zero end) on screen
; param:
;   DS:EBX  ָ��Ҫ����ַ�����0������������ַ 
put_string:
    push ecx
    push eax
    xor eax, eax
  more:
    mov al, [ebx]
    cmp al, 0
    jz str_end
    mov cl, al
    call put_char
    inc ebx    
    jmp more    
 str_end:
    pop eax
    pop ecx
    retf    
;
; clean screen 
;
screen_cls:
    push es
    push ecx
    push edi
    push eax
    
    xor edi, edi    
    mov eax, video_ram_seg_sel
    mov es, eax
    mov ecx, 2000
    mov eax, 0x0720
mov_word:    
    mov [es:edi], ax
    add edi, 2
    loop mov_word 
    
    pop eax
    pop edi
    pop ecx
    pop es
    retf 

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
    retf

; 
; For debug, output DWORD
;
put_hex_dword:
    
    pushad
    push ds
    
    mov ax, core_data_seg_sel
    mov ds, ax
    
    mov ebx, bin_hex
    mov ecx, 8
 .xlt:
    rol edx, 4
    mov eax, edx
    and eax, 0x0000000F
    xlat
    
    push ecx
    mov cl, al
    call put_char
    pop ecx
    
    loop .xlt
    
    pop ds
    popad
    retf

;
; ECX - [Input] Size to Alloc
; ECX - [Output] Alloc Base Address
allocate_memory:
    push ds
    push eax
    push ebx
    
    mov eax, core_data_seg_sel
    mov ds, eax
    mov eax, [ram_alloc]
    add eax, ecx
    
    mov ecx, [ram_alloc]
    mov ebx, eax
    and ebx, 0xFFFFFFFC
    add ebx, 4
    test eax, 0x00000003
    cmovnz eax, ebx
    mov [ram_alloc], eax
    
    pop ebx
    pop eax
    pop ds
    
    retf

; EDX:EAX - [IN]  descriptor item
; CX - [OUT] selector
;
set_up_gdt_descriptor:
    push eax
    push ebx 
    push edx
    
    push ds
    push es
    
    mov ebx, core_data_seg_sel
    mov ds, ebx
    
    sgdt [pgdt]
    mov ebx, mem_0_4_gb_seg_sel
    mov es, ebx
    
    movzx ebx, word [pgdt]
    inc bx
    add ebx, [pgdt + 2]
    
    mov [es:ebx], eax
    mov [es:ebx+4], edx
    
    add word [pgdt], 8
    
    lgdt [pgdt]
    
    mov ax, [pgdt]   ; calc selector
    xor dx, dx
    mov bx, 8
    div bx
    mov cx, ax
    shl cx, 3
            
    pop es
    pop ds
    pop edx
    pop ebx
    pop eax
    retf

; EAX - [IN] line base address
; EBX - [IN] limit
; ECX - [IN] attributes
;
; EDX:EAX - [OUT] descriptor
;
make_seg_descriptor:
    mov edx, eax
    shl eax, 16
    or ax, bx
    
    and edx, 0xFFFF0000
    rol edx, 8
    bswap edx
    
    xor bx, bx
    or edx, ebx
    and ecx, 0xFFF0FFFF   ; ��֤�ν��޵�4λΪ0 
    or edx, ecx
    
    retf

; EAX - [IN] line base address
; EBX - [IN] selector
; ECX - [IN] attributes
;
; EDX:EAX - [OUT] descriptor
;
make_gate_descriptor:
    push ebx
    push ecx
    
    mov edx, eax
    and eax, 0x0000FFFF
    shl ebx, 16
    and ebx, 0xFFFF0000
    or eax, ebx

    and edx, 0xFFFF0000
    and ecx, 0x0000FFFF   
    or edx, ecx
    
    pop ecx
    pop ecx
    retf

terminate_current_task:
    
    mov eax, core_data_seg_sel
    mov ds, eax
    
    pushfd
    pop edx
        
    test dx, 0100_0000_0000_0000B
    jnz .b1
    jmp far [prgman_tss]
    
  .b1:
    iretd    

;
; ����һ��4K��ҳ 
; EAX=ҳ�������ַ 
allocate_a_4k_page:
   
   push ebx
   push ecx
   push edx
   push ds
   
   mov eax, core_data_seg_sel
   mov ds, eax
   
   xor eax, eax
 .b1:
   bts [page_bit_map], eax
   jnc .b2
   inc eax
   cmp eax, page_map_len*8
   jl .b1
   
   mov ebx, message_3
   call sys_routine_seg_sel:put_string
   hlt
   
 .b2:
   shl eax, 12
   
   pop ds
   pop edx
   pop ecx
   pop ebx
   
   ret
         
;
; ����һ��ҳ������װ�ڵ�ǰ��Ĳ㼶��ҳ�ṹ��
; EBX=ҳ�����Ե�ַ 
;    
alloc_inst_a_page:
    
    push eax
    push ebx 
    push esi
    push ds
    
    mov eax, mem_0_4_gb_seg_sel
    mov ds, eax
    
    mov esi, ebx
    and esi, 0xFFC00000
    shr esi, 20    ; ҳĿ¼����������4 shr esi 22�� shl esi 2
    or esi, 0xFFFFF000
    
    test dword [esi], 0x00000001     ; �ж�Pλ�Ƿ�Ϊ1����ҳ���Ƿ���� 
    jnz .b1
    
    ; �������Ե�ַ��Ӧҳ��
    call allocate_a_4k_page          ; ����һ��ҳ�� 
    or eax, 0x00000007
    mov [esi], eax                   ; �洢��ҳĿ¼�ж�Ӧ��Ŀ 
 .b1:
    ; �������Ե�ַ��Ӧҳ��   
    ; ������һ�����ɣ� 
    ; ҳĿ¼�����һ����Ŀ������ҳĿ¼��ҳ����
    ; ���� Ҫ����ҳĿ¼�е�ĳһ����Ŀ ���10λҪ����Ϊ0xFFC 
    ; �м�10λΪ ҳĿ¼�������������Ե�ַ�����10λ�� 
    ; �ٽ� ���Ե�ַ���м�10λ ����4 ���õ���12λ��
    ; �������ܷ���ҳ���е� ĳһ�� 
    mov esi, ebx
    shr esi, 10 
    and esi, 0x003FF000
    or esi, 0xFFC00000     ; ҳ�����Ե�ַ
    
    and ebx, 0x003FF000
    shr ebx, 10 
    or esi, ebx      ; ҳ��������Ե�ַ
    call allocate_a_4k_page ; ����һ��ҳ��Ҫ��װ��ҳ
    or eax, 0x00000007
    mov [esi], eax 
            
    pop ds
    pop esi
    pop ebx
    pop eax
    
    retf       
    
SECTION core_data align=16 vstart=0
    pgdt      dw   0
              dd   0
              
    page_bit_map db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x55, 0x55, 0xFF
                 db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
                 db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
                 db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
                 db 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55
                 db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                 db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                 db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                 db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00                                                   
                 
    page_map_len equ $-page_bit_map
              
    ram_alloc dd   0x00100000
    
    ; ������
    salt:
    salt_1    db   '@PrintString'
              times 256-($-salt_1) db 0
              dd   put_string
              dw   sys_routine_seg_sel
    salt_2    db   '@ReadDiskData'
              times 256-($-salt_2) db 0
              dd   read_hard_disk_section
              dw   sys_routine_seg_sel
    salt_3    db   '@PrintDwordAsHexString'
              times 256-($-salt_3) db 0
              dd   put_hex_dword
              dw   sys_routine_seg_sel
    salt_4    db   '@TerminateProgram'
              times 256-($-salt_4) db 0
              dd   terminate_current_task
              dw   sys_routine_seg_sel
    
    salt_item_len equ $-salt_4
    salt_items    equ 4;($-salt)/salt_item_len

    message_0 db ' Working in system core, protect mode.'
              db 0x0d,0x0a,0
    
    message_1 db ' Paging is enabled. System core is mapped to'
              db ' address 0x80000000.',0x0d,0x0a,0
    message_2 db 0x0d,0x0a 
              db ' System wide CALL-GATE mounted.',0x0d,0x0a,0
    
    message_3 db '********No more pages********',0
    
    message_4 db 0x0d,0x0a,' Task switching...@_@',0x0d,0x0a,0
    
    message_5 db 0x0d,0x0a,' Processor HALT.',0
              
    bin_hex db '0123456789ABCDEF'
    
    core_buf times 2048 db 0
    
    cpu_brand0 db 0x0d,0x0a,' ',0
    cpu_brand times 64 db 0
    cpu_brand1 db 0x0d,0x0a,0x0d,0x0a,0    
    
    tcb_chain  dd 0   ; ������ƿ���
    
    ;�����������������Ϣ
    prgman_tss dd 0   ; ���������TSS����ַ                               
               dw 0   ; ���������TSS������ѡ����
    
    core_next_laddr dd 0x80100000
                  
core_data_end:
;======================================================================    
SECTION core_code align=16 vstart=0

;
; EDX:EAX = ������
; EBX=TCB����ַ
; 
; CX=��������ѡ���� 
;
fill_descriptor_in_ldt:
    
    push eax
    push edx
    push edi
    push ds
    
    mov ecx, mem_0_4_gb_seg_sel
    mov ds, ecx
    
    mov edi, [ebx+0x0c]  ; LDT����ַ 
    
    xor ecx, ecx
    mov cx, [ebx+0x0a]
    inc cx
    
    mov [edi+ecx+0x00], eax
    mov [edi+ecx+0x04], edx
    
    add cx, 8
    dec cx
    
    mov [ebx+0x0a], cx
    
    mov ax, cx
    xor dx, dx
    mov cx, 8
    div cx
    
    mov cx, ax
    shl cx, 3
    or cx, 0000_0000_000_0100B
    
    pop ds
    pop edi
    pop edx
    pop eax
    
    ret
;
; load user program, and relocate
; [IN] 
;     push start-lba
;     push TCB-addr
;
load_relocate_program:
    pushad 
    push ds   
    push es
    
    mov ebp, esp       ; Ϊ����ջ�ϲ���׼����׼ֵ 
    
    mov eax,mem_0_4_gb_seg_sel
    mov es,eax                         ;�л�DS���ں����ݶ�
    
    mov esi, [ebp+11*4]   ; tcb����ַ
    
    ; LDT memory
    mov ecx, 160
    call sys_routine_seg_sel:allocate_memory
    mov [es:esi+0x0c], ecx  ; LDT����ַ
    mov word [es:esi+0x0a], 0xffff ; ����Ϊ0
    
    mov eax, core_data_seg_sel
    mov ds, eax
            
    ; load user program to memory
    mov eax, [ebp+12*4]  ; �û�������ʼ LBA    
    mov edi, core_buf
    call sys_routine_seg_sel:read_hard_disk_section     ; get header
    
    mov eax, dword [core_buf]
    mov ebx, eax
    and ebx, 0xFFFFFE00
    add ebx, 512
    test eax, 0x000001FF
    cmovnz eax, ebx

    mov ecx, eax
    call sys_routine_seg_sel:allocate_memory
    mov [es:esi+0x06], ecx 
    
    mov edi, ecx
    xor edx, edx
    mov ecx, 512
    div ecx
    mov ecx, eax    ; ���������� 
    
    mov eax, mem_0_4_gb_seg_sel
    mov ds, eax
    
    push edi
    mov eax, [ebp+12*4]    ; ��ʵ������ LBA 
 .b1:
    call sys_routine_seg_sel:read_hard_disk_section
    inc eax
    add edi, 512
    loop .b1
    
    ;��������ͷ��������     0x07 
    pop edi
    mov eax, edi
    mov ebx, [edi+0x4]     ; seg len
    dec ebx
    mov ecx, 0x0040F200    ; attributes
    call sys_routine_seg_sel:make_seg_descriptor
    
    ; ��װ��LDT��
    mov ebx, esi
    call fill_descriptor_in_ldt
    
    or cx, 0x03    ; Ȩ��ֵ��Ϊ 3 
    mov [es:esi + 0x44], cx
    mov [edi + 0x04], cx 
        
    ;������������������   0x0F 
    mov eax,edi
    add eax,[edi+0x14]                 ;������ʼ���Ե�ַ
    mov ebx,[edi+0x18]                 ;�γ���
    dec ebx                            ;�ν���
    mov ecx,0x0040F800                 ;�ֽ����ȵĴ����������
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx, esi
    call fill_descriptor_in_ldt
    or cx, 0x03     
    mov [edi+0x14],cx

    ;�����������ݶ�������   0x17
    mov eax,edi
    add eax,[edi+0x1c]                 ;���ݶ���ʼ���Ե�ַ
    mov ebx,[edi+0x20]                 ;�γ���
    dec ebx                            ;�ν���
    mov ecx,0x0040F200                 ;�ֽ����ȵ����ݶ�������
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx, esi
    call fill_descriptor_in_ldt
    or cx, 0x03
    mov [edi+0x1c],cx

    ;���������ջ��������   0x1F
    mov ecx,[edi+0x0c]                 ;4KB�ı��� 
    mov ebx,0x000fffff
    sub ebx,ecx                        ;�õ��ν���
    mov eax,4096                        
    mul dword [edi+0x0c]                         
    mov ecx,eax                        ;׼��Ϊ��ջ�����ڴ� 
    call sys_routine_seg_sel:allocate_memory
    add eax,ecx                        ;�õ���ջ�ĸ߶������ַ 
    mov ecx,0x00c0F600                 ;4KB���ȵĶ�ջ��������
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx, esi
    call fill_descriptor_in_ldt
    or cx, 0x03
    mov [edi+0x08],cx

    ;�ض�λSALT
    mov eax, mem_0_4_gb_seg_sel
    mov es,eax                         ;es -> �û�����ͷ�� 
    mov eax,core_data_seg_sel
    mov ds,eax
      
    cld

    mov ecx,[es:edi+0x24]              ;�û������SALT��Ŀ��
    add edi,0x28                       ;�û������ڵ�SALTλ��ͷ����0x2c��
  .b2: 
    push ecx
    push edi
      
    mov ecx,salt_items
    mov esi,salt
  .b3:
    push edi
    push esi
    push ecx

    mov ecx,64                         ;�������У�ÿ��Ŀ�ıȽϴ��� 
    repe cmpsd                         ;ÿ�αȽ�4�ֽ� 
    jnz .b4
    mov eax,[esi]                      ;��ƥ�䣬esiǡ��ָ�����ĵ�ַ����
    mov [es:edi-256],eax               ;���ַ�����д��ƫ�Ƶ�ַ 
    mov ax,[esi+4]
    mov [es:edi-252],ax                ;�Լ���ѡ���� 
  .b4:
      
    pop ecx
    pop esi
    add esi,salt_item_len
    pop edi                            ;��ͷ�Ƚ� 
    loop .b3
      
    pop edi
    add edi,256
    pop ecx
    loop .b2

    mov esi,[ebp+11*4]                 ; TCB ����ַ
    
    ; 0 stack
    mov ecx, 4096
    mov eax, ecx
    mov [es:esi+0x1a], ecx
    shr dword [es:esi+0x1a], 12
    call sys_routine_seg_sel:allocate_memory
    add eax, ecx
    mov [es:esi+0x1e], eax
    mov ebx, 0xFFFFE
    mov ecx, 0x00c09600                ; 4K���ȣ���д����Ȩ��0
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx, esi
    call fill_descriptor_in_ldt
    mov [es:esi+0x22], cx
    mov dword [es:esi+0x24], 0
    
    ;����1��Ȩ����ջ
    mov ecx,4096
    mov eax,ecx                        ;Ϊ���ɶ�ջ�߶˵�ַ��׼��
    mov [es:esi+0x28],ecx
    shr dword [es:esi+0x28],12               ;�Ǽ�1��Ȩ����ջ�ߴ絽TCB
    call sys_routine_seg_sel:allocate_memory
    add eax,ecx                        ;��ջ����ʹ�ø߶˵�ַΪ����ַ
    mov [es:esi+0x2c],eax              ;�Ǽ�1��Ȩ����ջ����ַ��TCB
    mov ebx,0xffffe                    ;�γ��ȣ����ޣ�
    mov ecx,0x00c0b600                 ;4KB���ȣ���д����Ȩ��1
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx,esi                        ;TCB�Ļ���ַ
    call fill_descriptor_in_ldt
    or cx,0000_0000_0000_0001          ;����ѡ���ӵ���Ȩ��Ϊ1
    mov [es:esi+0x30],cx               ;�Ǽ�1��Ȩ����ջѡ���ӵ�TCB
    mov dword [es:esi+0x32],0          ;�Ǽ�1��Ȩ����ջ��ʼESP��TCB

    ;����2��Ȩ����ջ
    mov ecx,4096
    mov eax,ecx                        ;Ϊ���ɶ�ջ�߶˵�ַ��׼��
    mov [es:esi+0x36],ecx
    shr dword [es:esi+0x36],12               ;�Ǽ�2��Ȩ����ջ�ߴ絽TCB
    call sys_routine_seg_sel:allocate_memory
    add eax,ecx                        ;��ջ����ʹ�ø߶˵�ַΪ����ַ
    mov [es:esi+0x3a],ecx              ;�Ǽ�2��Ȩ����ջ����ַ��TCB
    mov ebx,0xffffe                    ;�γ��ȣ����ޣ�
    mov ecx,0x00c0d600                 ;4KB���ȣ���д����Ȩ��2
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx,esi                        ;TCB�Ļ���ַ
    call fill_descriptor_in_ldt
    or cx,0000_0000_0000_0010          ;����ѡ���ӵ���Ȩ��Ϊ2
    mov [es:esi+0x3e],cx               ;�Ǽ�2��Ȩ����ջѡ���ӵ�TCB
    mov dword [es:esi+0x40],0          ;�Ǽ�2��Ȩ����ջ��ʼESP��TCB     

    ;��GDT�еǼ�LDT������
    mov eax,[es:esi+0x0c]              ;LDT����ʼ���Ե�ַ
    movzx ebx,word [es:esi+0x0a]       ;LDT�ν���
    mov ecx,0x00408200                 ;LDT����������Ȩ��0
    call sys_routine_seg_sel:make_seg_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor
    mov [es:esi+0x10],cx               ;�Ǽ�LDTѡ���ӵ�TCB��
       
    ;�����û������TSS
    mov ecx,104                        ;tss�Ļ����ߴ�
    mov [es:esi+0x12],cx              
    dec word [es:esi+0x12]             ;�Ǽ�TSS����ֵ��TCB 
    call sys_routine_seg_sel:allocate_memory
    mov [es:esi+0x14],ecx              ;�Ǽ�TSS����ַ��TCB
      
    ;�Ǽǻ�����TSS�������
    mov word [es:ecx+0],0              ;������=0
      
    mov edx,[es:esi+0x24]              ;�Ǽ�0��Ȩ����ջ��ʼESP
    mov [es:ecx+4],edx                 ;��TSS��
      
    mov dx,[es:esi+0x22]               ;�Ǽ�0��Ȩ����ջ��ѡ����
    mov [es:ecx+8],dx                  ;��TSS��
      
    mov edx,[es:esi+0x32]              ;�Ǽ�1��Ȩ����ջ��ʼESP
    mov [es:ecx+12],edx                ;��TSS��

    mov dx,[es:esi+0x30]               ;�Ǽ�1��Ȩ����ջ��ѡ����
    mov [es:ecx+16],dx                 ;��TSS��

    mov edx,[es:esi+0x40]              ;�Ǽ�2��Ȩ����ջ��ʼESP
    mov [es:ecx+20],edx                ;��TSS��

    mov dx,[es:esi+0x3e]               ;�Ǽ�2��Ȩ����ջ��ѡ����
    mov [es:ecx+24],dx                 ;��TSS��

    mov dx,[es:esi+0x10]               ;�Ǽ������LDTѡ����
    mov [es:ecx+96],dx                 ;��TSS��
      
    mov dx,[es:esi+0x12]               ;�Ǽ������I/Oλͼƫ��
    mov [es:ecx+102],dx                ;��TSS�� 
      
    mov word [es:ecx+100],0            ;T=0
    
    mov dword [es:ecx+28], 0           ; CR3
    
    ; Ӧ�ó���ͷ������ȡ�������TSS
    mov ebx, [ebp+11*4]                ; TCB ����ַ 
    mov edi, [es:ebx+0x06]             ; �û�������ػ���ַ 
    
    mov edx, [es:edi+0x10]             ; ���ó������
    mov [es:ecx+32], edx               ; TSS��
    
    mov dx,[es:edi+0x14]               ;�Ǽǳ������Σ�CS��ѡ����
    mov [es:ecx+76],dx                 ;��TSS��

    mov dx,[es:edi+0x08]               ;�Ǽǳ����ջ�Σ�SS��ѡ����
    mov [es:ecx+80],dx                 ;��TSS��

    mov dx,[es:edi+0x04]               ;�Ǽǳ������ݶΣ�DS��ѡ����
    mov word [es:ecx+84],dx            ;��TSS�С�ע�⣬��ָ�����ͷ����
      
    mov word [es:ecx+72],0             ;TSS�е�ES=0
    mov word [es:ecx+88],0             ;TSS�е�FS=0
    mov word [es:ecx+92],0             ;TSS�е�GS=0

    pushfd
    pop edx         
    mov dword [es:ecx+36],edx          ;EFLAGS�����ó�������������EFLAGS    
       
    ;��GDT�еǼ�TSS������
    mov eax,[es:esi+0x14]              ;TSS����ʼ���Ե�ַ
    movzx ebx,word [es:esi+0x12]       ;�γ��ȣ����ޣ�
    mov ecx,0x00408900                 ;TSS����������Ȩ��0
    call sys_routine_seg_sel:make_seg_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor
    mov [es:esi+0x18],cx               ;�Ǽ�TSSѡ���ӵ�TCB

    pop es                             ;�ָ������ô˹���ǰ��es�� 
    pop ds                             ;�ָ������ô˹���ǰ��ds��
            
    popad
    ret 8
    
;
; ECX=tcb����ַ 
;
append_to_tcb_link:
    push eax
    push edx
    push ds
    push es
    
    mov eax, core_data_seg_sel
    mov ds, eax
    mov eax, mem_0_4_gb_seg_sel
    mov es, eax
    
    mov dword [es:ecx+0x00], 0   ; �ṹ���һ����0����ʾ֮��û������
    
    mov eax, [tcb_chain]
    or eax, eax
    jz .notcb
 .searc:
    mov edx, eax
    mov eax, [es:edx + 0x00]
    or eax, eax
    jnz .searc
    
    mov [es:edx + 0x00], ecx
    jmp .retpc
 .notcb:
    mov [tcb_chain], ecx ; �ձ�ֱ�ӽ�ͷָ��ָ���·���
    
 .retpc:    
    pop es
    pop ds
    pop edx
    pop eax
    ret    
    
    ;
    ; Core Start Address
    ;
start:
    mov ecx, core_data_seg_sel
    mov ds, ecx
    
    mov ecx,mem_0_4_gb_seg_sel         ;��ESָ��4GB���ݶ� 
    mov es,ecx    

    call sys_routine_seg_sel:screen_cls  ; ����
    
    xor ebx, ebx 
    call sys_routine_seg_sel:far_set_cursor_pos ; ���ù��λ�� 
    
    mov ebx, message_0
    call sys_routine_seg_sel:put_string
    
    mov eax, 0x80000002
    cpuid
    mov [cpu_brand + 0x00], eax
    mov [cpu_brand + 0x04], ebx
    mov [cpu_brand + 0x08], ecx
    mov [cpu_brand + 0x0C], edx
    
    mov eax, 0x80000003
    cpuid
    mov [cpu_brand + 0x10], eax
    mov [cpu_brand + 0x14], ebx
    mov [cpu_brand + 0x18], ecx
    mov [cpu_brand + 0x1C], edx

    mov eax, 0x80000004
    cpuid
    mov [cpu_brand + 0x20], eax
    mov [cpu_brand + 0x24], ebx
    mov [cpu_brand + 0x28], ecx
    mov [cpu_brand + 0x2C], edx
    
    mov ebx, cpu_brand0
    call sys_routine_seg_sel:put_string
    mov ebx, cpu_brand
    call sys_routine_seg_sel:put_string    
    mov ebx, cpu_brand1
    call sys_routine_seg_sel:put_string

    ; Open Page
    ; �����ں�ҳĿ¼����������������� 
    mov ecx, 1024
    mov ebx, 0x00020000
    xor esi, esi
 .b1: 
    mov dword [es:ebx + esi], 0x00000000
    add esi, 4
    loop .b1
    
    mov dword [es:ebx+4092], 0x00020003  ; ָ��ҳĿ¼���Լ�����Ŀ�����ڷ���ҳĿ¼����
    
    ; ��ҳĿ¼�ڴ��������е�ַ 0x00000000 ��Ӧ��Ŀ¼��
    mov dword [es:ebx+0], 0x00021003  ; ����ӳ���1M���ڴ�
    
    mov ebx, 0x00021000   ; ��һ��ҳ��Ļ���ַ����ҳĿ¼�����ڶ�Ӧ��1M�ڴ� 
    xor eax, eax
    xor esi, esi
 .b2:
    mov edx, eax
    or edx, 0x00000003
    mov [es:ebx+esi*4], edx
    add eax, 0x1000
    inc esi
    cmp esi, 256
    jl .b2
    
 .b3:                    ; ��һ��ҳ���е�1M�ڴ�֮���ҳ����ÿ� 
    mov dword [es:ebx + esi * 4], 0x00000000
    inc esi
    cmp esi, 1024
    jl .b3
    
    mov eax, 0x00020000  ; CR3�Ĵ�������ҳ�����ַ 
    mov cr3, eax
    
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax
    
    ;mov ebx, 0xFFFFF000   ; ҳĿ¼�Լ������Ի���ַ
    mov ebx, 0x00020000   ; ���ڵ�1M�ڴ�ֱ��ӳ��Ϊ�����ַ�ĵ�1M����˿���ֱ�ӷ���ҳĿ¼ 
    mov esi, 0x80000000   ; ӳ�����ʼ��ַ
    shr esi, 22
    shl esi, 2            ; ��ʼ��ַ�� ��ҳĿ¼�е���������10λ �� 4��
    mov dword [es:ebx + esi], 0x00021003  ; ����1M�ڴ�ӳ�䵽0x80000000��ʼ��ַ��
    
    sgdt [pgdt]
    mov ebx, [pgdt + 2]
    or dword [es:ebx + 0x10 + 4], 0x80000000
    or dword [es:ebx + 0x18 + 4], 0x80000000
    or dword [es:ebx + 0x20 + 4], 0x80000000
    or dword [es:ebx + 0x28 + 4], 0x80000000
    or dword [es:ebx + 0x30 + 4], 0x80000000
    or dword [es:ebx + 0x38 + 4], 0x80000000                     
     
    add dword [pgdt + 2], 0x80000000
    
    lgdt [pgdt]
    jmp core_code_seg_sel:flush    ; ˢ��CS�Ĵ��������ø߶����Ե�ַ
    
 flush:
    mov eax, core_stack_seg_sel
    mov ss, eax
    
    mov eax, core_data_seg_sel
    mov ds, eax

    mov ebx, message_1
    call sys_routine_seg_sel:put_string
         
    ; setup call gate
    mov ecx, salt_items
    mov edi, salt
 .stgate:
    push ecx
    
    mov eax, [edi + 256]
    mov bx, [edi + 260]
    mov cx, 1_11_0_1100_000_00000b 
    call sys_routine_seg_sel:make_gate_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor
    or cx, 0x03      ; Ring3 ���Է���     
    mov word [edi + 260], cx
    
    add edi, salt_item_len
    pop ecx
    loop .stgate
    
    mov ebx, message_2         ; gate call
    call far [salt + 256] 
 
    ; �����ں�����
    mov ebx, [core_next_laddr]
    call sys_routine_seg_sel:alloc_inst_a_page
    add dword [core_next_laddr], 4096
    
    mov word [es:ebx + 0], 0
    mov eax, cr3
    mov dword [es:ebx + 28], eax ; TSS��CR3�ֶ�(PDBR)����ΪCR3�е�ֵ 
    
    ; ���TSS�еı�Ҫ����
    mov word [es:ebx + 96], 0    ; LDT �������ֶ���Ϊ0
    mov word [es:ebx + 100], 0   ; T=0    
    mov word [es:ebx + 102], 103 ; I/Oλͼ��0��Ȩ������Ҫ
                                 ; ������Ȩ���Ķ�ջҲ����Ҫ
                                                                  
    ; ����TSS����������װGDT
    mov eax, ebx
    mov ebx, 103
    mov ecx, 0x00408900  
    call sys_routine_seg_sel:make_seg_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor
    mov [prgman_tss+0x04], cx    ; �����������TSS������ѡ����
    
    ; ����Ĵ���TR��������������ڱ�־�������˵�ǰ������˭
    ; ����ָ��Ϊ��ǰ����ִ�е�0��Ȩ������������� ����TSS���� 
    ltr cx    


    ;============================================

    ; ���� TCB 
    mov ecx, 0x46
    call sys_routine_seg_sel:allocate_memory
    call append_to_tcb_link
    ; �����û�����ѹջ �û������LBA/���ص�ַ 
    push app_prog_lba      ; 
    push ecx
    call load_relocate_program

    ;mov ebx, do_status         ; Done.
    ;call sys_routine_seg_sel:put_string
    
    call far [es:ecx+0x14]    ; ִ�������л�������һ�²�ͬ�������л�ʱҪ�ָ�TSS����
                              ; �����ڴ�������ʱTSSҪ��д���� 
    ; ���¼��ز��л�����
    ;mov ebx, prgman_msg2
    ;call sys_routine_seg_sel:put_string
    
    hlt

core_code_end:
    
SECTION core_trail

core_end:
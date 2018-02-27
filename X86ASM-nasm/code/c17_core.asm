;
; Core
;
app_prog1_lba      equ     20   ; Ӧ�ó���1 ���ڵ���ʼ������
app_prog2_lba      equ     30   ;
app_prog_startoff  equ     0x10 ; Ӧ�ó�����ʼƫ�� 

flat_4gb_data_seg_sel  equ    0x10
flat_4gb_code_seg_sel  equ    0x08
idt_linear_address     equ    0x8001f000
video_ram_address      equ    0x800B8000

; 
%macro alloc_core_linear 0
    mov ebx, [core_tcb+0x06]
    add dword [core_tcb+0x06], 0x1000
    call flat_4gb_code_seg_sel:alloc_inst_a_page
%endmacro

%macro alloc_user_linear 0
    mov ebx, [esi+0x06]
    add dword [esi+0x06], 0x1000
    call flat_4gb_code_seg_sel:alloc_inst_a_page
%endmacro 
   
SECTION core align=16 vstart=0x80040000
    core_lenght   dd core_end     ; �����ܳ��� 
    core_entry    dd start        ; ���Ĵ�����ʼ��ַ 
;
    [bits 32]

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
    pushad
        
    xor eax, eax    
    call get_cursor_pos
    mov ebx, eax
    
    cmp cl, 0x0d
    jz put_0d
    cmp cl, 0x0a
    jz put_0a
    
    shl ebx, 1  ; ��������ַ�
    mov [ebx + video_ram_address], cl
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
    add edi, video_ram_address
    mov esi, 0xa0
    add esi, video_ram_address    
    mov ecx, 1920
    rep movsw

    mov eax, 0x20
    mov ecx, 80
  cls_ln:
    mov byte [edi + video_ram_address], al
    add edi, 2
    loop cls_ln

    mov ebx, 1920   ; ���ù��λ��

  reset_cur: 
    call set_cursor_pos

    popad
    ret      
;
; Show a string(zero end) on screen
; param:
;   EBX  ָ��Ҫ����ַ�����0������������ַ 
put_string:

    cli
    
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
    
    sti    
    
    retf    
;
; clean screen 
;
screen_cls:
    push ecx
    push edi
    push eax
        
    mov edi, video_ram_address
    mov ecx, 2000
    mov eax, 0x0720
mov_word:    
    mov [edi], ax
    add edi, 2
    loop mov_word 
    
    pop eax
    pop edi
    pop ecx
    retf 

;
; read a section from disk
; EAX: section no.  EDI: memory buffer
read_hard_disk_section:
    
    cli
    
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
    
    sti
    
    retf

; 
; For debug, output DWORD
;
put_hex_dword:
    
    pushad
    
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
  
    popad
    retf


; EDX:EAX - [IN]  descriptor item
; CX - [OUT] selector
;
set_up_gdt_descriptor:
    push eax
    push ebx 
    push edx
    
    sgdt [pgdt]
    
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
;
;
;
terminate_current_task:
        
    mov eax, tcb_chain
 .b0:
    mov ebx, [eax]
    cmp word [ebx+0x04], 0xffff
    je .b1
    mov eax, ebx
    jmp .b0
    
 .b1: 
    mov word [ebx+0x04], 0x3333
 .b2:
    hlt
    jmp .b2

;
; ����һ��4K��ҳ 
; EAX=ҳ�������ַ 
allocate_a_4k_page:
   
   push ebx
   push ecx
   push edx
   
   xor eax, eax
 .b1:
   bts [page_bit_map], eax
   jnc .b2
   inc eax
   cmp eax, page_map_len*8
   jl .b1
   
   mov ebx, message_3
   call flat_4gb_code_seg_sel:put_string
   hlt
   
 .b2:
   shl eax, 12
   
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

    pop esi
    pop ebx
    pop eax
    
    retf   
    
create_copy_cur_pdir:

    push esi
    push edi
    push ebx 
    push ecx
    
    call allocate_a_4k_page
    mov ebx, eax
    or ebx, 0x00000007
    mov [0xFFFFFFF8], ebx
    
    invlpg [0xFFFFFFF8]
    
    mov esi, 0xFFFFF000
    mov edi, 0xFFFFE000
    mov ecx, 1024
    cld
    repe movsd    
    
    pop ecx
    pop ebx 
    pop edi
    pop esi
    retf        

; ͨ���жϴ������ 
general_interrupt_handler:
    push eax
    
    mov al, 0x20   ;�жϽ������� EOI 
    out 0xa0, al   ; ����Ƭ���� 
    out 0x20, al   ; ���Ƭ���� 
    
    pop eax
    
    iretd    

; ͨ���쳣�������
general_exception_handler:
    mov ebx, excep_msg
    call flat_4gb_code_seg_sel:put_string
    hlt    

rtm_0x70_interrupt_handle:
    
    pushad
    
    mov al, 0x20
    out 0xa0, al
    out 0x20, al
    
    mov al, 0x0c
    out 0x70, al
    in al, 0x71
    
    mov eax, tcb_chain
    
 .b0:
    mov ebx, [eax]
    or ebx, ebx
    jz .irtn
    cmp word [ebx+0x04], 0xffff
    je .b1
    mov eax, ebx
    jmp .b0
    
 .b1:
    mov ecx, [ebx]     ; �ҵ�æ�ڵ㣬�������� 
    mov [eax], ecx 
 .b2:
    mov edx, [eax]
    or edx, edx
    jz .b3
    mov eax, edx       ; ����Ѱ�����һ���ڵ� 
    jmp .b2
 
 .b3:
    mov [eax], ebx     ; �ҵ���β�ڵ㣬��EBX�е�æ�ڵ���� 
    mov dword [ebx], 0x00000000
    
    mov eax, tcb_chain  ; Ѱ�ҿ��н�� 
 .b4:
    mov eax, [eax]
    or eax, eax
    jz .irtn
    cmp word [eax+0x04], 0x0000
    jnz .b4
    
    not word [eax+0x04]    ; �ҵ����н�㣬����״̬ 
    not word [ebx+0x04]
    jmp far [eax + 0x14]   ; �����л�
    
 .irtn:
    popad
    
    iretd                 
    
;======================================
; data    
    pgdt      dw   0
              dd   0
    pidt      dw   0
              dd   0
    
    tcb_chain dd   0
    core_tcb times 32 db 0    ; �ں˵�TCB 
              
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
              
    ; ������
    salt:
    salt_1    db   '@PrintString'
              times 256-($-salt_1) db 0
              dd   put_string
              dw   flat_4gb_code_seg_sel
    salt_2    db   '@ReadDiskData'
              times 256-($-salt_2) db 0
              dd   read_hard_disk_section
              dw   flat_4gb_code_seg_sel
    salt_3    db   '@PrintDwordAsHexString'
              times 256-($-salt_3) db 0
              dd   put_hex_dword
              dw   flat_4gb_code_seg_sel
    salt_4    db   '@TerminateProgram'
              times 256-($-salt_4) db 0
              dd   terminate_current_task
              dw   flat_4gb_code_seg_sel
    
    salt_item_len equ $-salt_4
    salt_items    equ 4;($-salt)/salt_item_len

    excep_msg db '*****Exception encounted*****', 0

    message_0 db ' Working in system core, protect mode.'
              db 0x0d,0x0a,0
    
    message_1 db ' Paging is enabled. System core is mapped to'
              db ' address 0x80000000.',0x0d,0x0a,0
    message_2 db 0x0d,0x0a 
              db ' System wide CALL-GATE mounted.',0x0d,0x0a,0

    message_21 db 0x0d,0x0a, ' Running in Program Manager.',0x0d,0x0a,0
    
    message_3 db '********No more pages********',0
    
    core_msg0  db ' System core task running', 0x0d, 0x0a, 0
                  
    bin_hex db '0123456789ABCDEF'
    
    core_buf times 2048 db 0
    
    cpu_brand0 db 0x0d,0x0a,' ',0
    cpu_brand times 64 db 0
    cpu_brand1 db 0x0d,0x0a,0x0d,0x0a,0    
                   
core_data_end:

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
    
    mov ebp, esp       ; Ϊ����ջ�ϲ���׼����׼ֵ 
    
    ; ��յ�ǰҳĿ¼��ǰ�벿��
    mov ebx, 0xFFFFF000
    xor esi, esi
 .b1:
    mov dword [ebx + esi*4], 0x00000000
    inc esi
    cmp esi, 512
    jl .b1     
    
    mov eax, cr3
    mov cr3, eax     
                
    ; load user program to memory
    mov eax, [ebp+10*4]  ; �û�������ʼ LBA    
    mov edi, core_buf
    call flat_4gb_code_seg_sel:read_hard_disk_section     ; get header
    
    mov eax, dword [core_buf]
    mov ebx, eax
    and ebx, 0xFFFFF000
    add ebx, 0x1000
    test eax, 0x00000FFF    ; �������������� �� ���㣬��λEFLAGS��� 
    cmovnz eax, ebx

    mov ecx, eax
    shr ecx, 12    ; ������Ҫ�ж���ҳ 
        
    push edi
    mov esi, [ebp+9*4]    ; TCB ����ַ    
    mov eax, [ebp+10*4]     ; ��ʵ������ LBA 
 .b2:
    alloc_user_linear     ; �꣺���û������ַ�ռ��Ϸ����ڴ� 
    
    mov edi, ebx
    push ecx
    mov ecx, 8
 .b3:
    call flat_4gb_code_seg_sel:read_hard_disk_section 
    inc eax
    add edi, 512
    loop .b3
    
    pop ecx    
    loop .b2
    pop edi
     
    alloc_core_linear         ; �ں˿ռ䴴���û���TSS 
    
    mov [esi+0x14], ebx        ; TCB��TSS���Ե�ַ 
    mov word [esi+0x12], 103   ; TCB��TSS���� 
    
    ;������������     0x00
    alloc_user_linear 
    mov [esi + 0x0c], ebx    
     
    xor eax, eax
    mov ebx, 0x000FFFFF     ; seg len
    mov ecx, 0x00C0F800    ; attributes
    call flat_4gb_code_seg_sel:make_seg_descriptor    
    mov ebx, esi
    call fill_descriptor_in_ldt       ; ��װ��LDT��      
    or cx, 0000_0000_0000_0011B    ; Ȩ��ֵ��Ϊ 3 
    mov ebx, [esi+0x14]
    mov [ebx + 76], cx 
        
    ;�����������ݶ�������   0x07
    xor eax,eax
    mov ebx,0x000FFFFF                 ;�γ���
    mov ecx,0x00C0F200                 ;�ֽ����ȵ����ݶ�������
    call flat_4gb_code_seg_sel:make_seg_descriptor
    mov ebx, esi
    call fill_descriptor_in_ldt
    or cx, 0000_0000_0000_0011B
    mov ebx, [esi+0x14]
    mov [ebx + 84], cx       ; TSS DS��
    mov [ebx + 72], cx       ; TSS ES��
    mov [ebx + 88], cx       ; TSS FS��
    mov [ebx + 92], cx       ; TSS GS��                 

    ;���������ջ��������   0x0F
    alloc_user_linear
       
    mov ebx, [esi + 0x14]
    mov [ebx + 80], cx       ; TSS SS��
    mov edx, [esi+0x06]      ; ��Ϊջ�� ������ڴ�εĸߵ�ַ������һ����������ĵ�ַ 
    mov [ebx+56], edx        ; TSS ESP��
      
    cld

    mov edi, [0x08]              ;�û������ڵ�SALTλ��ͷ����0x2c��
    mov ecx, [0x0c]              ;�û������SALT��Ŀ��    
  .b4: 
    push ecx
    push edi
      
    mov ecx, salt_items
    mov esi, salt
  .b5:
    push edi
    push esi
    push ecx

    mov ecx,64                         ;�������У�ÿ��Ŀ�ıȽϴ��� 
    repe cmpsd                         ;ÿ�αȽ�4�ֽ� 
    jnz .b6
    mov eax,[esi]                      ;��ƥ�䣬esiǡ��ָ�����ĵ�ַ����
    mov [edi-256],eax               ;���ַ�����д��ƫ�Ƶ�ַ 
    mov ax,[esi+4]
    or ax, 0000000000000011B        ; RPL=3
    mov [edi-252],ax                ;�Լ���ѡ���� 
  .b6:
      
    pop ecx
    pop esi
    add esi,salt_item_len
    pop edi                            ;��ͷ�Ƚ� 
    loop .b5
      
    pop edi
    add edi,256
    pop ecx
    loop .b4

    
    mov esi, [ebp + 9*4]
    alloc_user_linear
    
    mov eax, 0x00000000
    mov ebx, 0x000FFFFF
    mov ecx, 0x00C09200       ; 4K���ȣ���Ȩ��0
    call flat_4gb_code_seg_sel:make_seg_descriptor
    mov ebx, esi
    call fill_descriptor_in_ldt
    
    mov ebx, [esi+0x14]
    mov [ebx+8], cx
    mov edx, [esi+0x06]
    mov [ebx+4], edx 
    
    ;����1��Ȩ����ջ
    alloc_user_linear
    
    mov eax, 0x00000000
    mov ebx, 0x000FFFFF
    mov ecx, 0x00C0B200                 ;4KB���ȣ���д����Ȩ��1
    call flat_4gb_code_seg_sel:make_seg_descriptor
    mov ebx, esi                        ;TCB�Ļ���ַ
    call fill_descriptor_in_ldt
    or cx, 0000_0000_0000_0001B         ;����ѡ���ӵ���Ȩ��Ϊ1
    
    mov ebx, [esi+0x14]             ; TSS ����ַ
    mov [ebx + 16], cx
    mov edx, [esi+0x06]             ; ��ջ�߶˵�ַ
    mov [ebx + 12], edx             ; TSS ESP1 

    ;����2��Ȩ����ջ
    alloc_user_linear

    mov eax, 0x00000000
    mov ebx, 0x000FFFFF
    mov ecx,0x00c0d200                 ;4KB���ȣ���д����Ȩ��1
    call flat_4gb_code_seg_sel:make_seg_descriptor
    mov ebx,esi                        ;TCB�Ļ���ַ
    call fill_descriptor_in_ldt
    or cx,0000_0000_0000_0010B         ;����ѡ���ӵ���Ȩ��Ϊ1

    mov ebx, [esi+0x14]             ; TSS ����ַ
    mov [ebx + 24], cx
    mov edx, [esi+0x06]             ; ��ջ�߶˵�ַ
    mov [ebx + 20], edx             ; TSS ESP1

    ;��GDT�еǼ�LDT������
    mov esi, [ebp + 9*4]
    mov eax, [esi+0x0c]             ;LDT����ʼ���Ե�ַ
    movzx ebx,word [esi+0x0a]       ;LDT�ν���
    mov ecx,0x00408200                 ;LDT����������Ȩ��0
    call flat_4gb_code_seg_sel:make_seg_descriptor
    call flat_4gb_code_seg_sel:set_up_gdt_descriptor
    mov [esi+0x10],cx               ;�Ǽ�LDTѡ���ӵ�TCB��
    
    mov ebx, [esi+0x14]
    mov [ebx + 96], cx              ; TSS�� LDT�� 
    mov word [ebx + 0], 0           ; ������
    
    mov dx, [esi + 0x12]            ; �γ���
    mov [ebx + 102], dx
    mov word [ebx + 100], 0         ; T = 0
    
    mov eax, [0x04]
    mov [ebx + 32], eax             ; EIP 
    
    pushfd 
    pop edx
    mov [ebx + 36], edx             ; TSS��EFLAGS
               
    ;��GDT�еǼ�TSS������
    mov eax,[esi+0x14]              ;TSS����ʼ���Ե�ַ
    movzx ebx,word [esi+0x12]       ;�γ��ȣ����ޣ�
    mov ecx,0x00408900                 ;TSS����������Ȩ��0
    call flat_4gb_code_seg_sel:make_seg_descriptor
    call flat_4gb_code_seg_sel:set_up_gdt_descriptor
    mov [esi+0x18],cx               ;�Ǽ�TSSѡ���ӵ�TCB
    
    ; ����ҳĿ¼��ҳ��
    call flat_4gb_code_seg_sel:create_copy_cur_pdir
    mov ebx, [esi+0x14]
    mov dword [ebx+28], eax 
            
    popad
    ret 8
    
;
; ECX=tcb����ַ 
;
append_to_tcb_link:
    
    cli    ; ���ж� 
    
    push eax
    push edx        
    
    mov eax, tcb_chain
 .searc:
    mov edx, [eax]
    or edx, edx
    jz .notcb
       
    mov eax, edx
    jmp .searc
 .notcb:
    mov [eax], ecx ; �ձ�ֱ�ӽ�ͷָ��ָ���·���
    mov dword [ecx], 0x00000000 ; TCBָ������0�����һ��TCB
     
    pop edx
    pop eax
    
    sti      ; ���ж� 
    
    ret    
    
    ;
    ; Core Start Address
    ;
start:
    ; �����ж��������� IDT
    ; �ڴ�֮ǰ���ܵ��ú��� sti ָ�����
    
    call flat_4gb_code_seg_sel:screen_cls  ; ����

    xor ebx, ebx
    call flat_4gb_code_seg_sel:far_set_cursor_pos ; ���ù��λ��    
    
    ; ǰ20�������������쳣
    mov eax, general_exception_handler
    mov bx, flat_4gb_code_seg_sel
    mov cx, 0x8e00    ;  32λ���жϣ�0��Ȩ����
    call flat_4gb_code_seg_sel:make_gate_descriptor
    
    mov ebx, idt_linear_address     ; ����ڴ���1M֮�ڣ��Ѿ������䣨��ҳ�������ڴ棩 
    xor esi, esi
 .idt0:
    mov [ebx + esi*8], eax
    mov [ebx + esi*8 + 4], edx
    inc esi
    cmp esi, 19
    jle .idt0
    
    mov eax, general_interrupt_handler
    mov bx, flat_4gb_code_seg_sel
    mov cx, 0x8e00
    call flat_4gb_code_seg_sel:make_gate_descriptor
    
    mov ebx, idt_linear_address
 .idt1:
    mov [ebx+esi*8], eax
    mov [ebx+esi*8+4], edx
    inc esi
    cmp esi, 255
    jle .idt1
    
    ; ʵʱʱ���жϴ������
    mov eax, rtm_0x70_interrupt_handle
    mov bx, flat_4gb_code_seg_sel
    mov cx, 0x8e00
    call flat_4gb_code_seg_sel:make_gate_descriptor
    
    mov ebx, idt_linear_address
    mov [ebx+0x70*8], eax
    mov [ebx+0x70*8+4], edx
    
    ; �����ж�
    mov word [pidt], 256*8-1
    mov dword [pidt+2], idt_linear_address
    lidt [pidt]
    
    ; ����8259A�жϿ�����
    mov al, 0x11       ; ICW1, ���ش�����������ʽ 
    out 0x20, al
    mov al, 0x20       ; ICW2 ��ʼ�ж����� 
    out 0x21, al
    mov al, 0x04       ; ICW3 ��Ƭ������IR2 
    out 0x21, al
    mov al, 0x01       ; ICW4 �����߻��壬ȫǶ�ף�����EOI     
    out 0x21, al     
    
    mov al, 0x11       ; ICW1, ���ش�����������ʽ
    out 0xa0, al
    mov al, 0x70       ; ICW2 ��ʼ�ж�����
    out 0xa1, al
    mov al, 0x04       ; ICW3 ��Ƭ������IR2
    out 0xa1, al
    mov al, 0x01       ; ICW4 �����߻��壬ȫǶ�ף�����EOI
    out 0xa1, al
    
    ; ���ú�ʱ���ж���ص�Ӳ��
    mov al, 0x0b       ; RTC�Ĵ���B
    or al, 0x80        ; NMI���
    out 0x70, al
    mov al, 0x12       ; ���üĴ���B����ֹ�������жϣ����Ÿ��½������ж�
    out 0x71, al       ; BCD �룬24Сʱ��    
     
    in al, 0xa1        ; ��8259��Ƭ��IMR�Ĵ���
    and al, 0xfe       ; ���bit 0
    out 0xa1, al       ; д�ؼĴ���
    
    mov al, 0x0c
    out 0x70, al
    in al, 0x71        ; ��ȡRTC�Ĵ���C����λδ�����ж�״̬
     
    sti  ; ����Ӳ���ж�
        
    mov ebx, message_0   
    call flat_4gb_code_seg_sel:put_string 
           
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
    call flat_4gb_code_seg_sel:put_string
    mov ebx, cpu_brand
    call flat_4gb_code_seg_sel:put_string    
    mov ebx, cpu_brand1
    call flat_4gb_code_seg_sel:put_string
         
    ; setup call gate
    mov ecx, salt_items
    mov edi, salt
 .stgate:
    push ecx    
    mov eax, [edi + 256]
    mov bx, [edi + 260]
    mov cx, 1_11_0_1100_000_00000b 
    call flat_4gb_code_seg_sel:make_gate_descriptor
    call flat_4gb_code_seg_sel:set_up_gdt_descriptor
    ;or cx, 0x0003      ; Ring3 ���Է���     
    mov word [edi + 260], cx
    
    add edi, salt_item_len
    pop ecx
    loop .stgate
    
    mov ebx, message_2         ; gate call
    call far [salt + 256] 
 
    ; �����ں�����
    mov word [core_tcb+0x04], 0xffff      ; ״̬æµ
    mov dword [core_tcb+0x06], 0x80100000
    
    mov word [core_tcb+0x0a], 0xffff      ; �Ǽ�LDT��ʼ�Ľ���Ϊδʹ��
    mov ecx, core_tcb
    call append_to_tcb_link               ; ��ӵ�TCB����
    
    alloc_core_linear   ; �꣬���ں������ַ�ռ�����ڴ� 
        
    mov word [ebx + 0], 0
    mov eax, cr3
    mov dword [ebx + 28], eax ; TSS��CR3�ֶ�(PDBR)����ΪCR3�е�ֵ 
    
    ; ���TSS�еı�Ҫ����
    mov word [ebx + 96], 0    ; LDT �������ֶ���Ϊ0
    mov word [ebx + 100], 0   ; T=0    
    mov word [ebx + 102], 103 ; I/Oλͼ��0��Ȩ������Ҫ
                                 ; ������Ȩ���Ķ�ջҲ����Ҫ
                                                                  
    ; ����TSS����������װGDT
    mov eax, ebx
    mov ebx, 103
    mov ecx, 0x00408900  
    call flat_4gb_code_seg_sel:make_seg_descriptor
    call flat_4gb_code_seg_sel:set_up_gdt_descriptor
    mov [core_tcb+0x14], cx    ; �����������TSS������ѡ����
    
    ; ����Ĵ���TR��������������ڱ�־�������˵�ǰ������˭
    ; ����ָ��Ϊ��ǰ����ִ�е�0��Ȩ������������� ����TSS���� 
    ltr cx    

    ; ������ tss������Ϊ"���������"������ִ���� 
    mov ebx, message_21
    call flat_4gb_code_seg_sel:put_string

    ; ���� ����1 TCB
    alloc_core_linear
    
    mov word [ebx+0x04], 0           ; ����״̬������ 
    mov dword [ebx+0x06], 0          ; ��ʼ���õ������ַ 
    mov word [ebx+0x0a], 0xffff
        
    ; �����û�����ѹջ �û������LBA/���ص�ַ 
    push app_prog1_lba      ; 
    push ebx
    call load_relocate_program
    mov ecx, ebx
    call append_to_tcb_link 

    ; ���� ����2 TCB
    alloc_core_linear

    mov word [ebx+0x04], 0           ; ����״̬������
    mov dword [ebx+0x06], 0          ; ���õ���ʼ�����ַ 
    mov word [ebx+0x0a], 0xffff

    ; �����û�����ѹջ �û������LBA/���ص�ַ
    push app_prog2_lba      ;
    push ebx
    call load_relocate_program
    mov ecx, ebx
    call append_to_tcb_link
    
 .core: 
    mov ebx, core_msg0 
    call flat_4gb_code_seg_sel:put_string
    
    jmp .core 

core_code_end:
    
SECTION core_trail

core_end:
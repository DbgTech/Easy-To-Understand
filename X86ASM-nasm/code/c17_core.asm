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
    
create_copy_cur_pdir:
    push ds
    push es
    push esi
    push edi
    push ebx 
    push ecx
    
    mov ebx, mem_0_4_gb_seg_sel
    mov ds, ebx
    mov es, ebx
    
    call allocate_a_4k_page
    mov ebx, eax
    or ebx, 0x00000007
    mov [0xFFFFFFF8], ebx
    
    mov esi, 0xFFFFF000
    mov edi, 0xFFFFE000
    mov ecx, 1024
    cld
    repe movsd    
    
    pop ecx
    pop ebx 
    pop edi
    pop esi
    pop es
    pop ds
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

    message_21 db 0x0d,0x0a, ' Running in Program Manager.',0x0d,0x0a,0
    
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
    
    ; ��յ�ǰҳĿ¼��ǰ�벿��
    mov ebx, 0xFFFFF000
    xor esi, esi
 .b1:
    mov dword [es:ebx + esi*4], 0x00000000
    inc esi
    cmp esi, 512
    jl .b1     
                
    ; load user program to memory
    mov eax, [ebp+12*4]  ; �û�������ʼ LBA    
    mov edi, core_buf
    call sys_routine_seg_sel:read_hard_disk_section     ; get header
    
    mov eax, dword [core_buf]
    mov ebx, eax
    and ebx, 0xFFFFF000
    add ebx, 0x1000
    test eax, 0x00000FFF    ; �������������� �� ���㣬��λEFLAGS��� 
    cmovnz eax, ebx

    mov ecx, eax
    shr ecx, 12    ; ������Ҫ�ж���ҳ 
        
    mov eax, mem_0_4_gb_seg_sel
    mov ds, eax
    
    push edi
    mov esi, [ebp+11*4]    ; TCB ����ַ    
    mov eax, [ebp+12*4]    ; ��ʵ������ LBA 
 .b2:
    mov ebx, [es:esi + 0x06] ; �������Ե�ַ
    add dword [es:esi + 0x06], 0x1000
    call sys_routine_seg_sel:alloc_inst_a_page
    
    mov edi, ebx
    push ecx
    mov ecx, 8
 .b3:
    call sys_routine_seg_sel:read_hard_disk_section 
    inc eax
    add edi, 512
    loop .b3
    
    pop ecx    
    loop .b2
    pop edi
     
    mov eax, core_data_seg_sel   ; �����ں����ݶ� 
    mov ds, eax
    
    mov ebx, [core_next_laddr]   ; ���ں� �ռ���� TSS 
    call sys_routine_seg_sel:alloc_inst_a_page
    add dword [core_next_laddr], 4096
    
    mov [es:esi+0x14], ebx        ; TCB��TSS���Ե�ַ 
    mov word [es:esi+0x12], 103   ; TCB��TSS���� 
    
    ;������������     0x00 
    mov ebx, [es:esi+0x06]      ; ȡ�ÿ������Ե�ַ
    add dword [es:esi+0x06], 0x1000
    call sys_routine_seg_sel:alloc_inst_a_page
    mov [es:esi + 0x0c], ebx    
     
    xor eax, eax
    mov ebx, 0x000FFFFF     ; seg len
    mov ecx, 0x00C0F800    ; attributes
    call sys_routine_seg_sel:make_seg_descriptor    
    mov ebx, esi
    call fill_descriptor_in_ldt       ; ��װ��LDT��      
    or cx, 0000_0000_0000_0011B    ; Ȩ��ֵ��Ϊ 3 
    mov ebx, [es:esi + 0x14]
    mov [es:ebx + 76], cx 
        
    ;�����������ݶ�������   0x07
    xor eax,eax
    mov ebx,0x000FFFFF                 ;�γ���
    mov ecx,0x00C0F200                 ;�ֽ����ȵ����ݶ�������
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx, esi
    call fill_descriptor_in_ldt
    or cx, 0000_0000_0000_0011B
    mov ebx, [es:esi+0x14]
    mov [es:ebx + 84], cx       ; TSS DS��
    mov [es:ebx + 72], cx       ; TSS ES��
    mov [es:ebx + 88], cx       ; TSS FS��
    mov [es:ebx + 92], cx       ; TSS GS��                 

    ;���������ջ��������   0x0F
    mov ebx,[es:esi+0x06]                 ;4KB�ı���
    add dword [es:esi + 0x06], 0x1000
    call sys_routine_seg_sel:alloc_inst_a_page    
    mov ebx, [es:esi + 0x14]
    mov [es:ebx + 80], cx       ; TSS SS��
    mov edx, [es:esi+0x06]      ; ��Ϊջ�� ������ڴ�εĸߵ�ַ������һ����������ĵ�ַ 
    mov [es:ebx+56], edx        ; TSS ESP��

    ;�ض�λSALT
    mov eax, mem_0_4_gb_seg_sel
    mov es,eax                         ;es -> �û�����ͷ�� 
    mov eax,core_data_seg_sel
    mov ds,eax
      
    cld

    mov edi, [es:0x08]              ;�û������ڵ�SALTλ��ͷ����0x2c��
    mov ecx, [es:0x0c]              ;�û������SALT��Ŀ��    
  .b4: 
    push ecx
    push edi
      
    mov ecx,salt_items
    mov esi,salt
  .b5:
    push edi
    push esi
    push ecx

    mov ecx,64                         ;�������У�ÿ��Ŀ�ıȽϴ��� 
    repe cmpsd                         ;ÿ�αȽ�4�ֽ� 
    jnz .b6
    mov eax,[esi]                      ;��ƥ�䣬esiǡ��ָ�����ĵ�ַ����
    mov [es:edi-256],eax               ;���ַ�����д��ƫ�Ƶ�ַ 
    mov ax,[esi+4]
    mov [es:edi-252],ax                ;�Լ���ѡ���� 
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

    
    mov esi, [ebp + 11*4]
    mov ebx, [es:esi + 0x06]
    add dword [es:esi+0x06], 0x1000
    call sys_routine_seg_sel:alloc_inst_a_page
    
    mov eax, 0x00000000
    mov ebx, 0x000FFFFF
    mov ecx, 0x00C09200       ; 4K���ȣ���Ȩ��0
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx, esi
    call fill_descriptor_in_ldt
    mov ebx, [es:esi+0x14]
    mov [es:ebx+8], cx
    mov edx, [es:esi+0x06]
    mov [es:ebx+4], edx 
    
    ;����1��Ȩ����ջ
    mov ebx, [es:esi + 0x06]
    add dword [es:esi + 0x06], 0x1000
    call sys_routine_seg_sel:alloc_inst_a_page
    
    mov eax, 0x00000000
    mov ebx, 0x000FFFFF
    mov ecx, 0x00C0B200                 ;4KB���ȣ���д����Ȩ��1
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx, esi                        ;TCB�Ļ���ַ
    call fill_descriptor_in_ldt
    or cx, 0000_0000_0000_0001B         ;����ѡ���ӵ���Ȩ��Ϊ1
    
    mov ebx, [es:esi+0x14]             ; TSS ����ַ
    mov [es:ebx + 16], cx
    mov edx, [es:esi+0x06]             ; ��ջ�߶˵�ַ
    mov [es:ebx + 12], edx             ; TSS ESP1 

    ;����2��Ȩ����ջ
    mov ebx, [es:esi + 0x06]
    add dword [es:esi + 0x06], 0x1000
    call sys_routine_seg_sel:alloc_inst_a_page

    mov eax, 0x00000000
    mov ebx, 0x000FFFFF
    mov ecx,0x00c0d200                 ;4KB���ȣ���д����Ȩ��1
    call sys_routine_seg_sel:make_seg_descriptor
    mov ebx,esi                        ;TCB�Ļ���ַ
    call fill_descriptor_in_ldt
    or cx,0000_0000_0000_0010B         ;����ѡ���ӵ���Ȩ��Ϊ1

    mov ebx, [es:esi+0x14]             ; TSS ����ַ
    mov [es:ebx + 24], cx
    mov edx, [es:esi+0x06]             ; ��ջ�߶˵�ַ
    mov [es:ebx + 20], edx             ; TSS ESP1

    ;��GDT�еǼ�LDT������
    mov esi, [ebp + 11*4]
    mov eax, [es:esi+0x0c]             ;LDT����ʼ���Ե�ַ
    movzx ebx,word [es:esi+0x0a]       ;LDT�ν���
    mov ecx,0x00408200                 ;LDT����������Ȩ��0
    call sys_routine_seg_sel:make_seg_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor
    mov [es:esi+0x10],cx               ;�Ǽ�LDTѡ���ӵ�TCB��
    
    mov ebx, [es:esi+0x14]
    mov [es:ebx + 96], cx              ; TSS�� LDT�� 
    mov word [es:ebx + 0], 0           ; ������
    
    mov dx, [es:esi + 0x12]            ; �γ���
    mov [es:ebx + 102], dx
    mov word [es:ebx + 100], 0         ; T = 0
    
    mov eax, [es:0x04]
    mov [es:ebx + 32], eax             ; EIP 
    
    pushfd 
    pop edx
    mov [es:ebx + 36], edx             ; TSS��EFLAGS
               
    ;��GDT�еǼ�TSS������
    mov eax,[es:esi+0x14]              ;TSS����ʼ���Ե�ַ
    movzx ebx,word [es:esi+0x12]       ;�γ��ȣ����ޣ�
    mov ecx,0x00408900                 ;TSS����������Ȩ��0
    call sys_routine_seg_sel:make_seg_descriptor
    call sys_routine_seg_sel:set_up_gdt_descriptor
    mov [es:esi+0x18],cx               ;�Ǽ�TSSѡ���ӵ�TCB
    
    ; ����ҳĿ¼��ҳ��
    call sys_routine_seg_sel:create_copy_cur_pdir
    mov ebx, [es:esi+0x14]
    mov dword [es:ebx+28], eax 

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
    or cx, 0x0003      ; Ring3 ���Է���     
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

    ; ������ tss������Ϊ"���������"������ִ���� 
    mov ebx, message_21
    call sys_routine_seg_sel:put_string

    ; ���� TCB
    mov ebx, [core_next_laddr]
    call sys_routine_seg_sel:alloc_inst_a_page
    add dword [core_next_laddr], 4096
    
    mov dword [es:ebx + 0x06], 0
    mov word [es:ebx + 0x0a], 0xffff
    mov ecx, ebx     
    call append_to_tcb_link
    
    ; �����û�����ѹջ �û������LBA/���ص�ַ 
    push app_prog_lba      ; 
    push ecx
    call load_relocate_program

    mov ebx, message_4
    call sys_routine_seg_sel:put_string
    
    call far [es:ecx+0x14]    ; ִ�������л�������һ�²�ͬ�������л�ʱҪ�ָ�TSS����
                              ; �����ڴ�������ʱTSSҪ��д���� 
    ; ���¼��ز��л�����
    mov ebx, message_5
    call sys_routine_seg_sel:put_string
    
    hlt

core_code_end:
    
SECTION core_trail

core_end:
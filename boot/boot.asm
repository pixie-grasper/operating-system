  ; ds
  section .bss vstart=0x0000
  org 0x0000
a20_check_buffer resw 1
graphics_current_pos resw 1
drive_number resb 1
padding1 resb 1
loaded_segment_info:
  .br: resw 1
  .pvd: resw 1
  .svd: resw 1
  .vpd: resw 1
  .bc: resw 1
  .pt: resw 1
pass_table_size resw 1

  ; cs
  section .text vstart=0x0000
  org 0x0000
  bits 16
  cpu 8086

  jmp 0x07c0:init

init:
  mov ax, cs
  mov ds, ax
  mov ax, 0x7000
  mov ss, ax
  or ax, -1
  mov fs, ax
  mov ax, 0xb800
  mov gs, ax
  xor ax, ax
  mov sp, ax
  mov [ds:graphics_current_pos], ax
  mov [ds:drive_number], dl
  cld

check_8086:
  ; if CPU 8086, flags bits 15:12 cannot clear
  pushf
  pushf
  pop ax
  mov cx, ax
  and ax, 0x0fff
  push ax
  popf
  pushf
  pop ax
  and ax, 0xf000
  cmp ax, 0xf000
  je failed_cpu

  cpu 286
check_286:
  ; if CPU 286, flags bits 15:12 always clear
  or cx, 0xf000
  push cx
  popf
  pushf
  pop ax
  test ax, 0xf000
  jz failed_cpu
  popf

  cpu 386
check_cpuid:
  ; if CPU has CPUID, bits 21 modifiable
  pushfd
  pop eax
  mov ecx, eax
  xor eax, 0x00200000
  push eax
  popfd
  pushfd
  pop eax
  cmp eax, ecx
  je failed_cpu
  push ecx
  popfd

  cpu 586
check_64bit:
  mov eax, 0x00000001
  cpuid
  test edx, 0x00000040  ; PAE supported?
  jz failed_cpu
  mov eax, 0x80000000
  cpuid
  cmp eax, 0x80000001
  jb failed_cpu
  mov eax, 0x80000001
  cpuid
  test edx, 0x20000000  ; IA-32e mode supported?
  jz failed_cpu

  cpu x64
relocate_loader:
  ; copy from 0x07c0:0000 to 0x0080:0000
  mov ax, 0x0080
  mov es, ax
  mov si, 0x0000
  mov di, 0x0000
  mov cx, 2048 / 2
  rep movsw
  jmp 0x0080:relocated

relocated:
  mov ax, cs
  mov ds, ax

before_load_sections:
  xor eax, eax
  mov [loaded_segment_info], eax
  mov [loaded_segment_info + 4], eax
load_sections:
  mov ah, 0x42
  mov dl, [drive_number]
  mov si, int13h42hpacket
  int 0x13
  jc failed
  inc word [int13h42hpacket.lba]
  mov si, int13h42hpacket.segment
  mov cx, [si]
  add word [si], 0x0080
  mov es, cx
  mov eax, 'CD00'
  cmp eax, [es:0x0001]
  jne failed
  mov al, '1'
  cmp al, [es:0x0005]
  jne failed
  mov al, [es:0x0000]
  cmp al, 0x00
  je check_boot_record
  cmp al, 0x01
  je check_primary_volume_descriptor
  cmp al, 0x02
  je check_supplementary_volume_descriptor
  cmp al, 0x03
  je check_volume_partition_descriptor
  cmp al, 0xff
  je volume_descriptor_set_terminated
  jmp load_sections

check_boot_record:
  mov [loaded_segment_info.br], cx
  jmp load_sections

check_primary_volume_descriptor:
  mov [loaded_segment_info.pvd], cx
  jmp load_sections

check_supplementary_volume_descriptor:
  mov [loaded_segment_info.svd], cx
  jmp load_sections

check_volume_partition_descriptor:
  mov [loaded_segment_info.vpd], cx
  jmp load_sections

volume_descriptor_set_terminated:
  ; first, check the boot record
  mov ax, [loaded_segment_info.br]
  test ax, ax
  jz failed
  mov es, ax
  mov si, el_torito_boot_record_string
  mov di, 0x0000
  mov cx, 0x0020
  mov bx, 4
.l1:
  mov eax, [ds:si]
  cmp eax, [es:di]
  jne failed
  add si, bx
  add di, bx
  sub cx, bx
  jnz .l1
  ; then, check the boot catalog
  mov eax, [es:0x47]
  test eax, eax
  jz failed
  mov [int13h42hpacket.lba], eax
  mov ah, 0x42
  mov dl, [drive_number]
  mov si, int13h42hpacket
  int 0x13
  jc failed
  mov si, int13h42hpacket.segment
  mov cx, [si]
  add word [si], 0x0080
  mov es, cx
  mov [loaded_segment_info.bc], cx
  mov es, cx
  cmp dword [es:0x0000], 1
  jne failed
  cmp byte [es:0x0020], 0x88
  jne failed
  ; then, load the directory record for the root directory
  mov ax, [loaded_segment_info.pvd]
  test ax, ax
  jz failed
  mov es, ax
  mov eax, [es:156 + 2]  ; location
  test eax, eax
  jz failed
  mov [int13h42hpacket.lba], eax
  mov ecx, [es:156 + 10]  ; length
  add ecx, 0x07ff
  shr ecx, 11
  cmp ecx, 0x7f
  ja failed_too_big_table
  ; then, search the kernel
  mov di, kernel_name
.l2:
  mov [int13h42hpacket.numofsector], cx
  mov ah, 0x42
  mov dl, [drive_number]
  mov si, int13h42hpacket
  int 0x13
  jc failed
  mov si, int13h42hpacket.segment
  shl cx, 11
  mov ax, [si]
  add word [si], cx
  mov es, ax
  mov si, 32
.l3:
  mov bx, 0x0000
.l4:
  mov al, [ds:di + bx]
  test al, al
  jz .l6
  cmp al, [es:si + bx]
  je .l5
  add si, [es:si - 32]
  mov al, [es:si]
  test al, al
  jz failed  ; not found
  cmp si, 0x0800
  jb .l3
  mov ax, es
  add ax, 0x0080
  mov es, ax
  sub si, 0x0800
  jmp .l3
.l5:
  inc bx
  jmp .l4
.l6:
  sub si, 32
  mov eax, [es:si + 2]
  test eax, eax
  jz failed
  mov [int13h42hpacket.lba], eax
  mov ecx, [es:si + 10]
  add ecx, 0x07ff
  shr ecx, 11
  cmp ecx, 0x7f
  ja failed_too_big_table
  inc bx
  add di, bx
  mov al, [ds:di]
  test al, al
  jnz .l2
.l7:  ; find it!
  mov [int13h42hpacket.numofsector], cx
  mov word [int13h42hpacket.segment], 0x0200
  mov ah, 0x42
  mov dl, [drive_number]
  mov si, int13h42hpacket
  int 0x13
  jc failed

enable_a20:
  ; first, check a20 gate already enabled
  call check_a20
  je enter_protected_mode
  ; if not, check keyboard controller available
  cli
  in al, 0x64
  cmp al, 0xff
  jne .l1
  in al, 0x60
  cmp al, 0xff
  jne .l1
  ; if not, use system controll port
  in al, 0x92
  or al, 0x02
  out 0x92, al
  sti
  call wait_a20
  je enter_protected_mode
  jmp .l2
.l1:
  call kbd_busy_wait
  mov al, 0xad
  out 0x64, al  ; disable keyboard
  call kbd_buffer_make_empty
  mov al, 0xd1
  out 0x64, al  ; port open
  call kbd_busy_wait
  in al, 0x60
  or al, 2
  out 0x60, al  ; enable a20
  call kbd_buffer_make_empty
  mov al, 0xae
  out 0x64, al  ; enable keyboard
  call kbd_busy_wait
  sti
  call wait_a20
  je enter_protected_mode
.l2:
  ; if failed, try to use bios
  mov ax, 0x2401
  int 0x15
  jc failed
  call wait_a20
  jne failed

enter_protected_mode:
  cli
  lgdt [gdtr32]
  mov eax, cr0
  or eax, 0x00000001
  mov cr0, eax
  jmp .l1
.l1:
  mov ax, DataSelector32
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax
  mov esp, 0x00080000
  jmp CodeSelector32:enter_ia32e_mode

succeed:
  mov si, okmsg
  call print
  jmp end

failed:
  mov si, badmsg
  call print
  jmp end

failed_too_big_table:
  mov si, toobigptmsg
  call print
  jmp end

end:
  hlt
  jmp end

check_a20:
  ; ds = 0x0080
  ; fs = 0xffff
  mov di, 0x0810
  mov dx, [fs:di]
  mov word [fs:di], 0xffff
  mov word [ds:0x0000], 0x0000
  mov ax, [fs:di]
  mov [fs:di], dx
  test ax, ax
  jnz true
  jmp false

wait_a20:
  xor cx, cx
.l1:
  dd 0x00eb00eb  ; io-wait
  call check_a20
  je .l2
  inc cx
  jnz .l1
  jmp false
.l2:
  jmp true

kbd_busy_wait:
  in al, 0x64
  test al, 0x02  ; busy?
  jnz kbd_busy_wait
  ret

kbd_buffer_make_empty:
  in al, 0x64
  test al, 0x02  ; busy?
  jnz kbd_buffer_make_empty
  test al, 0x01  ; data in buffer?
  jz true
  in al, 0x60  ; get data from the buffer.
  jmp kbd_buffer_make_empty

true:
  xor ax, ax
  ret

false2:
  pop ax
false:
  or ax, -1
  ret

  cpu 8086
failed_cpu:
  mov si, badcpu
  call print
.l1:
  hlt
  jmp .l1

print:
  push di
  push ax
  mov di, [ds:graphics_current_pos]
  mov ah, 0x07
.l1:
  mov al, [ds:si]
  test al, al
  jz .l2
  mov [gs:di], ax
  inc si
  inc di
  inc di
  jmp .l1
.l2:
  mov [ds:graphics_current_pos], di
  pop ax
  pop di
  ret

  cpu x64
  bits 32
enter_ia32e_mode:
  ; first, create PML4E, PDPTE
  xor eax, eax
  mov dword [eax], 0x1000 + 0x0f
  mov [eax + 4], eax
  mov edi, 0x1000
  mov ecx, 4096 / 8
  mov edx, eax
  mov eax, 0x00000000 + 0x8f  ; 1 GiB paging
.l1:
  mov [edi], eax
  mov [edi + 4], edx
  add eax, 0x40000000
  adc edx, 0
  and edx, 0x0f  ; disable a64:a36
  add edi, 8
  dec ecx
  jnz .l1
  ; then, set CR4.PAE
  mov eax, cr4
  or eax, 0x00000020
  mov cr4, eax
  ; then, load CR3, PML4
  xor eax, eax
  mov cr3, eax
  ; then, set EFER.LME
  ; rdmsr ~> mov edx:eax, MSR[ecx]
  mov ecx, 0xc0000080
  rdmsr
  or eax, 0x00000100
  wrmsr
  ; then, set CR0.PG
  mov eax, cr0
  or eax, 0x80000000
  mov cr0, eax
  mov ax, DataSelector64
  mov ds, ax
  mov es, ax
  mov ss, ax
  xor ax, ax  ; null selector
  mov fs, ax
  mov gs, ax
  jmp CodeSelector64:0x2000

int13h42hpacket:
  db 0x10
  db 0x00
.numofsector dw 0x0001
.address: dw 0x0000
.segment: dw 0x0100
.lba:     dq 0x10

okmsg db 'ok.', 0x00
badmsg db 'failed.', 0x00
toobigptmsg db 'system error: too big directory.', 0x00
badcpu db 'BAD CPU.', 0
kernel_name db 0x04, 'BOOT', 0x00, 0x0c, 'KERNEL.BIN', 0x3b, 0x31, 0x00, 0x00

  align 4
el_torito_boot_record_string: db 0x00, 'CD001', 0x01, 'EL TORITO'
                              db ' SPECIFICATION', 0x00, 0x00

gdtr32:
  dw gdtend - gdtbegin
  dd gdtbegin

  align 16
  section .data vstart=0x0800+($-$$)
  ; type
  ; 0: read-only
  ; 1: read-only, accessed
  ; 2: read/write
  ; 3: read/write, accessed
  ; 4: read-only, expand-down
  ; 5: read-only, expand-down, accessed
  ; 6: read/write, expand-down
  ; 7: read/write, expand-down, accessed
  ; 8: execute-only
  ; 9: execute-only, accessed
  ; A: execute/read
  ; B: execute/read, accessed
  ; C: execute-only, conforming
  ; D: execute-only, conforming, accessed
  ; E: execute/read, conforming
  ; F: execute/read, conforming, accessed
gdtbegin:
  dq 0  ; null selector

CodeSelector32 equ 1 * 8
  dw 0xffff  ; Segment limit 15:0
  dw 0x0800  ; Base address 15:0
  db 0x00    ; Base 23:16
  db 0x9a    ; 7 = Segment present, 6:5 = Descriptor Privilege level, 4 = Descriptor type (0 = system; 1 = code or data) 3:0 = type
  db 0xcf    ; 7 = Granularity, 6 = Default operation size (0 = 16-bit segment, 1 = 32-bit segment), 5 = 64-bit code segment, 4 = Available for use by system software,
             ; 3:0 = Segment limit 19:16
  db 0x00    ; Base address 31:24

DataSelector32 equ 2 * 8
  dw 0xffff
  dw 0x0000
  db 0x00
  db 0x92
  db 0xcf
  db 0x00

CodeSelector64 equ 3 * 8
  dd 0x00000000
  db 0x00
  db 0x9a
  db 0xa0
  db 0x00

DataSelector64 equ 4 * 8
  dd 0x00000000
  db 0x00
  db 0x92
  db 0xa0
  db 0x00
gdtend:

%ifndef DESCRIPTOR_TABLES_ASM_
%define DESCRIPTOR_TABLES_ASM_

%include "interrupts.asm"

descriptor_tables:
.init:
  ; make gdt
  mov edi, [global_page_addr]
  mov esi, edi
  mov ecx, 4096 * global_page_size / 4
  xor eax, eax
.init.1:
  mov [edi], eax
  add edi, 4
  dec ecx
  jnz .init.1
  ; cs
  mov word [esi + 13], 0x209a
  ; ds
  mov byte [esi + 21], 0x92
  ; fs, gs
  lea edx, [esi + .TLS]
  mov [esi + 26], dx
  shr edx, 16
  mov [esi + 28], dl
  mov byte [esi + 29], 0x92
  mov [esi + 31], dh
  lea edx, [esi + .GDT]
  mov [.gdtr + 2], edx
  lgdt [.gdtr]
  ; set TLS
  mov ax, 3 * 8
  mov fs, ax
  mov gs, ax
  mov dword [esi + .TLS], 0x00100020
  ; make idt
  lea edi, [esi + .LDT]
  mov esi, interrupts.addresslist
  mov ecx, 256
.init.2:
  mov edx, [esi]
  mov [edi], dx
  mov byte [edi + 2], 1 * 8
  mov byte [edi + 5], 0x8e  ; type e = 64-bit interrupt gate
  shr edx, 16
  mov [edi + 6], dx
  add edi, 16
  add esi, 4
  dec ecx
  jnz .init.2
  mov esi, [global_page_addr]
  add esi, .LDT
  mov [.idtr + 2], esi
  lidt [.idtr]
  ret

.gdtr:
  dw 4095
  dq 0

.idtr:
  dw 4095
  dq 0

.GDT equ 4096 * 0
.LDT equ 4096 * 1
.TLS equ 4096 * 2

%endif  ; DESCRIPTOR_TABLES_ASM_

%ifndef DESCRIPTOR_TABLES_ASM_
%define DESCRIPTOR_TABLES_ASM_

descriptor_tables:
.init:
  ; make gdt
  mov edi, [global_page_addr]
  mov esi, edi
  mov [.gdtr + 2], edi
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
  lea edx, [esi + 4096]
  mov [esi + 26], dx
  shr edx, 16
  mov [esi + 28], dl
  mov byte [esi + 29], 0x92
  mov [esi + 31], dh
  lgdt [.gdtr]
  mov ax, 3 * 8
  mov fs, ax
  mov gs, ax
  mov dword [esi + 4096], 0x00100020
  ret

.gdtr:
  dw 4095
  dq 0

%endif  ; DESCRIPTOR_TABLES_ASM_

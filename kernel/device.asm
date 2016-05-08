%ifndef DEVICE_ASM_
%define DEVICE_ASM_

; structure
;   device = {tuple, dependes on the flag}, extra-field = flag: 8 bit
;   tuple = {octet-buffer x 3(buffer, ready-bitmap, modified-bitmap)}
;   flag: 0 = port-mapped I/O
;           device = {buffer, dep}
;           dep = {port-number, device-number, type}

%include "ide.asm"

device:
.init:
  call table.new
  mov [.table], eax
  xor rdx, rdx
  call ide.init
  mov [.num.of.device], rdx
  call table.begin
  mov esi, eax
  xor rdi, rdi
  mov di, [0x0800]
.init.1:
  mov eax, esi
  call table.iterator.isend
  jnc .init.3
  call table.iterator.deref
  cmp edi, 1
  je .init.hdd
  cmp edi, 2
  je .init.cd
.init.2:
  mov eax, esi
  call table.iterator.succ
  jmp .init.1
.init.3:
  mov eax, esi
  call objects.unref
  ret
.init.hdd:
  ; find flag == 0 && type == ATA
  mov ebp, edx
  xor rax, rax
  mov eax, edx
  shl rax, 4
  cmp byte [rax + object.padding], 0
  jne .init.2
  xor rcx, rcx
  mov ecx, [rax + object.content + 4]
  shl rcx, 4
  cmp dword [rcx + object.internal.content + 8], .ata
  jne .init.2
  mov [.boot], ebp
  jmp .init.3
.init.cd:
  ; find flag == 0 && type == ATAPI
  mov ebp, edx
  xor rax, rax
  mov eax, edx
  shl rax, 4
  cmp byte [rax + object.padding], 0
  jne .init.2
  xor rcx, rcx
  mov ecx, [rax + object.content + 4]
  shl rcx, 4
  cmp dword [rcx + object.internal.content + 8], .atapi
  jne .init.2
  ; is it a CD?
  mov eax, [rcx + object.internal.content]
  mov edx, [rcx + object.internal.content + 4]
  call ide.iscd
  jc .init.2
  call ide.cd.issupportsdiskpresent
  jc .init.cd.2
  call ide.cd.isdiskpresent
  jc .init.2
  mov [.boot], ebp
  jmp .init.3
.init.cd.2:
  call ide.cd.trytoread
  jc .init.2
  mov [.boot], ebp
  jmp .init.3

.new:
  push rdx
  call objects.new.chunk
  mov rdx, rax
  call octet_buffer.new
  mov [rdx + object.internal.content], eax
  call octet_buffer.new
  mov [rdx + object.internal.content + 4], eax
  call octet_buffer.new
  mov [rdx + object.internal.content + 8], eax
  shr rdx, 4
  call objects.new.raw
  mov byte [rax + object.class], object.device
  mov [rax + object.content], edx
  shr rax, 4
  pop rdx
  ret

.dispose.raw:
  push rax
  push rdx
  xor rdx, rdx
  mov edx, [rax + object.content]
  shl rdx, 4
  mov eax, [rdx + object.internal.content]
  call objects.unref
  mov eax, [rdx + object.internal.content + 4]
  call objects.unref
  mov eax, [rdx + object.internal.content + 8]
  call objects.unref
  pop rdx
  pop rax
  ret

.table: dd 0
.num.of.device: dq 0
.boot: dd 0

.ata   equ 0
.atapi equ 1


%endif  ; DEVICE_ASM_

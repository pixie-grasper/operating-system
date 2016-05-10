%ifndef DEVICE_ASM_
%define DEVICE_ASM_

; structure
;   device = {tuple, dependes on the flag}, extra-field = flag: 8 bit
;   tuple = {octet-buffer, reserved, reserved}
;   flag: 0 = port-mapped I/O
;           device = {tuple, dep}
;           dep = {port-number, device-number, reserved}, extra-field = type: 8 bit
;           type: 0 = ATA, 1 = ATAPI

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
  cmp byte [rcx + object.internal.padding], .ata
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
  cmp byte [rcx + object.internal.padding], .atapi
  jne .init.2
  ; is it a Disk Device?
  mov eax, [rcx + object.internal.content]
  mov edx, [rcx + object.internal.content + 4]
  call ide.isdiskdevice
  jc .init.2
  ; is a El-Torito Bootable Disk?
  mov eax, ebp
  mov edx, 0x11 * 2048
  call .newindex
  test rax, rax
  jz .init.2
  mov rdx, rax
  mov rdi, .eltorito.magic
  mov ecx, 32 / 8
.init.cd.1:
  mov rbx, [rdx]
  cmp rbx, [rdi]
  jne .init.2
  add rdx, 8
  add rdi, 8
  dec ecx
  jnz .init.cd.1
  mov edx, [rax + 0x47]  ; LBA of the boot catalog
  shl edx, 11  ; 1 LBA = 2048 bytes
  mov eax, ebp
  call .newindex
  test rax, rax
  jz .init.2
  cmp dword [rax], 1
  jne .init.2
  cmp word [rax + 0x1e], 0xaa55
  jne .init.2
  cmp byte [rax + 0x20], 0x88
  jne .init.2
  mov [.boot], ebp
  jmp .init.3

.new:
  push rcx
  push rdx
  call objects.new.chunk
  mov rcx, rax
  shr rcx, 4
  call objects.new.chunk
  mov rdx, rax
  call octet_buffer.new
  mov [rdx + object.internal.content], eax
  shr rdx, 4
  call objects.new.raw
  mov byte [rax + object.class], object.device
  mov [rax + object.content], edx
  mov [rax + object.content + 4], ecx
  shr rax, 4
  pop rdx
  pop rcx
  ret

.dispose.raw:
  push rax
  push rdx
  xor rdx, rdx
  mov edx, [rax + object.content]
  shl rdx, 4
  mov eax, [rdx + object.internal.content]
  call objects.unref
  xor rdx, rdx
  mov edx, [rax + object.content + 4]
  shl rdx, 4
  mov rax, rdx
  call objects.dispose.raw
  pop rdx
  pop rax
  ret

  ; in: a = device id
  ; in: d = address on the drive (byte-wised)
  ; out: a = address to the loaded buffer | nil
.newindex:
  push rbx
  push rcx
  push rdx
  push rsi
  push rdi
  push rbp
  xor rcx, rcx
  mov ecx, eax
  shl rcx, 4
  xor rsi, rsi
  mov esi, [rcx + object.content]
  shl rsi, 4
  mov eax, [rsi + object.internal.content]
  call octet_buffer.index
  test rax, rax
  jnz .newindex.end
  mov rdi, rdx
  cmp byte [rcx + object.padding], .pmio
  je .newindex.pmio
  jmp .newindex.failed
.newindex.pmio:
  xor rbp, rbp
  mov ebp, [rcx + object.content + 4]
  shl rbp, 4
  cmp byte [rbp + object.internal.padding], .ata
  je .newindex.pmio.ata
  cmp byte [rbp + object.internal.padding], .atapi
  je .newindex.pmio.atapi
  jmp .newindex.failed
.newindex.pmio.ata:
  ; TODO: implement
  jmp .newindex.failed
.newindex.pmio.atapi:
  mov eax, [rsi + object.internal.content]
  and rdx, ~0x0fff
  call octet_buffer.newindex
  mov rbx, rdx
  shr rbx, 11
  mov ecx, [rbp + object.internal.content]
  mov edx, [rbp + object.internal.content + 4]
  call ide.read.atapi
  test rax, rax
  jz .newindex.failed
  and rdi, 0x0fff
  add rax, rdi
  jmp .newindex.end
.newindex.failed:
  xor rax, rax
.newindex.end:
  pop rbp
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  ret

.table: dd 0
.num.of.device: dq 0
.boot: dd 0

.pmio equ 0

.ata   equ 0
.atapi equ 1

  align 8
.eltorito.magic: db 0x00, 'CD001', 0x01, 'EL TORITO SPECIFICATION', 0x00, 0x00

%endif  ; DEVICE_ASM_

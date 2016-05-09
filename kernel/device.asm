%ifndef DEVICE_ASM_
%define DEVICE_ASM_

; structure
;   device = {tuple, dependes on the flag}, extra-field = flag: 8 bit
;   tuple = {octet-buffer x 3(buffer, ready-bitmap, modified-bitmap)}
;   flag: 0 = port-mapped I/O
;           device = {buffer, dep}
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
  mov edx, 0x11 * 4
  call .read
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
  mov edx, [rax + 0x47]  ; boot catalog
  shl edx, 2
  mov eax, ebp
  call .read
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

  ; in: a = device id
  ; in: d = virtual LBA (512 bytes / block)
  ; out: a = address to the loaded buffer | nil
.read:
  push rbx
  push rcx
  push rdx
  push rsi
  push rdi
  push rbp
  push r8
  push r9
  push r10
  xor r8, r8
  mov r8d, eax
  shl r8, 4
  xor r9, r9
  mov r9d, [r8 + object.content]
  shl r9, 4
  mov eax, [r9 + object.internal.content + 4]
  mov r10, rdx
  shr rdx, 3
  and rdx, ~0x03
  call octet_buffer.index
  test rax, rax
  jz .read.1
  mov rcx, r10
  and ecx, 0x1f
  mov edx, 1
  shl edx, cl
  test edx, [rax]
  jz .read.1
  mov eax, [r9 + object.internal.content]
  mov rdx, r10
  shl rdx, 9
  call octet_buffer.index
  jmp .read.end
.read.1:
  cmp byte [r8 + object.padding], 0
  je .read.ide
  jmp .read.failed
.read.ide:
  xor rbp, rbp
  mov ebp, [r8 + object.content + 4]
  shl rbp, 4
  cmp byte [rbp + object.internal.padding], .ata
  je .read.ide.ata
  cmp byte [rbp + object.internal.padding], .atapi
  je .read.ide.atapi
  jmp .read.failed
.read.ide.ata:
  ; TODO: implement
  jmp .read.failed
.read.ide.atapi:
  mov eax, [r9 + object.internal.content]
  mov rdx, r10
  shl rdx, 9
  call octet_buffer.newindex
  mov ecx, [rbp + object.internal.content]
  mov edx, [rbp + object.internal.content + 4]
  mov rbx, r10
  shr rbx, 2  ; 512/2048 address convert
  call ide.read.atapi
  mov rdi, rax
  mov eax, [r9 + object.internal.content + 4]
  mov rdx, r10
  shr rdx, 3
  and rdx, ~0x03
  call octet_buffer.newindex
  mov rsi, rax
  mov rcx, r10
  and ecx, 0x1c
  mov edx, 0x0f
  shl edx, cl
.read.ide.atapi.1:
  mov eax, [rsi]
  mov ecx, eax
  or ecx, edx
  lock cmpxchg [rsi], ecx
  jne .read.ide.atapi.1
  mov rax, rdi
  jmp .read.end
.read.failed:
  xor rax, rax
.read.end:
  pop r10
  pop r9
  pop r8
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

.ata   equ 0
.atapi equ 1

  align 8
.eltorito.magic: db 0x00, 'CD001', 0x01, 'EL TORITO SPECIFICATION', 0x00, 0x00

%endif  ; DEVICE_ASM_

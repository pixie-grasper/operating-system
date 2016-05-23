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
  stid [.table], a
  xor rdx, rdx
  call ide.init
  mov [.num.of.device], rdx
  call table.begin
  movid si, a
  xor rdi, rdi
  mov di, [0x0800]
.init.1:
  movid a, si
  call table.iterator.isend
  jnc .init.3
  call table.iterator.deref
  cmp edi, 1
  je .init.hdd
  cmp edi, 2
  je .init.cd
.init.2:
  movid a, si
  call table.iterator.succ
  jmp .init.1
.init.3:
  movid a, si
  call objects.unref
  ret
.init.hdd:
  ; find flag == 0 && type == ATA
  movid bp, d
  addr_from_id a, d
  cmp byte [rax + object.padding], 0
  jne .init.2
  ldaddr c, [rax + object.content + word.size]
  cmp byte [rcx + object.internal.padding], .ata
  jne .init.2
  stid [.boot], bp
  jmp .init.3
.init.cd:
  ; find flag == 0 && type == ATAPI
  movid bp, d
  addr_from_id a, d
  cmp byte [rax + object.padding], 0
  jne .init.2
  ldaddr c, [rax + object.content + word.size]
  cmp byte [rcx + object.internal.padding], .atapi
  jne .init.2
  ; is it a Disk Device?
  mov eax, [rcx + object.internal.content]
  mov edx, [rcx + object.internal.content + word.size]
  call ide.isdiskdevice
  jc .init.2
  ; is a El-Torito Bootable Disk?
  movid a, bp
  mov edx, 0x11 * 2048
  call .index
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
  movid a, bp
  call .index
  test rax, rax
  jz .init.2
  cmp dword [rax], 1
  jne .init.2
  cmp word [rax + 0x1e], 0xaa55
  jne .init.2
  cmp byte [rax + 0x20], 0x88
  jne .init.2
  stid [.boot], bp
  jmp .init.3

.new:
  pushs c, d
  call objects.new.chunk
  id_from_addr a
  movid c, a
  call objects.new.chunk
  mov rdx, rax
  call octet_buffer.new
  stid [rdx + object.internal.content], a
  id_from_addr d
  call objects.new.raw
  mov byte [rax + object.class], object.device
  stid [rax + object.content], d
  stid [rax + object.content + word.size], c
  id_from_addr a
  pops c, d
  ret

.dispose.raw:
  pushs a, c, d
  mov rcx, rax
  ldaddr d, [rax + object.content]
  ldid a, [rdx + object.internal.content]
  call objects.unref
  ldaddr d, [rcx + object.content + word.size]
  mov rax, rdx
  call objects.dispose.raw
  pops a, c, d
  ret

  ; in: a = device id
  ; in: d = address on the drive (byte-wised)
  ; out: a = address to the loaded buffer | nil
.index:
  pushs b, c, d, si, di, bp
  addr_from_id c, a
  ldaddr si, [rcx + object.content]
  ldid a, [rsi + object.internal.content]
  call octet_buffer.index
  test rax, rax
  jnz .index.end
  mov rdi, rdx
  cmp byte [rcx + object.padding], .pmio
  je .index.pmio
  jmp .index.failed
.index.pmio:
  ldaddr bp, [rcx + object.content + word.size]
  cmp byte [rbp + object.internal.padding], .ata
  je .index.pmio.ata
  cmp byte [rbp + object.internal.padding], .atapi
  je .index.pmio.atapi
  jmp .index.failed
.index.pmio.ata:
  ; TODO: implement
  jmp .index.failed
.index.pmio.atapi:
  ldid a, [rsi + object.internal.content]
  and rdx, ~0x0fff
  call octet_buffer.newindex
  mov rbx, rdx
  shr rbx, 11
  mov ecx, [rbp + object.internal.content]
  mov edx, [rbp + object.internal.content + word.size]
  call ide.read.atapi
  test rax, rax
  jz .index.failed
  and rdi, 0x0fff
  add rax, rdi
  jmp .index.end
.index.failed:
  ldnil a
.index.end:
  pops b, c, d, si, di, bp
  ret

  ; in: a = device id
  ; in: c = length (byte-wised)
  ; in: d = address on the drive (byte-wised)
  ; in: di = address to copy
.index.cp:
  pushs a, b, c, d, si, di
  mov rsi, rdx
  and rsi, 0x0fff
  add rsi, rcx
  test rsi, 0x1000
  jnz .index.cp.4
  call .index
  test rax, rax
  jz .index.cp.failed
.index.cp.1:
  cmp rcx, 4
  jb .index.cp.2
  mov edx, [rax]
  mov [rdi], edx
  add rax, 4
  add rdi, 4
  sub rcx, 4
  jmp .index.cp.1
.index.cp.2:
  test rcx, rcx
  jz .index.cp.end
.index.cp.3:
  mov dl, [rax]
  mov [rdi], dl
  inc rax
  inc rdi
  dec rcx
  jnz .index.cp.3
  jmp .index.cp.end
.index.cp.4:
  movid si, a
  call .index
  test rax, rax
  jz .index.cp.failed
  mov rbx, rax
  movid a, si
  add rdx, rcx
  dec rdx
  call .index
  test rax, rax
  jz .index.cp.failed
.index.cp.5:
  test rbx, 0x03
  jz .index.cp.6
  mov dl, [rbx]
  mov [rdi], dl
  inc rbx
  inc rdi
  dec rcx
  jmp .index.cp.5
.index.cp.6:
  test rbx, 0x0fff
  jz .index.cp.7
  mov edx, [rbx]
  mov [rdi], edx
  add rbx, 4
  add rdi, 4
  sub rcx, 4
  jmp .index.cp.6
.index.cp.7:
  cmp rcx, 4
  jb .index.cp.8
  mov edx, [rax]
  mov [rdi], edx
  add rax, 4
  add rdi, 4
  sub rcx, 4
  jmp .index.cp.7
.index.cp.8:
  test rcx, rcx
  jz .index.cp.end
.index.cp.9:
  mov dl, [rax]
  mov [rdi], dl
  inc rax
  inc rdi
  dec rcx
  jnz .index.cp.9
  jmp .index.cp.end
.index.cp.failed:
  pops a, b, c, d, si, di
  jmp return.false
.index.cp.end:
  pops a, b, c, d, si, di
  jmp return.true

.table: did 0
.num.of.device: dq 0
.boot: did 0

.pmio equ 0

.ata   equ 0
.atapi equ 1

  align 8
.eltorito.magic: db 0x00, 'CD001', 0x01, 'EL TORITO SPECIFICATION', 0x00, 0x00

%endif  ; DEVICE_ASM_

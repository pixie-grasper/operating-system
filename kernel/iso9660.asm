%ifndef ISO9660_ASM_
%define ISO9660_ASM_

; structure
;   iterator = {property, status}
;   property = {device, current deref | nil, reserved}
;   status = {LBA of the directory record, current pos, length of the record}
;   file-status = {device, file-size, LBA of the begins file}

iso9660:
.iterator.dispose.raw:
  push rax
  push rcx
  push rdx
  xor rdx, rdx
  mov rcx, rax
  mov edx, [rax + object.content]
  shl rdx, 4
  mov eax, [rdx + object.internal.content + 4]
  call objects.unref
  mov rax, rdx
  call objects.dispose.raw
  xor rax, rax
  mov eax, [rcx + object.content + 4]
  shl rax, 4
  call objects.dispose.raw
  pop rdx
  pop rcx
  pop rax
  ret

.file.status.dispose.raw:
  push rax
  mov eax, [rax + object.internal.content]
  call objects.unref
  pop rax
  ret

  ; in: a = device
  ; out: a = iterator of the root | nil
.begin:
  push rcx
  push rdx
  push rsi
  mov esi, eax
  mov edx, 2048 * 16
.begin.1:
  mov eax, esi
  call device.index
  test rax, rax
  jz .begin.3
  cmp byte [rax], 1  ; finding primary volume descriptor
  je .begin.2
  cmp byte [rax], 0xff
  mov rax, 0
  je .begin.3
  add edx, 2048
  jmp .begin.1
.begin.2:
  ; now, the root directory record starts at rax + 156
  mov ecx, [rax + 156 + 2]  ; location
  mov edx, [rax + 156 + 10]  ; length
  call objects.new.chunk
  mov [rax + object.internal.content], ecx
  mov [rax + object.internal.content + 8], edx
  shr rax, 4
  mov ecx, eax
  call objects.new.chunk
  mov [rax + object.internal.content], esi
  shr rax, 4
  mov esi, eax
  call objects.new.raw
  mov [rax + object.content], esi
  mov [rax + object.content + 4], ecx
  shr rax, 4
.begin.3:
  pop rsi
  pop rdx
  pop rcx
  ret

  ; in: a = iterator
.iterator.succ:
  push rax
  push rbx
  push rcx
  push rdx
  push rsi
  xor rsi, rsi
  mov esi, eax
  shl rsi, 4
  xor rcx, rcx
  mov ecx, [rsi + object.content + 4]
  shl rcx, 4
  xor rbx, rbx
  mov ebx, [rcx + object.internal.content + 4]
  cmp ebx, [rcx + object.internal.content + 8]
  jae .iterator.succ.1
  xor rdx, rdx
  mov edx, [rcx + object.internal.content]
  shl rdx, 11
  xor rax, rax
  mov eax, [rcx + object.internal.content + 4]
  add rdx, rax
  xor rax, rax
  mov eax, [rsi + object.content]
  shl rax, 4
  mov eax, [rax + object.internal.content]
  call device.index
  mov esi, [rax]
  and esi, 0xff
  add [rcx + object.internal.content + 4], esi
  xor rdx, rdx
  mov edx, [rsi + object.content]
  shl rdx, 4
  mov eax, [rdx + object.internal.content + 4]
  call objects.unref
  xor eax, eax
  mov [rdx + object.internal.content + 4], eax
.iterator.succ.1:
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  pop rax
  ret

  ; in: a = iterator
.iterator.isrefsfile:
  push rax
  push rbx
  push rcx
  push rdx
  push rsi
  xor rsi, rsi
  mov esi, eax
  shl rsi, 4
  xor rcx, rcx
  mov ecx, [rsi + object.content]
  shl rcx, 4
  mov eax, [rcx + object.internal.content]
  xor rbx, rbx
  mov ebx, [rsi + object.content + 4]
  shl rbx, 4
  xor rdx, rdx
  mov edx, [rbx + object.internal.content]
  shl rdx, 11
  xor rcx, rcx
  mov ecx, [rbx + object.internal.content + 4]
  add rdx, rcx
  add rdx, 25
  call device.index
  mov dl, [rax]
  test dl, 0x02
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  pop rax
  jz return.true
  jmp return.false

  ; in: a = iterator
.iterator.isend:
  push rax
  push rcx
  push rdx
  xor rdx, rdx
  mov edx, eax
  shl rdx, 4
  xor rcx, rcx
  mov ecx, [rdx + object.content + 4]
  shl rcx, 4
  mov eax, [rcx + object.internal.content + 4]
  cmp eax, [rcx + object.internal.content + 8]
  pop rdx
  pop rcx
  pop rax
  jae return.true
  jmp return.false

%endif  ; ISO9660_ASM_

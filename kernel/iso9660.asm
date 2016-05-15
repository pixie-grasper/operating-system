%ifndef ISO9660_ASM_
%define ISO9660_ASM_

; structure
;   iterator = {property, status}
;   property = {device, current deref | nil, reserved}
;   status = {LBA of the directory record, current pos, length of the record}
;   file.status = {device, status}

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
  mov edx, [rax + object.content + 4]
  mov eax, [rax + object.content]
  call objects.unref
  xor rax, rax
  mov eax, edx
  shl rax, 4
  call objects.dispose.raw
  pop rax
  ret

  ; in: a = device
  ; out: a = iterator id of the root | nil
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
  mov byte [rax + object.class], object.iso9660.iterator
  mov [rax + object.content], esi
  mov [rax + object.content + 4], ecx
  shr rax, 4
.begin.3:
  pop rsi
  pop rdx
  pop rcx
  ret

  ; in: a = iterator id
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

  ; in: a = iterator id
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

  ; in: a = iterator id
  ; out: a = octet-buffer id indicates a name of the refed object
.iterator.getname:
  push rbx
  push rcx
  push rdx
  push rsi
  push rdi
  push rbp
  xor rsi, rsi
  mov esi, eax
  shl rsi, 4
  xor rbp, rbp
  mov ebp, [rsi + object.content]
  shl rbp, 4
  mov eax, [rbp + object.internal.content]
  mov ebp, eax
  xor rbx, rbx
  mov ebx, [rsi + object.content + 4]
  shl rbx, 4
  xor rdx, rdx
  mov edx, [rbx + object.internal.content]
  shl rdx, 11
  xor rcx, rcx
  mov ecx, [rbx + object.internal.content + 4]
  add rdx, rcx
  mov rbx, rdx
  call device.index
  xor rcx, rcx
  mov cl, [rax]
  call octet_buffer.new
  mov esi, eax
  xor rdx, rdx
  call octet_buffer.newindex
  mov rdi, rax
  mov rdx, rbx
  mov eax, ebp
  call device.index.cp
  mov rbx, rdi
  add rbx, 33
  xor rcx, rcx
  xor rdx, rdx
  mov cl, [rdi + 32]
  mov edx, ecx
  add ecx, 0x03
  shr ecx, 2
  jz .iterator.getname.2
.iterator.getname.1:
  mov eax, [rbx]
  mov [rdi], eax
  add rbx, 4
  add rdi, 4
  dec ecx
  jnz .iterator.getname.1
.iterator.getname.2:
  xor rbx, rbx
  mov ebx, edx
  add ebx, 3
  and ebx, ~3
  sub rdi, rbx
  mov [rdi + rdx], ecx
  mov eax, esi
  pop rbp
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  ret

  ; in: a = iterator id refs directory
  ; out: a = refed iterator id | nil
.iterator.deref.directory:
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
  mov eax, [rcx + object.internal.content + 4]
  test eax, eax
  jnz .iterator.deref.directory.end.2
  mov eax, [rcx + object.internal.content]
  call objects.ref
  xor rbx, rbx
  mov ebx, [rsi + object.content + 4]
  shl rbx, 4
  xor rdx, rdx
  mov edx, [rbx + object.internal.content]
  shl rdx, 11
  xor rcx, rcx
  mov ecx, [rbx + object.internal.content + 4]
  add rdx, rcx
  mov rcx, 28
  sub rsp, 32
  mov rdi, rsp
  mov esi, eax
  call device.index.cp
  jc .iterator.deref.directory.failed
  test byte [rdi + 25], 0x02  ; directory?
  jz .iterator.deref.directory.failed
  mov ecx, [rdi + 2]  ; location
  mov edx, [rdi + 10]  ; length
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
  mov byte [rax + object.class], object.iso9660.iterator
  mov [rax + object.content], esi
  mov [rax + object.content + 4], ecx
  shr rax, 4
  jmp .iterator.deref.directory.end
.iterator.deref.directory.failed:
  xor rax, rax
.iterator.deref.directory.end:
  add rsp, 32
.iterator.deref.directory.end.2:
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  ret

  ; in: a = iterator id refs file
  ; out: a = file id
.iterator.deref.file:
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
  mov eax, [rcx + object.internal.content + 4]
  test eax, eax
  jnz .iterator.deref.file.end.2
  mov eax, [rcx + object.internal.content]
  call objects.ref
  xor rbx, rbx
  mov ebx, [rsi + object.content + 4]
  shl rbx, 4
  xor rdx, rdx
  mov edx, [rbx + object.internal.content]
  shl rdx, 11
  xor rcx, rcx
  mov ecx, [rbx + object.internal.content + 4]
  add rdx, rcx
  mov rcx, 28
  sub rsp, 32
  mov rdi, rsp
  mov esi, eax
  call device.index.cp
  jc .iterator.deref.file.failed
  test byte [rdi + 25], 0x02  ; file?
  jnz .iterator.deref.file.failed
  call objects.new.chunk
  mov [rax + object.internal.content], esi
  mov qword [rax + object.internal.content + 4], .file.index
  shr rax, 4
  mov edx, eax
  call file.new
  call file.set.info
  jmp .iterator.deref.file.end
.iterator.deref.file.failed:
  xor rax, rax
.iterator.deref.file.end:
  add rsp, 32
.iterator.deref.file.end.2:
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  ret

  ; in: a = iterator id
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

  ; in: a = page address
  ; in: c = file.status id
  ; in: d = file offset
  ; TODO: implement
.file.index:
  ret

%endif  ; ISO9660_ASM_

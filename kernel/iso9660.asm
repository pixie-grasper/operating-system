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
  mov rcx, rax
  ldaddr d, [rax + object.content]
  ldid a, [rdx + object.internal.content + word.size]
  call objects.unref
  mov rax, rdx
  call objects.dispose.raw
  ldaddr a, [rcx + object.content + word.size]
  call objects.dispose.raw
  pop rdx
  pop rcx
  pop rax
  ret

.file.status.dispose.raw:
  push rax
  push rdx
  ldaddr d, [rax + object.content + word.size]
  ldid a, [rax + object.content]
  call objects.unref
  mov rax, rdx
  call objects.dispose.raw
  pop rdx
  pop rax
  ret

  ; in: a = device
  ; out: a = iterator id of the root | nil
.begin:
  push rcx
  push rdx
  push rsi
  movid si, a
  mov edx, 2048 * 16
.begin.1:
  movid a, si
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
  mov [rax + object.internal.content + word.size * 2], edx
  id_from_addr a
  movid c, a
  call objects.new.chunk
  stid [rax + object.internal.content], si
  id_from_addr a
  movid si, a
  call objects.new.raw
  mov byte [rax + object.class], object.iso9660.iterator
  stid [rax + object.content], si
  stid [rax + object.content + word.size], c
  id_from_addr a
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
  addr_from_id si, a
  ldaddr c, [rsi + object.content + word.size]
  xor rbx, rbx
  mov ebx, [rcx + object.internal.content + word.size]
  cmp ebx, [rcx + object.internal.content + word.size * 2]
  jae .iterator.succ.1
  xor rdx, rdx
  mov edx, [rcx + object.internal.content]
  shl rdx, 11
  xor rax, rax
  mov eax, [rcx + object.internal.content + word.size]
  add rdx, rax
  ldaddr a, [rsi + object.content]
  ldid a, [rax + object.internal.content]
  call device.index
  xor rsi, rsi
  mov sil, [rax]
  add [rcx + object.internal.content + word.size], esi
  ldaddr d, [rsi + object.content]
  ldid a, [rdx + object.internal.content + word.size]
  call objects.unref
  ldnil a
  stid [rdx + object.internal.content + word.size], a
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
  addr_from_id si, a
  ldaddr c, [rsi + object.content]
  ldid a, [rcx + object.internal.content]
  ldaddr b, [rsi + object.content + word.size]
  xor rdx, rdx
  mov edx, [rbx + object.internal.content]
  shl rdx, 11
  xor rcx, rcx
  mov ecx, [rbx + object.internal.content + word.size]
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
  addr_from_id si, a
  ldaddr bp, [rsi + object.content]
  ldid a, [rbp + object.internal.content]
  movid bp, a
  ldaddr b, [rsi + object.content + word.size]
  xor rdx, rdx
  mov edx, [rbx + object.internal.content]
  shl rdx, 11
  xor rcx, rcx
  mov ecx, [rbx + object.internal.content + word.size]
  add rdx, rcx
  mov rbx, rdx
  call device.index
  xor rcx, rcx
  mov cl, [rax]
  call octet_buffer.new
  movid si, a
  xor rdx, rdx
  call octet_buffer.newindex
  mov rdi, rax
  mov rdx, rbx
  movid a, bp
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
  movid a, si
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
  addr_from_id si, a
  ldaddr c, [rsi + object.content]
  ldid a, [rcx + object.internal.content + word.size]
  testid a
  jnz .iterator.deref.directory.end.2
  ldid a, [rcx + object.internal.content]
  call objects.ref
  ldaddr b, [rsi + object.content + word.size]
  xor rdx, rdx
  mov edx, [rbx + object.internal.content]
  shl rdx, 11
  xor rcx, rcx
  mov ecx, [rbx + object.internal.content + word.size]
  add rdx, rcx
  mov rcx, 28
  sub rsp, 32
  mov rdi, rsp
  movid si, a
  call device.index.cp
  jc .iterator.deref.directory.failed
  test byte [rdi + 25], 0x02  ; directory?
  jz .iterator.deref.directory.failed
  mov ecx, [rdi + 2]  ; location
  mov edx, [rdi + 10]  ; length
  call objects.new.chunk
  mov [rax + object.internal.content], ecx
  mov [rax + object.internal.content + word.size * 2], edx
  id_from_addr a
  movid c, a
  call objects.new.chunk
  stid [rax + object.internal.content], si
  id_from_addr a
  movid si, a
  call objects.new.raw
  mov byte [rax + object.class], object.iso9660.iterator
  stid [rax + object.content], si
  stid [rax + object.content + word.size], c
  id_from_addr a
  jmp .iterator.deref.directory.end
.iterator.deref.directory.failed:
  ldnil a
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
  addr_from_id si, a
  ldaddr c, [rsi + object.content]
  ldid a, [rcx + object.internal.content + word.size]
  testid a
  jnz .iterator.deref.file.end.2
  ldid a, [rcx + object.internal.content]
  call objects.ref
  ldaddr b, [rsi + object.content + word.size]
  xor rdx, rdx
  mov edx, [rbx + object.internal.content]
  shl rdx, 11
  xor rcx, rcx
  mov ecx, [rbx + object.internal.content + 4]
  add rdx, rcx
  mov rcx, 28
  sub rsp, 32
  mov rdi, rsp
  movid si, a
  call device.index.cp
  jc .iterator.deref.file.failed
  test byte [rdi + 25], 0x02  ; file?
  jnz .iterator.deref.file.failed
  call objects.new.chunk
  stid [rax + object.internal.content], si
  mov qword [rax + object.internal.content + 4], .file.index
  id_from_addr a
  movid d, a
  call file.new
  call file.set.info
  jmp .iterator.deref.file.end
.iterator.deref.file.failed:
  ldnil a
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
  addr_from_id d, a
  ldaddr c, [rdx + object.content + word.size]
  mov eax, [rcx + object.internal.content + word.size]
  cmp eax, [rcx + object.internal.content + word.size * 2]
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

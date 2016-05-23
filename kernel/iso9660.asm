%ifndef ISO9660_ASM_
%define ISO9660_ASM_

; structure
;   iterator = {property, status}
;   property = {device, current deref | nil, reserved}
;   status = {LBA of the directory record, current pos, length of the record}
;   file.info = {file.status, [address of the loader]:64}
;   file.status = {device, status}

iso9660:
.iterator.dispose.raw:
  pushs a, c, d
  mov rcx, rax
  ldaddr d, [rax + object.content]
  ldid a, [rdx + object.internal.content + word.size]
  call objects.unref
  mov rax, rdx
  call objects.dispose.raw
  ldaddr a, [rcx + object.content + word.size]
  call objects.dispose.raw
  pops a, c, d
  ret

.file.status.dispose.raw:
  pushs a, d
  ldaddr d, [rax + object.content + word.size]
  ldid a, [rax + object.content]
  call objects.unref
  mov rax, rdx
  call objects.dispose.raw
  pops a, d
  ret

  ; in: a = device
  ; out: a = iterator id of the root | nil
.begin:
  pushs c, d, si
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
  pops c, d, si
  ret

  ; in: a = iterator id
.iterator.succ:
  pushs a, b, c, d, si
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
  pops a, b, c, d, si
  ret

  ; in: a = iterator id
.iterator.isrefsfile:
  pushs a, b, c, d, si
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
  pops a, b, c, d, si
  jz return.true
  jmp return.false

  ; in: a = iterator id
  ; out: a = octet-buffer id indicates a name of the refed object
  ; out: d = name.length
.iterator.getname:
  pushs b, c, si, di, bp
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
  mov cl, [rdi + 32]
  mov rdx, rcx
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
  pops b, c, si, di, bp
  ret

  ; in: a = iterator id refs directory
  ; out: a = refed iterator id | nil
.iterator.deref.directory:
  pushs b, c, d, si
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
  pops b, c, d, si
  ret

  ; in: a = iterator id refs file
  ; out: a = file id
.iterator.deref.file:
  pushs b, c, d, si, di
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
  mov ecx, [rbx + object.internal.content + word.size]
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
  mov ecx, [rbx + object.internal.content]
  mov [rax + object.internal.content], ecx
  mov ecx, [rbx + object.internal.content + word.size]
  mov [rax + object.internal.content + word.size], ecx
  mov ecx, [rbx + object.internal.content + word.size * 2]
  mov [rax + object.internal.content + word.size * 2], ecx
  id_from_addr a
  movid c, a
  call objects.new.raw
  mov byte [rax + object.content], object.iso9660.file.status
  stid [rax + object.content], si
  stid [rax + object.content + word.size], c
  id_from_addr a
  movid c, a
  call objects.new.chunk
  stid [rax + object.internal.content], c
  mov qword [rax + object.internal.content + word.size], .file.index
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
  pops b, c, d, si, di
  ret

  ; in: a = iterator id
.iterator.isend:
  pushs a, c, d
  addr_from_id d, a
  ldaddr c, [rdx + object.content + word.size]
  mov eax, [rcx + object.internal.content + word.size]
  cmp eax, [rcx + object.internal.content + word.size * 2]
  pops a, c, d
  jae return.true
  jmp return.false

  ; in: a = page address
  ; in: c = file.status id
  ; in: d = file offset
  ; out: a = mapped address
.file.index:
  pushs b, c, d, si, di, bp
  mov rsi, rax
  addr_from_id b, c
  mov rbp, rdx
  ldaddr a, [rbx + object.content + word.size]
  xor rdx, rdx
  mov edx, [rax + object.internal.content]
  shl rdx, 11
  xor rcx, rcx
  mov ecx, [rax + object.internal.content + word.size]
  add rdx, rcx
  mov rcx, 8
  sub rsp, 8
  mov rdi, rsp
  ldid a, [rbx + object.content]
  call device.index.cp
  xor rdx, rdx
  mov edx, [rdi + 2]
  add rsp, 8
  shl rdx, 11
  add rdx, rbp
  and rdx, ~0x0fff
  and rbp, 0x0fff
  mov rdi, rsi
  mov rcx, 4096
  call device.index.cp
  mov rax, rdi
  add rax, rbp
  pops b, c, d, si, di, bp
  ret

%endif  ; ISO9660_ASM_

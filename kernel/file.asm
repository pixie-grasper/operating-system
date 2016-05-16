%ifndef FILE_ASM_
%define FILE_ASM_

; structure
;   file = {octet-buffer, info | nil}
;   info = {status, [address of the loader]:64}

file:
.new:
  call .new.raw
  id_from_addr a
  ret

.new.raw:
  push rdx
  call octet_buffer.new
  movid d, a
  call objects.new.raw
  mov byte [rax + object.class], object.file
  stid [rax + object.content], d
  pop rdx
  ret

.dispose.raw:
  push rax
  push rcx
  push rdx
  addr_from_id d, a
  ldid a, [rdx + object.content]
  call objects.unref
  ldaddr c, [rdx + object.content + word.size]
  testaddr c
  jz .dispose.raw.1
  ldid a, [rcx + object.internal.content]
  call objects.unref
  mov rax, rcx
  call objects.dispose.raw
.dispose.raw.1:
  pop rdx
  pop rcx
  pop rax
  ret

  ; in: a = file id
  ; in: d = info id
.set.info:
  push rax
  push rcx
  addr_from_id c, a
  ldaddr a, [rcx + object.content + word.size]
  testaddr a
  jz .set.info.1
  ldid a, [rax + object.internal.content]
  call objects.unref
.set.info.1:
  stid [rcx + object.content + word.size], d
  pop rcx
  pop rax
  ret

  ; in: a = file id
  ; in: d = offset
  ; out: a = nil | mapped address
.index:
  push rcx
  push rdx
  push rsi
  push rdi
  addr_from_id di, a
  ldid a, [rdi + object.content]
  call octet_buffer.index
  test rax, rax
  jnz .index.end
  ldaddr si, [rdi + object.content + word.size]
  jz .index.end
  mov rcx, rdx
  and rdx, ~0x0fff
  ldid a, [rdi + object.content]
  call octet_buffer.newindex
  test rax, rax
  jz .index.end
  mov rdx, rcx
  ldid c, [rsi + object.internal.content]
  call [rsi + object.internal.content + word.size]
.index.end:
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  ret

%endif  ; FILE_ASM_

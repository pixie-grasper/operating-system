%ifndef FILE_ASM_
%define FILE_ASM_

; structure
;   file = {octet-buffer, info | nil}
;   info = {status, [address of the loader]:64}

file:
.new:
  call .new.raw
  shr rax, 4
  ret

.new.raw:
  push rdx
  call octet_buffer.new
  mov edx, eax
  call objects.new.raw
  mov byte [rax + object.class], object.file
  mov [rax + object.content], edx
  pop rdx
  ret

.dispose.raw:
  push rax
  push rcx
  push rdx
  xor rdx, rdx
  mov edx, eax
  shl rdx, 4
  mov eax, [rdx + object.content]
  call objects.unref
  xor rcx, rcx
  mov ecx, [rdx + object.content + 4]
  shl rcx, 4
  jz .dispose.raw.1
  mov eax, [rcx + object.internal.content]
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
  push rcx
  xor rcx, rcx
  mov ecx, eax
  shl rcx, 4
  mov [rcx + object.content + 4], edx
  pop rcx
  ret

  ; in: a = file id
  ; in: d = offset
  ; out: a = nil | mapped address
.index:
  push rcx
  push rdx
  push rsi
  push rdi
  xor rdi, rdi
  mov edi, eax
  shl rdi, 4
  mov eax, [rdi + object.content]
  call octet_buffer.index
  test rax, rax
  jnz .index.end
  xor rsi, rsi
  mov esi, [rdi + object.content + 4]
  shl rsi, 4
  jz .index.end
  mov rcx, rdx
  and rdx, ~0x0fff
  mov eax, [rdi + object.content]
  call octet_buffer.newindex
  test rax, rax
  jz .index.end
  mov rdx, rcx
  mov ecx, [rsi + object.internal.content]
  call [rsi + object.internal.content + 4]
.index.end:
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  ret

%endif  ; FILE_ASM_

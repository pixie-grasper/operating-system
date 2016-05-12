%ifndef FILE_ASM_
%define FILE_ASM_

; structure
;   file = {octet-buffer, info | nil}
;   info = {status, [address of the loader]:64}

file:
.new:
  push rdx
  call octet_buffer.new
  mov edx, eax
  call objects.new.raw
  mov byte [rax + object.class], object.file
  mov [rax + object.content], edx
  shr rax, 4
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

%endif  ; FILE_ASM_

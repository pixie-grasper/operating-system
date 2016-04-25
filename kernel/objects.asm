%ifndef OBJECTS_ASM_
%define OBJECTS_ASM_

struc object
  .mark resb 1
  .class resb 1
  .padding resb 2
  .refcount resd 1
  .content resd 2
endstruc

struc object.internal
  .mark resb 1
  .padding resb 3
  .content resd 3
endstruc

%define object.system 0
%define object.integer 1
%define object.stack 2
%define object.stack.iterator 3

%include "integer.asm"
%include "stack.asm"

objects:
.init:
  xor rax, rax
  mov [fs:TLS.objects.heap], rax
  call .newheap
  ret

.newheap:
  push rcx
  push rdx
  push rdi
  call memory.newpage@s
  mov rdi, rax
  mov ecx, 4096 / 4
  xor edx, edx
.newheap.1:
  mov [rdi], edx
  add rdi, 4
  dec ecx
  jnz .newheap.1
  mov byte [rax], 7  ; reserves 48 byte / 4096 byte
  ; the third object points to the old heap page.
  mov rdx, [fs:TLS.objects.heap]
  mov byte [rax + 32 + object.class], object.system
  mov [rax + 32 + object.content], rdx
  mov [fs:TLS.objects.heap], rax
  pop rdi
  pop rdx
  pop rcx
  ret

  ; assume run on single-process per thread.
.new.chunk:
  push rcx
  push rdx
  push rsi
  push rdi
.new.chunk.1:
  mov rsi, [fs:TLS.objects.heap]
  mov rdi, rsi
  xor rax, rax
  xor ecx, ecx
.new.chunk.2:
  mov eax, [rsi]
  mov edx, eax
  inc edx
  jz .new.chunk.3
  or edx, eax
  mov [rsi], edx
  xor edx, eax  ; only single bit on
  dec edx
  popcnt eax, edx
  shl eax, 4
  add eax, ecx
  add rax, rdi
  xor rcx, rcx
  mov [rax], rcx
  mov [rax + 8], rcx
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  ret
.new.chunk.3:
  add ecx, 512
  add rsi, 4
  cmp ecx, 4096
  jne .new.chunk.2
  call .newheap
  jmp .new.chunk.1

  ; out: a = object id
.new:
  call .new.chunk
  call .ref.init
  shr rax, 4
  ret

  ; out: a = object address
.new.raw:
  call .new.chunk
  call .ref.init
  ret

.ref.init:
  mov dword [rax + object.refcount], 1
  ret

  ; in: a = object id
.ref:
  call .isbool
  jnc .ref.2
  push rcx
  push rdx
  xor rdx, rdx
  mov edx, eax
  shl rdx, 4
.ref.1:
  mov eax, [rdx + object.refcount]
  mov ecx, eax
  inc ecx
  lock cmpxchg [rdx + object.refcount], ecx
  jne .ref.1
  pop rcx
  pop rdx
.ref.2:
  ret

  ; in: a = object id
.unref:
  call .isbool
  jnc .unref.4
  push rcx
  push rdx
  xor rdx, rdx
  mov edx, eax
  shl rdx, 4
.unref.1:
  mov eax, [rdx + object.refcount]
  mov ecx, eax
  dec ecx
  lock cmpxchg [rdx + object.refcount], ecx
  jne .unref.1
  test ecx, ecx
  jnz .unref.3
  mov rax, rdx
  mov dl, [rdx + object.class]
  cmp dl, object.integer
  je .unref.integer
  cmp dl, object.stack
  je .unref.stack
  cmp dl, object.stack.iterator
  je .unref.stack.iterator
.unref.2:
  call .dispose.raw
.unref.3:
  pop rdx
  pop rcx
.unref.4:
  ret
.unref.integer:
  call integer.dispose.raw
  jmp .unref.2
.unref.stack:
  call stack.dispose.raw
  jmp .unref.2
.unref.stack.iterator:
  call stack.iterator.dispose.raw
  jmp .unref.2

  ; in: a = object address
.dispose.raw:
  push rcx
  push rdx
  push rdi
  mov rdi, rax
  mov rcx, rax
  and rdi, ~0x0fff
  and rax, 0x0e00
  shr rax, 9 - 2
  add rdi, rax
  and rcx, 0x01f0
  shr rcx, 4
  mov eax, 1
  shl eax, cl
  mov ecx, eax
  not ecx
.dispose.raw.1:
  mov eax, [rdi]
  mov edx, eax
  and edx, ecx
  lock cmpxchg [rdi], edx
  jne .dispose.raw.1
  pop rdi
  pop rdx
  pop rcx
  ret

  ; compare a < b, return it.
  ; note: nil or false < any (without nil or false).
  ; in: a = object id 1
  ; in: d = object id 2
  ; out: a = boolean id
.lt:
  test edx, edx
  jz .new.false
  test eax, eax
  jz .new.true
  cmp eax, edx
  je .new.false
  xor rcx, rcx
  mov ecx, eax
  shl rcx, 4
  mov rsi, rcx
  xor rcx, rcx
  mov ecx, edx
  shl rcx, 4
  mov rdi, rcx
  mov cl, [rsi + object.class]
  cmp cl, [rdi + object.class]
  ja .new.false
  jb .new.true
  cmp cl, object.system
  je .lt.system
  cmp cl, object.integer
  je .lt.integer
.lt.system:
  call integer.lt@s  ; TODO: compare the system objects exactly
  ret
.lt.integer:
  call integer.lt@s
  ret

.lt@s:
  push rcx
  push rdx
  push rsi
  push rdi
  call .lt
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  ret

.new.nil:
  xor eax, eax
  ret

.new.false:
  xor eax, eax
  ret

.new.true:
  mov eax, 1
  ret

  ; in: a = object id
.isbool:
  test eax, eax
  jz return.true
  cmp eax, 1
  jz return.true
  jmp return.false

.isfalse:
  test eax, eax
  jz return.true
  jmp return.false

%endif  ; OBJECTS_ASM_

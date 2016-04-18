%ifndef OBJECTS_ASM_
%define OBJECTS_ASM_

struc object
  .class resb 1
  .mark resb 1
  .padding resb 2
  .refcount resd 1
  .content resd 2
endstruc

struc object.internal
  .class resb 1
  .mark resb 1
  .padding resb 2
  .content resd 3
endstruc

%define object.system 0
%define object.integer 1

%include "integer.asm"

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

.new.nil:
  xor rax, rax
  ret

.new.false:
  xor rax, rax
  ret

.new.true:
  or rax, -1
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

.new.integer:
  call .new.chunk
  call .ref.init
  mov byte [rax + object.class], object.integer
  ret

.ref.init:
  mov dword [rax + object.refcount], 1
  ret

.ref:
  inc dword [rax + object.refcount]
  ret

.unref:
  dec dword [rax + object.refcount]
  jnz .unref.2
  push rdx
  mov dl, [rax + object.class]
  cmp dl, object.integer
  je .unref.integer
.unref.1:
  call .dispose
  pop rdx
.unref.2:
  ret
.unref.integer:
  call integer.dispose
  jmp .unref.1

.dispose:
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
.dispose.1:
  mov eax, [rdi]
  mov edx, eax
  and edx, ecx
  lock cmpxchg [rdi], edx
  jnz .dispose.1
  pop rdi
  pop rdx
  pop rcx
  ret

; note:
;   64 GiB / 16 byte = 2^32,
;   object-id : 32 bits = address-to-the-object >> 4
.id.to.addr:
  shl rax, 4
  ret

.addr.to.id:
  shr rax, 4
  ret

.isfalse:
  test rax, rax
  jz .new.true
  jmp .new.false

%endif  ; OBJECTS_ASM_

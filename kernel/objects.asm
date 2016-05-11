%ifndef OBJECTS_ASM_
%define OBJECTS_ASM_

struc object
  .mark resb 1
  .class resb 1
  .padding resb 2
  .refcount resd 1
  .content resd 2
endstruc

; classes
.system equ 0
.integer equ 1
.stack equ 2
.stack.iterator equ 3
.octetbuffer equ 4
.set equ 5
.table equ 6
.table.iterator equ 7
.device equ 8
.iso9660.iterator equ 9

struc object.internal
  .mark resb 1
  .padding resb 3
  .content resd 3
endstruc

%include "integer.asm"
%include "octet-buffer.asm"
%include "set.asm"
%include "stack.asm"
%include "table.asm"

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

  ; out: a = chunk address
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
  push rax
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
  pop rdx
  pop rcx
  pop rax
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
  cmp dl, object.octetbuffer
  je .unref.octetbuffer
  cmp dl, object.set
  je .unref.set
  cmp dl, object.table
  je .unref.table
  cmp dl, object.table.iterator
  je .unref.table.iterator
  cmp dl, object.device
  je .unref.device
  cmp dl, object.iso9660.iterator
  je .unref.iso9660.iterator
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
.unref.octetbuffer:
  call octet_buffer.dispose.raw
  jmp .unref.2
.unref.set:
  call set.dispose.raw
  jmp .unref.2
.unref.table:
  call table.dispose.raw
  jmp .unref.2
.unref.table.iterator:
  call table.iterator.dispose.raw
  jmp .unref.2
.unref.device:
  call device.dispose.raw
  jmp .unref.2
.unref.iso9660.iterator:
  call iso9660.iterator.dispose.raw
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

  ; compare a < d, return it.
  ; note: nil or false < any (without nil or false).
  ; in: a = object id 1
  ; in: d = object id 2
  ; out: a = boolean id
.lt@us:
  test edx, edx
  jz .new.false
  test eax, eax
  jz .new.true
  cmp eax, edx
  je .new.false
  xor rsi, rsi
  mov esi, eax
  shl rsi, 4
  xor rdi, rdi
  mov edi, edx
  shl rdi, 4
  mov cl, [rsi + object.class]
  cmp cl, [rdi + object.class]
  ja .new.false
  jb .new.true
  cmp cl, object.integer
  je .lt@us.integer
  cmp rsi, rdi  ; shallow compare
  jb .new.true
  jmp .new.false
.lt@us.integer:
  call integer.lt
  ret

.lt:
  push rcx
  push rdx
  push rsi
  push rdi
  call .lt@us
  pop rdi
  pop rsi
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
  mov rax, 1
  ret

  ; in: a = object id
.isbool:
  test rax, rax
  jz return.true
  cmp rax, 1
  jz return.true
  jmp return.false

.isfalse:
  test rax, rax
  jz return.true
  jmp return.false

%endif  ; OBJECTS_ASM_

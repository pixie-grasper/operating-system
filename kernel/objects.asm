%ifndef OBJECTS_ASM_
%define OBJECTS_ASM_

; page size = 4096 bytes
; object size = 16 / 32 bytes
;   if object-size == 16:
;     objects-per-page := 4096 / 16 (= 256)
;     256-bits = 32 bytes = 2 chunks 
;   else:
;     objects-per-page := 4096 / 32 (= 128)
;     128-bits = 16 bytes = 0.5 chunk

%ifdef OBJECT_32_BYTES
struc object
  .mark resb 1
  .class resb 1
  .padding resb 6
  .refcount resd 1
  .padding.2 resd 1
  .content resq 2
endstruc
%else  ; OBJECT_32_BYTES
struc object
  .mark resb 1
  .class resb 1
  .padding resb 2
  .refcount resd 1
  .content resd 2
endstruc
%endif  ; OBJECT_32_BYTES

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
.iso9660.file.status equ 10
.file equ 11

%ifdef OBJECT_32_BYTES
struc object.internal
  .mark resb 1
  .padding resb 7
  .content resq 3
endstruc
%else  ; OBJECT_32_BYTES
struc object.internal
  .mark resb 1
  .padding resb 3
  .content resd 3
endstruc
%endif

%include "file.asm"
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

%ifdef OBJECT_32_BYTES
.newheap:
  pushs c
  call memory.newpage
  call memory.zerofill
  mov byte [rax], 1  ; reserves 32 byte / 4096 byte
  mov rcx, rax
  mov rax, [fs:TLS.objects.heap]
  mov [rcx + 16], rax
  lock cmpxchg [fs:TLS.objects.heap], rcx
  mov rax, rcx
  je .newheap.1
  call memory.disposepage
  mov rax, [fs:TLS.objects.heap]
.newheap.1:
  pops c
  ret
%else  ; OBJECT_32_BYTES
.newheap:
  pushs c
  call memory.newpage
  call memory.zerofill
  mov byte [rax], 7  ; reserves 48 byte / 4096 byte
  mov byte [rax + 32 + object.class], object.system
  mov rcx, rax
  ; the third object points to the old heap page.
  mov rax, [fs:TLS.objects.heap]
  mov [rcx + 32 + object.content], rax
  lock cmpxchg [fs:TLS.objects.heap], rcx
  mov rax, rcx
  je .newheap.1
  call memory.disposepage
  mov rax, [fs:TLS.objects.heap]
.newheap.1:
  pops c
  ret
%endif

  ; out: a = chunk address
  ; assume run on single-process per thread.
.new.chunk:
  pushs c, d, si, di
.new.chunk.1:
  mov rsi, [fs:TLS.objects.heap]
  mov rdi, rsi
  xor rax, rax
  xor ecx, ecx
  mov eax, [rsi]
.new.chunk.2:
  mov edx, eax
  inc edx
  jz .new.chunk.3
  or edx, eax
  lock cmpxchg [rsi], edx
  jne .new.chunk.2
  xor edx, eax  ; only single bit on
  dec edx
  xor rax, rax
  popcnt eax, edx
%ifdef OBJECT_32_BYTES
  shl eax, 5
%else  ; OBJECT_32_BYTES
  shl eax, 4
%endif  ; OBJECT_32_BYTES
  add eax, ecx
  add rax, rdi
  xor rcx, rcx
  mov [rax], rcx
  mov [rax + 8], rcx
%ifdef OBJECT_32_BYTES
  mov [rax + 16], rcx
  mov [rax + 24], rcx
%endif  ; OBJECT_32_BYTES
  pops c, d, si, di
  ret
.new.chunk.3:
%ifdef OBJECT_32_BYTES
  add ecx, 1024  ; = 32 * 32
%else  ; OBJECT_32_BYTES
  add ecx, 512  ; = 32 * 16
%endif  ; OBJECT_32_BYTES
  add rsi, 4
  cmp ecx, 4096
  jne .new.chunk.2
  call .newheap
  jmp .new.chunk.1

  ; out: a = object id
.new:
  call .new.chunk
  call .ref.init
  id_from_addr a
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
  pushs a, c, d
  addr_from_id d, a
  mov eax, [rdx + object.refcount]
.ref.1:
  mov ecx, eax
  inc ecx
  lock cmpxchg [rdx + object.refcount], ecx
  jne .ref.1
  pops a, c, d
.ref.2:
  ret

  ; in: a = object id
.unref:
  call .isbool
  jnc .unref.4
  pushs a, c, d
  addr_from_id d, a
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
  cmp dl, object.iso9660.file.status
  je .unref.iso9660.file.status
  cmp dl, object.file
  je .unref.file
.unref.2:
  call .dispose.raw
.unref.3:
  pops a, c, d
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
.unref.iso9660.file.status:
  call iso9660.file.status.dispose.raw
  jmp .unref.2
.unref.file:
  call file.dispose.raw
  jmp .unref.2

  ; in: a = object address
.dispose.raw:
  pushs c, d, di
  mov rdi, rax
  mov rcx, rax
  and rdi, ~0x0fff
%ifdef OBJECT_32_BYTES
  and rcx, 0x03e0
  shr ecx, 5
  and rax, 0x0c00
  shr rax, 10 - 2
%else  ; OBJECT_32_BYTES
  and rcx, 0x01f0
  shr ecx, 4
  and rax, 0x0e00
  shr rax, 9 - 2
%endif  ; OBJECT_32_BYTES
  add rdi, rax
  mov eax, 1
  shl eax, cl
  mov ecx, eax
  not ecx
  mov eax, [rdi]
.dispose.raw.1:
  mov edx, eax
  and edx, ecx
  lock cmpxchg [rdi], edx
  jne .dispose.raw.1
  pops c, d, di
  ret

  ; compare a < d, return it.
  ; note: nil or false < any (without nil or false).
  ; in: a = object id 1
  ; in: d = object id 2
  ; out: a = boolean id
.lt@us:
  testid d
  jz .new.false
  testid a
  jz .new.true
  cmp eax, edx
  je .new.false
  addr_from_id si, a
  addr_from_id di, d
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
  pushs c, d, si, di
  call .lt@us
  pops c, d, si, di
  ret

.new.nil:
  ldnil a
  ret

.new.false:
  ldnil a
  ret

.new.true:
  ldt a
  ret

  ; in: a = object id
.isbool:
  testid a
  jz return.true
  cmp rax, 1
  jz return.true
  jmp return.false

.isfalse:
  testid a
  jz return.true
  jmp return.false

%endif  ; OBJECTS_ASM_

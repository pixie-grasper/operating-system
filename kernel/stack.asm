%ifndef STACK_ASM_
%define STACK_ASM_

; structure
; a = {head-node | nil, reserved}
; node = {value.1, value.2, next | nil}, extra-field = flag:1 bit
; flag = 0: 0 = value.2 not present, 1 = value.2 present
stack:
  ; out: a = stack id
.new:
  call objects.new.raw
  mov byte [rax + object.class], object.stack
  shr rax, 4
  ret

  ; in: a = stack address
.dispose.raw:
  push rcx
  push rdx
  xor rdx, rdx
  mov edx, [rax + object.content]
  shl rdx, 4
  jz .dispose.raw.3
.dispose.raw.1:
  mov eax, [rdx + object.internal.content]
  call objects.unref
  test byte [rdx + object.padding], 0x01
  jz .dispose.raw.2
  mov eax, [rdx + object.internal.content + 4]
  call objects.unref
.dispose.raw.2:
  xor rcx, rcx
  mov ecx, [rdx + object.internal.content + 8]
  mov rax, rdx
  call objects.dispose.raw
  mov rdx, rcx
  shl rdx, 4
  jnz .dispose.raw.1
.dispose.raw.3:
  pop rdx
  pop rcx
  ret

  ; @const
  ; in: a = stack id
  ; out: a = true if the stack is empty
.empty:
  push rdx
  xor rdx, rdx
  mov edx, eax
  shl rdx, 4
  mov eax, [rdx + object.content]
  pop rdx
  call objects.isfalse
  jnc .empty.1
  call objects.new.false
  ret
.empty.1:
  call objects.new.true
  ret

  ; @const
  ; in: a = stack id
  ; out: a = top object id of the stack
.top:
  push rdx
  xor rdx, rdx
  mov edx, eax
  shl rdx, 4
  xor rax, rax
  mov eax, [rdx + object.content]
  shl rax, 4
  test byte [rax + object.padding], 0x01
  jnz .top.1
  mov eax, [rax + object.internal.content]
  jmp .top.2
.top.1:
  mov eax, [rax + object.internal.content + 4]
.top.2:
  pop rdx
  ret

  ; @const
  ; in: a = stack id
  ; in: d = n: integer; top = 0
  ; out: a = n-th object id of the stack
.nth:
  push rcx
  push rdx
  xor rcx, rcx
  mov ecx, eax
  shl rcx, 4
  xor rax, rax
  mov eax, [rcx + object.content]
  shl rax, 4
.nth.1:
  test rdx, rdx
  jz .nth.3
  dec rdx
  jz .nth.5
  test byte [rax + object.padding], 0x01
  jz .nth.2
  dec rdx
.nth.2:
  xor rcx, rcx
  mov ecx, [rax + object.internal.content + 8]
  shl rcx, 4
  mov rax, rcx
  jmp .nth.1
.nth.3:
  test byte [rax + object.padding], 0x01
  jnz .nth.4
  mov eax, [rax + object.internal.content]
  jmp .nth.7
.nth.4:
  mov eax, [rax + object.internal.content + 4]
  jmp .nth.7
.nth.5:
  test byte [rax + object.padding], 0x01
  jz .nth.6
  mov eax, [rax + object.internal.content]
  jmp .nth.7
.nth.6:
  xor rcx, rcx
  mov ecx, [rax + object.internal.content + 8]
  shl rcx, 4
  mov eax, [rcx + object.internal.content + 4]
.nth.7:
  pop rdx
  pop rcx
  ret

  ; in: a = stack id
  ; in: d = object id that will be pushed
.push:
  push rax
  call .push.move
  mov eax, edx
  call objects.ref
  pop rax
  ret

  ; in: a = stack id
  ; in: d = object id that will be pushed
.push.move:
  push rax
  ; rdx not changed
  push rsi
  push rdi
  xor rdi, rdi
  xor rsi, rsi
  mov edi, eax
  shl rdi, 4
  mov esi, [rdi + object.content]
  shl rsi, 4
  jnz .push.move.1
  call objects.new.chunk
  mov byte [rax + object.padding], 0x00
  mov [rax + object.internal.content], edx
  mov [rax + object.internal.content + 4], rsi
  shr rax, 4
  mov [rdi + object.content], eax
  jmp .push.move.3
.push.move.1:
  test byte [rsi + object.padding], 0x01
  jnz .push.move.2
  mov byte [rsi + object.padding], 0x01
  mov [rsi + object.internal.content + 4], edx
  jmp .push.move.3
.push.move.2:
  call objects.new.chunk
  shr rsi, 4
  mov byte [rax + object.padding], 0x00
  mov [rax + object.internal.content], edx
  mov [rax + object.internal.content + 8], esi
  shr rax, 4
  mov [rdi + object.content], eax
.push.move.3:
  pop rdi
  pop rsi
  pop rax
  ret

  ; in: a = stack id
.pop:
  push rax
  push rdx
  push rsi
  xor rdx, rdx
  mov edx, eax
  shl rdx, 4
  xor rax, rax
  mov eax, [rdx + object.content]
  shl rax, 4
  test byte [rax + object.padding], 0x01
  jnz .pop.1
  push rax
  mov eax, [rax + object.internal.content]
  call objects.unref
  pop rax
  mov esi, [rax + object.internal.content + 8]
  call objects.dispose.raw
  mov [rdx + object.content], esi
  jmp .pop.2
.pop.1:
  mov byte [rax + object.padding], 0x00
  mov eax, [rax + object.internal.content + 4]
  call objects.unref
.pop.2:
  pop rsi
  pop rdx
  pop rax
  ret

  ; in: a = stack id
  ; out: a = object id that was popped
.pop.move:
  push rdx
  push rsi
  xor rdx, rdx
  mov edx, eax
  shl rdx, 4
  xor rax, rax
  mov eax, [rdx + object.content]
  shl rax, 4
  test byte [rax + object.padding], 0x01
  jnz .pop.move.1
  mov esi, [rax + object.internal.content + 8]
  mov [rdx + object.content], esi
  mov esi, [rax + object.internal.content]
  call objects.dispose.raw
  mov eax, esi
  jmp .pop.move.2
.pop.move.1:
  mov byte [rax + object.padding], 0x00
  mov eax, [rax + object.internal.content + 4]
.pop.move.2:
  pop rsi
  pop rdx
  ret

%endif  ; STACK_ASM_
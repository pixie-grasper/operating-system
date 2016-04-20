%ifndef STACK_ASM_
%define STACK_ASM_

; structure
; a = {head-node | nil, reserved}
; node = {value.1, value.2, next | nil}, extra-field = flag:1 bit
; flag = 0: 0 = value.2 not present, 1 = value.2 present
stack:
  ; out: a = stack id
.new:
  push rdx
  call objects.new.raw
  mov byte [rax + object.class], object.stack
  xor rdx, rdx
  mov [rax + object.content], rdx
  shr rax, 4
  pop rdx
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
  xor rax, rax
  mov eax, [rdx + object.internal.content + 8]
  mov rcx, rax
  mov rax, rdx
  call objects.dispose.raw
  mov rdx, rcx
  shl rdx, 4
  jnz .dispose.raw.1
.dispose.raw.3:
  pop rdx
  pop rcx
  ret

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
  jz .top.1
  mov eax, [rax + object.internal.content]
  jmp .top.2
.top.1:
  mov eax, [rax + object.internal.content + 4]
.top.2:
  pop rdx
  ret

  ; in: a = stack id
  ; in: d = object id that will be pushed
.push:
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
  jnz .push.1
  call objects.new.chunk
  mov byte [rax + object.padding], 0x00
  mov [rax + object.internal.content], edx
  mov [rax + object.internal.content + 4], rsi
  shr rax, 4
  mov [rdi + object.content], eax
  jmp .push.3
.push.1:
  test byte [rsi + object.padding], 0x01
  jnz .push.2
  mov byte [rsi + object.padding], 0x01
  mov [rsi + object.internal.content + 4], edx
  jmp .push.3
.push.2:
  call objects.new.chunk
  shr rsi, 4
  mov byte [rax + object.padding], 0x00
  mov [rax + object.internal.content], edx
  mov [rax + object.internal.content + 8], esi
  shr rax, 4
  mov [rdi + object.content], eax
.push.3:
  mov eax, edx
  call objects.ref
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
  mov eax, [rax + object.content]
  call objects.unref
  pop rax
  xor rsi, rsi
  mov esi, [rax + object.content + 8]
  call objects.dispose.raw
  mov [rdx + object.content], esi
  jmp .pop.2
.pop.1:
  mov byte [rax + object.padding], 0x00
  mov eax, [rax + object.content + 4]
  call objects.unref
.pop.2:
  pop rsi
  pop rdx
  pop rax
  ret


%endif  ; STACK_ASM_

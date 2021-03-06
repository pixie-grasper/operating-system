%ifndef STACK_ASM_
%define STACK_ASM_

; structure
;   stack = {head-node | nil, reserved}
;     node = {value.1, value.2, next | nil}, extra-field = flag: 1 bit
;     flag = 0: 0 = value.2 not present, 1 = value.2 present
;   iterator = {[address of the node]:64}, extra-field = flag: 1 bit
;     flag = 0: 0 = value.1 selected, 1 = value.2 selected
stack:
  ; out: a = stack id
.new:
  call objects.new.raw
  mov byte [rax + object.class], object.stack
  id_from_addr a
  ret

  ; in: a = stack address
.dispose.raw:
  pushs a
  id_from_addr a
  call .clear
  pops a
  ret

.iterator.dispose.raw:
  ret

  ; @const
  ; in: a = stack id
  ; out: a = true if the stack is empty
.empty:
  pushs d
  addr_from_id d, a
  ldid a, [rdx + object.content]
  pops d
  call objects.isfalse
  jnc .empty.1
  ldnil a
  ret
.empty.1:
  ldt a
  ret

  ; @const
  ; in: a = stack id
  ; out: a = top object id of the stack
.top:
  pushs d
  addr_from_id d, a
  ldaddr a, [rdx + object.content]
  test byte [rax + object.internal.padding], 0x01
  jnz .top.1
  ldid a, [rax + object.internal.content]
  jmp .top.2
.top.1:
  ldid a, [rax + object.internal.content + word.size]
.top.2:
  pops d
  ret

  ; @const
  ; in: a = stack id
  ; in: d = n: integer; top = 0
  ; out: a = n-th object id of the stack
.nth:
  pushs c, d
  addr_from_id c, a
  ldaddr a, [rcx + object.content]
.nth.1:
  test rdx, rdx
  jz .nth.3
  dec rdx
  jz .nth.5
  test byte [rax + object.internal.padding], 0x01
  jz .nth.2
  dec rdx
.nth.2:
  ldaddr c, [rax + object.internal.content + word.size * 2]
  mov rax, rcx
  jmp .nth.1
.nth.3:
  test byte [rax + object.internal.padding], 0x01
  jnz .nth.4
  ldid a, [rax + object.internal.content]
  jmp .nth.7
.nth.4:
  ldid a, [rax + object.internal.content + word.size]
  jmp .nth.7
.nth.5:
  test byte [rax + object.internal.padding], 0x01
  jz .nth.6
  ldid a, [rax + object.internal.content]
  jmp .nth.7
.nth.6:
  ldaddr c, [rax + object.internal.content + word.size * 2]
  ldid a, [rcx + object.internal.content + word.size]
.nth.7:
  pops c, d
  ret

  ; @const
  ; in: a = stack id
  ; out: a = stack.iterator id
.begin:
  pushs c, d
  addr_from_id d, a
  call objects.new.raw
  mov byte [rax + object.class], object.stack.iterator
  ldaddr c, [rdx + object.content]
  mov [rax + object.content], rcx
  mov dl, [rcx + object.internal.padding]
  mov [rax + object.padding], dl
  id_from_addr a
  pops c, d
  ret

  ; in: a = stack.iterator id
  ; out: a = object id
.iterator.deref:
  pushs c, d
  ldnil c
  addr_from_id d, a
  mov rax, [rdx + object.content]
  mov cl, [rdx + object.padding]
  ldid a, [rax + object.internal.content + rcx * word.size]
  pops c, d
  ret

  ; in/out: a = stack.iterator id
.iterator.succ:
  pushs d
  addr_from_id d, a
  test byte [rdx + object.padding], 0x01
  jz .iterator.succ.1
  mov byte [rdx + object.padding], 0x00
  jmp .iterator.succ.2
.iterator.succ.1:
  pushs a, c
  mov rax, [rdx + object.content]
  mov cl, [rax + object.internal.padding]
  mov [rdx + object.padding], cl
  ldaddr c, [rax + object.internal.content + word.size * 2]
  mov [rdx + object.content], rcx
  pops a, c
.iterator.succ.2:
  pops d
  ret

  ; in: a = stack.iterator id
.iterator.isend:
  pushs d
  addr_from_id d, a
  mov rdx, [rdx + object.content]
  test rdx, rdx
  pops d
  jz return.true
  jmp return.false

  ; in: a = stack id
  ; in: d = object id that will be pushed
.push:
  pushs a
  call .push.move
  movid a, d
  call objects.ref
  pops a
  ret

  ; in: a = stack id
  ; in: d = object id that will be pushed
.push.move:
  pushs a, si, di
  addr_from_id di, a
  ldaddr si, [rdi + object.content]
  jnz .push.move.1
  call objects.new.chunk
  mov byte [rax + object.internal.padding], 0x00
  stid [rax + object.internal.content], d
  id_from_addr a
  stid [rdi + object.content], a
  jmp .push.move.3
.push.move.1:
  test byte [rsi + object.internal.padding], 0x01
  jnz .push.move.2
  mov byte [rsi + object.internal.padding], 0x01
  stid [rsi + object.internal.content + word.size], d
  jmp .push.move.3
.push.move.2:
  call objects.new.chunk
  id_from_addr si
  mov byte [rax + object.internal.padding], 0x00
  stid [rax + object.internal.content], d
  stid [rax + object.internal.content + word.size * 2], si
  id_from_addr a
  stid [rdi + object.content], a
.push.move.3:
  pops a, si, di
  ret

  ; in: a = stack id
.pop:
  pushs a, d, si
  addr_from_id d, a
  ldaddr a, [rdx + object.content]
  test byte [rax + object.internal.padding], 0x01
  jnz .pop.1
  push rax
  ldid a, [rax + object.internal.content]
  call objects.unref
  pop rax
  ldid si, [rax + object.internal.content + word.size * 2]
  call objects.dispose.raw
  stid [rdx + object.content], si
  jmp .pop.2
.pop.1:
  mov byte [rax + object.internal.padding], 0x00
  ldid a, [rax + object.internal.content + word.size]
  call objects.unref
.pop.2:
  pops a, d, si
  ret

  ; in: a = stack id
  ; out: a = object id that was popped
.pop.move:
  pushs d, si
  addr_from_id d, a
  ldaddr a, [rdx + object.content]
  test byte [rax + object.internal.padding], 0x01
  jnz .pop.move.1
  ldid si, [rax + object.internal.content + word.size * 2]
  stid [rdx + object.content], si
  ldid si, [rax + object.internal.content]
  call objects.dispose.raw
  movid a, si
  jmp .pop.move.2
.pop.move.1:
  mov byte [rax + object.internal.padding], 0x00
  ldid a, [rax + object.internal.content + word.size]
.pop.move.2:
  pops d, si
  ret

  ; in: a = stack id
.clear:
  pushs a, c, d
  addr_from_id d, a
  ldaddr a, [rdx + object.content]
  testaddr a
  mov rdx, rax
  jz .clear.raw.3
  push rax
.clear.raw.1:
  ldid a, [rdx + object.internal.content]
  call objects.unref
  test byte [rdx + object.internal.padding], 0x01
  jz .clear.raw.2
  ldid a, [rdx + object.internal.content + word.size]
  call objects.unref
.clear.raw.2:
  ldaddr c, [rdx + object.internal.content + word.size]
  mov rax, rdx
  call objects.dispose.raw
  mov rdx, rcx
  test rcx, rcx
  jnz .clear.raw.1
  pop rax
  stid [rax + object.content], d
.clear.raw.3:
  pops a, c, d
  ret

  ; in: a = stack id
.clear.move:
  pushs a, d
  addr_from_id d, a
  ldaddr a, [rdx + object.content]
  testaddr a
  jz .clear.move.2
  push rdx
.clear.move.1:
  ldaddr d, [rax + object.internal.content + word.size * 2]
  call objects.dispose.raw
  mov rax, rdx
  test rdx, rdx
  jnz .clear.move.1
  pop rdx
  stid [rdx + object.content], a
.clear.move.2:
  pops a, d
  ret

%endif  ; STACK_ASM_

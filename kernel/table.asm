%ifndef TABLE_ASM_
%define TABLE_ASM_

; structure
;   table = {root-node | nil, reserved}
;     node = {internal-node, left | nil, right | nil}, extra-field = balance: 8 bits
;     internal-node = {key, value, weight}
;     balance = -2 .. 2 (includes internal-state-value)
;   iterator = {current-node, stack indicates path}, extra-field = end: 1 bit
;     end = 0: not end, 1: end

table:
.new:
  call objects.new.raw
  mov byte [rax + object.class], object.table
  id_from_addr a
  ret

.dispose.raw:
  pushs a
  id_from_addr a
  call .clear
  pops a
  ret

.iterator.dispose.raw:
  pushs a
  ldid a, [rax + object.content + word.size]
  call stack.clear.move
  call objects.unref
  pops a
  ret

  ; in: a = table id
.clear:
  pushs a, c, d
  addr_from_id d, a
  ldaddr a, [rdx + object.content]
  jz .clear.1
  mov rdx, rax
  call .clear.2
.clear.1:
  pops a, c, d
  ret
.clear.2:
  ldaddr c, [rdx + object.internal.content]
  ldid a, [rcx + object.internal.content]
  call objects.unref
  ldid a, [rcx + object.internal.content + word.size]
  call objects.unref
  mov rax, rcx
  call objects.dispose.raw
%ifdef OBJECT_32_BYTES
  ldaddr d, [rdx + object.internal.content + word.size]
%else  ; OBJECT_32_BYTES
  mov rax, rdx
  ldaddr d, [rax + object.internal.content + word.size]
%endif  ; OBJECT_32_BYTES
  jz .clear.3
  push rax
  call .clear.2
  pop rax
.clear.3:
  ldaddr d, [rax + object.internal.content + word.size * 2]
  jz .clear.4
  push rax
  call .clear.2
  pop rax
.clear.4:
  call objects.dispose.raw
  ret

  ; @const
  ; in: a = table id
  ; out: a = table.iterator id
.begin:
  pushs c, d, si, di
  addr_from_id d, a
  call objects.new.raw
  mov byte [rax + object.class], object.stack.iterator
  mov rsi, rax
  call stack.new
  stid [rsi + object.content + word.size], a
  ldaddr c, [rdx + object.content]
  testaddr c
  jz .begin.2
  movid di, a
.begin.1:
  ; c: address of the current node
  ; si: address of the iterator
  ; di: stack id
  ; while node.left != nil:
  ldaddr a, [rcx + object.internal.content + word.size]
  testaddr a
  jz .begin.2
  ; push node, false
  movid a, di
  mov rdx, rcx
  id_from_addr d
  call stack.push.move
  ldnil d
  call stack.push.move
  ; node <- node.left
  ldaddr d, [rcx + object.internal.content + word.size]
  mov rcx, rdx
  jmp .begin.1
.begin.2:
  id_from_addr c
  stid [rsi + object.content], c
  id_from_addr si
  movid a, si
  pops c, d, si, di
  ret

  ; in: a = table.iterator id
  ; out: a = key id
  ; out: d = value id
.iterator.deref:
  pushs c
  addr_from_id c, a
  ldaddr d, [rcx + object.content]
  ldaddr c, [rdx + object.internal.content]
  ldid a, [rcx + object.internal.content]
  ldid d, [rcx + object.internal.content + word.size]
  pops c
  ret

  ; in: a = table.iterator id
.iterator.succ:
  pushs a, c, d, si, di, bp
  addr_from_id si, a
  ; if iterator ended: return it
  cmp byte [rsi + object.padding], 0
  jne .iterator.succ.5
  ldaddr c, [rsi + object.content]
  ldid bp, [rsi + object.content + word.size]
  ; c: address of the current node
  ; si: address of the iterator
  ; bp: stack id indicates path
  ; if node.right != nil:
  ldaddr di, [rcx + object.internal.content + word.size * 2]
  testaddr di
  jz .iterator.succ.2
  ; push node, true
  movid a, bp
  mov rdx, rcx
  id_from_addr d
  call stack.push.move
  ldt d
  call stack.push.move
  ; node <- node.right
  mov rcx, rdi
.iterator.succ.1:
  ; while node.left != nil:
  ldaddr di, [rcx + object.internal.content + word.size]
  testaddr di
  jz .iterator.succ.3
  ; push node, false
  movid a, bp
  mov rdx, rcx
  id_from_addr d
  call stack.push.move
  ldnil d
  call stack.push.move
  ; node <- node.left
  mov rcx, rdi
  jmp .iterator.succ.1
.iterator.succ.2:
  ; else:
  ; while path.len != 0:
  movid a, bp
  call stack.empty
  testid a
  jnz .iterator.succ.4
  ; node, pdir <- path.pop()
  movid a, bp
  call stack.pop.move
  movid d, a
  movid a, bp
  call stack.pop.move
  addr_from_id c, a
  ; if pdir == LEFT:
  testid d
  jnz .iterator.succ.2
.iterator.succ.3:
  ; iterator.node <- current-node
  id_from_addr c
  stid [rsi + object.content], c
  jmp .iterator.succ.5
.iterator.succ.4:
  ; if old-node pointed the maximum-key: return ended iterator
  mov byte [rsi + object.padding], 1
.iterator.succ.5:
  pops a, c, d, si, di, bp
  ret

  ; in: a = table.iterator id
.iterator.isend:
  pushs d
  addr_from_id d, a
  cmp byte [rdx + object.padding], 0
  pops d
  je return.false
  jmp return.true

  ; @const
  ; in: a = table id
  ; in: d = key id
  ; out: a = value id or nil
.index:
  pushs c, d, si, di
  addr_from_id di, a
  ldaddr si, [rdi + object.content]
  jz .index.4
  movid di, d
.index.1:
  ; si: address of the current node
  ; di: key id
  ldaddr c, [rsi + object.internal.content]
  ldid a, [rcx + object.internal.content]
  movid d, di
  call objects.lt
  testid a
  jz .index.2
  ; [si:o.i.c].key < key
  ldaddr a, [rsi + object.internal.content + word.size * 2]
  testaddr a
  jz .index.4
  mov rsi, rax
  jmp .index.1
.index.2:
  movid a, di
  ldid d, [rcx + object.internal.content]
  call objects.lt
  testid a
  jz .index.3
  ; [si:o.i.c].key > key
  ldaddr a, [rsi + object.internal.content + word.size]
  testaddr a
  jz .index.4
  mov rsi, rax
  jmp .index.1
.index.3:
  ldid a, [rcx + object.internal.content + word.size]
  jmp .index.5
.index.4:
  ldnil a
.index.5:
  pops c, d, si, di
  ret

  ; in: a = table id
  ; in: d = key id
  ; in: c = value id or nil
.newindex:
  pushs a, b, c, d, si, di, bp, r8
  addr_from_id b, a
  movid di, d
  call stack.new
  movid bp, a
  ldaddr si, [rbx + object.content]
  testaddr si
  ; b: address of the table
  ; c: value id or nil
  ; si: address of the current node
  ; di: key id
  ; bp: stack id
.newindex.1:
  jz .newindex.4
  ldaddr r8, [rsi + object.internal.content]
  ldid a, [r8 + object.internal.content]
  movid d, di
  call objects.lt
  testid a
  jz .newindex.2
  ; [si:o.i.c].key < key
  ; push node, true
  movid a, bp
  mov rdx, rsi
  id_from_addr d
  call stack.push.move
  ldt d
  call stack.push.move
  ; node <- node.right
  ldaddr a, [rsi + object.internal.content + word.size * 2]
  testaddr a
  mov rsi, rax
  jmp .newindex.1
.newindex.2:
  movid a, di
  ldid d, [r8 + object.internal.content]
  call objects.lt
  testid a
  jz .newindex.3
  ; [si:o.i.c].key > key
  ; push node, false
  movid a, bp
  mov rdx, rsi
  id_from_addr d
  call stack.push.move
  ldnil d
  call stack.push.move
  ; node <- node.left
  ldaddr a, [rsi + object.internal.content + word.size]
  testaddr a
  mov rsi, rax
  jmp .newindex.1
.newindex.3:
  ; if value == nil: remove pair form the table
  testid c
  jz .newindex.remove.1
  ; else: update pair
  ldaddr d, [rsi + object.internal.content]
  ldid a, [rdx + object.internal.content + word.size]
  cmpid a, c
  je .newindex.5
  movid a, c
  call objects.ref
  ldid a, [rdx + object.internal.content + word.size]
  call objects.unref
  stid [rdx + object.internal.content + word.size], c
  jmp .newindex.5
.newindex.4:
  ; if value == nil: do nothing
  testid c
  jz .newindex.5
  ; else: insert the pair
  call objects.new.chunk
  mov rsi, rax
  call objects.new.chunk
  stid [rax + object.internal.content], di
  stid [rax + object.internal.content + word.size], c
  mov dword [rax + object.internal.content + word.size * 2], 1
  id_from_addr a
  stid [rsi + object.internal.content], a
  movid a, di
  call objects.ref
  movid a, c
  call objects.ref
  jmp .newindex.insert.1
.newindex.5:
  movid a, bp
  call stack.clear.move
  call objects.unref
  pops a, b, c, d, si, di, bp, r8
  ret

.newindex.insert.1:
  ; b: address of the table
  ; si: address of the dangling node (at the top of the loop) or new-node
  ; bp: stack id indicates path
  ; while path.len != 0:
  movid a, bp
  call stack.empty
  testid a
  jnz .newindex.insert.8
  ; pnode, pdir <- path.pop()
  movid a, bp
  call stack.pop.move
  clear_before_ld d
  movid d, a
  movid a, bp
  call stack.pop.move
  addr_from_id c, a
  ; if pdir == LEFT: pnode.left <- node else: pnode.right <- node
  id_from_addr si
  stid [rcx + object.internal.content + word.size + rdx * word.size], si
  ; if pdir == LEFT: pnode.balance++ else: pnode.balance--
  add edx, edx
  dec edx
  sub [rcx + object.internal.padding], dl
  ; pnode.weight <- pnode.left.weight + pnode.right.weight + 1
  ; if pnode.* == nil: pnode.*.weight == 0
  ldnil d
  ldaddr a, [rcx + object.internal.content + word.size]
  testaddr a
  jz .newindex.insert.2
  ldaddr si, [rax + object.internal.content]
  add edx, [rsi + object.internal.content + word.size * 2]
.newindex.insert.2:
  ldaddr a, [rcx + object.internal.content + word.size * 2]
  testaddr a
  jz .newindex.insert.3
  ldaddr si, [rax + object.internal.content]
  add edx, [rsi + object.internal.content + word.size * 2]
.newindex.insert.3:
  inc edx
  ldaddr a, [rcx + object.internal.content]
  mov [rax + object.internal.content + word.size * 2], edx
  mov rsi, rcx
  ; if pnode.balance == 0: break
  mov dl, [rcx + object.internal.padding]
  test dl, dl
  jz .newindex.insert.13
  ; if pnode.balance > 1:
  cmp dl, 1
  jng .newindex.insert.5
  ; if pnode.left.balance < 0:
  ldaddr a, [rcx + object.internal.content + word.size]
  cmp byte [rax + object.internal.padding], 0
  jnl .newindex.insert.4
  ; pnode.left <- rotate.left pnode.left
  call .rotate.left
  id_from_addr a
  stid [rcx + object.internal.content + word.size], a
  ; new-node <- rotate.right pnode
  mov rax, rcx
  call .rotate.right
  mov rsi, rax
  ; balance.update
  call .balance.update
  ; break
  jmp .newindex.insert.7
.newindex.insert.4:
  ; new-node <- rotate.right pnode
  mov rax, rcx
  call .rotate.right
  mov rsi, rax
  ; new-node.balance <- 0
  ; pnode.balance <- 0
  mov byte [rax + object.internal.padding], 0
  mov byte [rcx + object.internal.padding], 0
  ; break
  jmp .newindex.insert.7
.newindex.insert.5:
  ; elif pnode.balance < -1:
  cmp dl, -1
  jnl .newindex.insert.1
  ; if pnode.right.balance > 0:
  ldaddr a, [rcx + object.internal.content + word.size * 2]
  cmp byte [rax + object.internal.padding], 0
  jng .newindex.insert.6
  ; pnode.right <- rotate.right pnode.right
  call .rotate.right
  ; new-node <- rotate.left pnode
  mov rax, rcx
  call .rotate.left
  mov rsi, rax
  ; balance.update new-node
  call .balance.update
  ; break
  jmp .newindex.insert.7
.newindex.insert.6:
  ; new-node <- rotate.left pnode
  mov rax, rcx
  call .rotate.left
  mov rsi, rax
  ; new-node.balance <- 0
  ; pnode.balance <- 0
  mov byte [rax + object.internal.padding], 0
  mov byte [rcx + object.internal.padding], 0
  ; break through
.newindex.insert.7:
  ; si: address of a dangling new-node
  ; if path.len == 0: root-node <- new-node
  movid a, bp
  call stack.empty
  testid a
  jz .newindex.insert.9
.newindex.insert.8:
  id_from_addr si
  stid [rbx + object.content], si
  jmp .newindex.5
.newindex.insert.9:
  ; else:
  ; pnode, pdir <- path.pop()
  movid a, bp
  call stack.pop.move
  clear_before_ld d
  movid d, a
  movid a, bp
  call stack.pop.move
  addr_from_id c, a
  ; if pdir == LEFT: pnode.left <- new-node else: pnode.right <- new-node
  id_from_addr si
  stid [rcx + object.internal.content + word.size + rdx * word.size], si
.newindex.insert.10:
  ; b: address of the table
  ; c: address of the pnode
  ; bp: stack id indicates path
  ; while true:
  ; pnode.weight <- pnode.left.weight + pnode.right.weight + 1
  ; if pnode.* == nil: pnode.*.weight == 0
  ldnil d
  ldaddr a, [rcx + object.internal.content + word.size]
  testaddr a
  jz .newindex.insert.11
  ldaddr si, [rax + object.internal.content]
  add edx, [rsi + object.internal.content + word.size * 2]
.newindex.insert.11:
  ldaddr a, [rcx + object.internal.content + word.size * 2]
  testaddr a
  jz .newindex.insert.12
  ldaddr si, [rax + object.internal.content]
  add edx, [rsi + object.internal.content + word.size * 2]
.newindex.insert.12:
  inc edx
  ldaddr a, [rcx + object.internal.content]
  mov [rax + object.internal.content + word.size * 2], edx
.newindex.insert.13:
  ; if path.len == 0: break
  movid a, bp
  call stack.empty
  testid a
  jnz .newindex.5
  ; pnode, pdir <- path.pop()
  movid a, bp
  call stack.pop.move
  movid a, bp
  call stack.pop.move
  addr_from_id c, a
  jmp .newindex.insert.10

.newindex.remove.1:
  ; b: address of the table
  ; si: address of the current node
  ; bp: stack id
  ldaddr d, [rsi + object.internal.content]
  ldid a, [rdx + object.internal.content]
  call objects.unref
  ldid a, [rdx + object.internal.content + word.size]
  call objects.unref
  ; if it has childlen:
  ldid a, [rsi + object.internal.content + word.size]
  testid a
  jz .newindex.remove.4
  ldid a, [rsi + object.internal.content + word.size * 2]
  testid a
  jz .newindex.remove.4
  ; find node.right.left.left.left. ... .left that is not nil
  ; push node, true
  movid a, bp
  mov rdx, rsi
  id_from_addr d
  call stack.push.move
  ldt d
  call stack.push.move
  ; that <- node.right
  ldaddr di, [rsi + object.internal.content + word.size * 2]
.newindex.remove.2:
  ; while that.left != nil:
  ldid a, [rdi + object.internal.content + word.size]
  testid a
  jz .newindex.remove.3
  ; push that, false
  movid a, bp
  mov rdx, rdi
  id_from_addr d
  call stack.push.move
  ldnil d
  call stack.push.move
  ; that <- that.left
%ifdef OBJECT_32_BYTES
  ldaddr di, [rdi + object.internal.content + word.size]
%else  ; OBJECT_32_BYTES
  ldid a, [rdi + object.internal.content + word.size]
  addr_from_id di, a
%endif  ; OBJECT_32_BYTES
  jmp .newindex.remove.2
.newindex.remove.3:
  ; node.key, node.value <- that.key, that.value
  ldaddr a, [rdi + object.internal.content]
  ldaddr c, [rsi + object.internal.content]
  ldid d, [rax + object.internal.content]
  stid [rcx + object.internal.content], d
  ldid d, [rax + object.internal.content + word.size]
  stid [rcx + object.internal.content + word.size], d
  ; node <- that
  mov rsi, rdi
.newindex.remove.4:
  ; if path.len != 0: pnode <- path.top().node else: pnode <- nil
  ldnil di
  movid a, bp
  call stack.empty
  testid a
  jnz .newindex.remove.5
  movid a, bp
  mov rdx, 1
  call stack.nth
  addr_from_id di, a
.newindex.remove.5:
  ; now, (node.left && node.right) == nil
  ; if node.left == nil: node <- node.right else: node <- node.left
  ldid d, [rsi + object.internal.content + word.size]
  testid d
  jnz .newindex.remove.6
  ldid d, [rsi + object.internal.content + word.size * 2]
.newindex.remove.6:
  ldaddr a, [rsi + object.internal.content]
  call objects.dispose.raw
  mov rax, rsi
  call objects.dispose.raw
  ; if root-node removed: root-node <- node
  test rdi, rdi
  jnz .newindex.remove.7
  stid [rbx + object.content], d
  jmp .newindex.5
  ; table.node <- nil
.newindex.remove.7:
  ; if path.top().dir == LEFT: pnode.left <- node else: pnode.right <- node
  movid a, bp
  call stack.top
  clear_before_ld c
  movid c, a
  ldid a, [rdi + object.internal.content + word.size + rcx * word.size]
  stid [rdi + object.internal.content + word.size + rcx * word.size], d
  addr_from_id si, a
  ldaddr a, [rsi + object.internal.content]
  call objects.dispose.raw
  mov rax, rsi
  call objects.dispose.raw
.newindex.remove.8:
  ; b: address of the table
  ; si: address of the new-node
  ; di: address of the pnode
  ; bp: stack id indicates path
  ; while path.len != 0:
  movid a, bp
  call stack.empty
  testid a
  jnz .newindex.5
  ; new-node <- nil
  ldnil si
  ; pnode, pdir <- path.pop()
  movid a, bp
  call stack.pop.move
  movid d, a
  movid a, bp
  call stack.pop.move
  addr_from_id di, a
  ; if pdir == LEFT: pnode.balance-- else: pnode.balance++
  add edx, edx
  dec edx
  add [rdi + object.internal.padding], dl
  ; pnode.weight <- pnode.left.weight + pnode.right.weight + 1
  ; if pnode.* == nil: pnode.*.weight == 0
  xor edx, edx
  ldaddr a, [rdi + object.internal.content + word.size]
  testaddr a
  jz .newindex.remove.9
  ldaddr c, [rax + object.internal.content]
  add edx, [rcx + object.internal.content + word.size * 2]
.newindex.remove.9:
  ldaddr a, [rdi + object.internal.content + word.size * 2]
  testaddr a
  jz .newindex.remove.10
  ldaddr c, [rax + object.internal.content]
  add edx, [rcx + object.internal.content + word.size * 2]
.newindex.remove.10:
  inc edx
  ldaddr a, [rdi + object.internal.content]
  mov [rax + object.internal.content + word.size * 2], edx
  ; if pnode.balance > 1:
  mov dl, [rdi + object.internal.padding]
  cmp dl, 1
  jng .newindex.remove.13
  ; if pnode.left.balance < 0:
  ldaddr a, [rdi + object.internal.content + word.size]
  cmp byte [rax + object.internal.padding], 0
  jnl .newindex.remove.11
  ; pnode.left <- rotate.left pnode.left
  call .rotate.left
  id_from_addr a
  stid [rdi + object.internal.content + word.size], a
  ; new-node <- rotate.right pnode
  mov rax, rdi
  call .rotate.right
  mov rsi, rax
  ; balance.update
  call .balance.update
  jmp .newindex.remove.17
.newindex.remove.11:
  ; new-node <- rotate.right pnode
  mov rax, rdi
  call .rotate.right
  mov rsi, rax
  ; if new-node.balance == 0: new-node.balance <- -1; pnode.balance <- 1
  cmp byte [rax + object.internal.padding], 0
  jne .newindex.remove.12
  mov byte [rax + object.internal.padding], -1
  mov byte [rdi + object.internal.padding], 1
  jmp .newindex.remove.17
.newindex.remove.12:
  ; else: new-node.balance <- 0; pnode.balance <- 0
  mov byte [rax + object.internal.padding], 0
  mov byte [rdi + object.internal.padding], 0
  jmp .newindex.remove.17
.newindex.remove.13:
  ; elif pnode.balance < -1:
  cmp dl, -1
  jnl .newindex.remove.16
  ; if pnode.right.balance > 0:
  ldaddr a, [rdi + object.internal.content + word.size * 2]
  cmp byte [rax + object.internal.padding], 0
  jng .newindex.remove.14
  ; pnode.right <- rotate.right pnode.right
  call .rotate.right
  id_from_addr a
  stid [rdi + object.internal.content + word.size * 2], a
  ; new-node <- rotate.left pnode
  mov rax, rdi
  call .rotate.left
  mov rsi, rax
  ; balance.update
  call .balance.update
  jmp .newindex.remove.17
.newindex.remove.14:
  ; new-node <- rotate.left pnode
  mov rax, rdi
  call .rotate.left
  mov rsi, rax
  ; if new-node.balance == 0: new-node.balance <- 1; pnode.balance <- -1
  cmp byte [rax + object.internal.padding], 0
  jne .newindex.remove.15
  mov byte [rax + object.internal.padding], 1
  mov byte [rdi + object.internal.padding], -1
  jmp .newindex.remove.17
.newindex.remove.15:
  ; else: new-node.balance <- 0; pnode.balance <- 0
  mov byte [rax + object.internal.padding], 0
  mov byte [rdi + object.internal.padding], 0
  jmp .newindex.remove.17
.newindex.remove.16:
  ; elif pnode.balance != 0: break
  cmp dl, 0
  jne .newindex.remove.19
.newindex.remove.17:
  ; if new-node != nil:
  test rsi, rsi
  jz .newindex.remove.8
  ; if path.len == 0:
  movid a, bp
  call stack.empty
  testid a
  jz .newindex.remove.18
  ; table.node <- new-node
  id_from_addr si
  stid [rbx + object.content], si
  ; break
  jmp .newindex.5
.newindex.remove.18:
  ; gnode, gdir <- path.top()
  movid a, bp
  mov rdx, 1
  call stack.nth
  addr_from_id d, a
  movid a, bp
  call stack.top
  clear_before_ld c
  movid c, a
  ; if gdir == LEFT: gnode.left <- new-node else: gnode.right <- new-node
  mov rax, rsi
  id_from_addr si
  stid [rdx + object.internal.content + word.size + rcx * word.size], si
  ; if new-node.balance != 0: break
  cmp byte [rax + object.internal.padding], 0
  je .newindex.remove.8
.newindex.remove.19:
  ; di: address of the pnode
  ; bp: stack id indicates path
  ; while path.len != 0:
  movid a, bp
  call stack.empty
  testid a
  jnz .newindex.5
  ; pnode <- path.pop().node
  movid a, bp
  call stack.pop.move
  movid a, bp
  call stack.pop.move
  addr_from_id di, a
  ; pnode.weight <- pnode.left.weight + pnode.right.weight + 1
  ; if pnode.* == nil: pnode.*.weight == 0
  xor edx, edx
  ldaddr a, [rdi + object.internal.content + word.size]
  testaddr a
  jz .newindex.remove.20
  ldaddr c, [rax + object.internal.content]
  add edx, [rcx + object.internal.content + word.size * 2]
.newindex.remove.20:
  ldaddr a, [rdi + object.internal.content + word.size * 2]
  testaddr a
  jz .newindex.remove.21
  ldaddr c, [rax + object.internal.content]
  add edx, [rcx + object.internal.content + word.size * 2]
.newindex.remove.21:
  inc edx
  ldaddr a, [rdi + object.internal.content]
  mov [rax + object.internal.content + word.size * 2], edx
  jmp .newindex.remove.19

  ; in/out: a = address of the node
  ; note: node.left has to exist
.rotate.right:
  pushs c, d, si, di
  ; lnode <- node.left
  ldaddr d, [rax + object.internal.content + word.size]
  ; node.left <- lnode.right
  ldid c, [rdx + object.internal.content + word.size * 2]
  stid [rax + object.internal.content + word.size], c
  ; lnode.right <- node
  mov rsi, rax
  id_from_addr si
  stid [rdx + object.internal.content + word.size * 2], si
  ; lnode.weight <- node.weight
  ldaddr si, [rax + object.internal.content]
  ldaddr di, [rdx + object.internal.content]
  mov ecx, [rsi + object.internal.content + word.size * 2]
  mov [rdi + object.internal.content + word.size * 2], ecx
  ; node.weight <- lnode.weight - lnode.left.weight - 1
  ldaddr di, [rdx + object.internal.content + word.size]
  testaddr di
  jz .rotate.right.1
  sub ecx, [rdi + object.internal.content + word.size * 2]
.rotate.right.1:
  dec ecx
  mov [rsi + object.internal.content + word.size * 2], ecx
  ; return lnode
  mov rax, rdx
  pops c, d, si, di
  ret

  ; in/out: a = address of the node
.rotate.left:
  pushs c, d, si, di
  ; rnode <- node.right
  ldaddr d, [rax + object.internal.content + word.size * 2]
  ; node.right <- rnode.left
  ldid c, [rdx + object.internal.content + word.size]
  stid [rax + object.internal.content + word.size * 2], c
  ; rnode.left <- node
  mov rsi, rax
  id_from_addr si
  stid [rdx + object.internal.content + word.size], si
  ; rnode.weight <- node.weight
  ldaddr si, [rax + object.internal.content]
  ldaddr di, [rdx + object.internal.content]
  mov ecx, [rsi + object.internal.content + word.size * 2]
  mov [rdi + object.internal.content + word.size * 2], ecx
  ; node.weight <- rnode.weight - rnode.right.weight - 1
  ldaddr di, [rdx + object.internal.content + word.size * 2]
  jz .rotate.left.1
  sub ecx, [rdi + object.internal.content + word.size * 2]
.rotate.left.1:
  dec ecx
  mov [rsi + object.internal.content + word.size * 2], ecx
  ; return rnode
  mov rax, rdx
  pops c, d, si, di
  ret

  ; in: a = address of the node
.balance.update:
  pushs d
  cmp byte [rax + object.internal.padding], 1
  jne .balance.update.1
  ldaddr d, [rax + object.internal.content + word.size * 2]
  mov byte [rdx + object.internal.padding], -1
  ldaddr d, [rax + object.internal.content + word.size]
  mov byte [rdx + object.internal.padding], 0
  jmp .balance.update.3
.balance.update.1:
  cmp byte [rax + object.internal.padding], -1
  jne .balance.update.2
  ldaddr d, [rax + object.internal.content + word.size * 2]
  mov byte [rdx + object.internal.padding], 0
  ldaddr d, [rax + object.internal.content + word.size]
  mov byte [rdx + object.internal.padding], 1
  jmp .balance.update.3
.balance.update.2:
  ldaddr d, [rax + object.internal.content + word.size * 2]
  mov byte [rdx + object.internal.padding], 0
  ldaddr d, [rax + object.internal.content + word.size]
  mov byte [rdx + object.internal.padding], 0
.balance.update.3:
  mov byte [rax + object.internal.padding], 0
  pops d
  ret

%endif  ; TABLE_ASM_

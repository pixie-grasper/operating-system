%ifndef SET_ASM_
%define SET_ASM_

; structure
;   set = {root-node | nil, reserved}
;     node = {value, left | nil, right | nil}, extra-field = balance: 8 bits
;     balance = -2 .. 2 (includes internal-state-value)

set:
.new:
  call objects.new.raw
  mov byte [rax + object.class], object.set
  id_from_addr a
  ret

.dispose.raw:
  pushs a
  id_from_addr a
  call .clear
  pops a
  ret

  ; in: a = set id
.clear:
  pushs a, d
  addr_from_id d, a
  ldaddr a, [rdx + object.content]
  testaddr a
  jz .clear.1
  mov rdx, rax
  call .clear.2
.clear.1:
  pops a, d
  ret
.clear.2:
  ldid a, [rdx + object.internal.content]
  call objects.unref
  mov rax, rdx
  ldaddr d, [rax + object.internal.content + word.size]
  testaddr d
  jz .clear.3
  push rax
  call .clear.2
  pop rax
.clear.3:
  ldaddr d, [rax + object.internal.content + word.size * 2]
  testaddr d
  jz .clear.4
  push rax
  call .clear.2
  pop rax
.clear.4:
  call objects.dispose.raw
  ret

  ; in: a = set id
.clear.move:
  pushs a, d
  addr_from_id d, a
  ldaddr a, [rdx + object.content]
  testaddr a
  jz .clear.move.1
  call .clear.move.2
.clear.move.1:
  pops a, d
  ret
.clear.move.2:
  mov rdx, rax
  ldaddr a, [rdx + object.internal.content + word.size]
  testaddr a
  jz .clear.move.3
  push rdx
  call .clear.move.2
  pop rdx
.clear.move.3:
  ldaddr a, [rdx + object.internal.content + word.size * 2]
  testaddr a
  jz .clear.move.4
  push rdx
  call .clear.move.2
  pop rdx
.clear.move.4:
  mov rax, rdx
  call objects.dispose.raw
  ret

  ; @const
  ; in: a = set id
  ; in: d = value id
  ; out: a = false if not found, true if found
.find:
  pushs d, si, di
  addr_from_id si, a
  clear_before_ld a
  ldaddr a, [rsi + object.content]
  testaddr a
  jz .find.4
  movid di, d
.find.1:
  mov rsi, rax
  ldid a, [rsi + object.internal.content]
  movid d, di
  call objects.lt
  testid a
  jz .find.2
  ; [si:o.i.c] < value
  clear_before_ld a
  ldaddr a, [rsi + object.internal.content + word.size * 2]
  testaddr a
  jz .find.4
  jmp .find.1
.find.2:
  movid a, di
  ldid d, [rsi + object.internal.content]
  call objects.lt
  testid a
  jz .find.3
  ; [si:o.i.c] > value
  clear_before_ld a
  ldaddr a, [rsi + object.internal.content + word.size]
  testaddr a
  jz .find.4
  jmp .find.1
.find.3:
  ldt a
  jmp .find.5
.find.4:
  ldnil a
.find.5:
  pops d, si, di
  ret

  ; in: a = set id
  ; in: d = value id
.insert:
  pushs a, c, d, si, di, bp
  addr_from_id c, a
  ldaddr si, [rcx + object.content]
  testaddr si
  jnz .insert.1
  call objects.new.chunk
  stid [rax + object.internal.content], d
  id_from_addr a
  stid [rcx + object.content], a
  movid a, d
  call objects.ref
  jmp .insert.6
.insert.1:
  call stack.new
  movid bp, a
  movid di, d
.insert.2:
  ; c: address of the set
  ; si: address of the current node
  ; di: value id
  ; bp: stack id indicates path
  ldid a, [rsi + object.internal.content]
  movid d, di
  call objects.lt
  testid a
  jz .insert.3
  ; [si:o.i.c.] < value
  ; push node, true
  movid a, bp
  mov rdx, rsi
  id_from_addr d
  call stack.push.move
  ldt d
  call stack.push.move
  ldaddr a, [rsi + object.internal.content + word.size * 2]
  testaddr a
  mov rsi, rax
  ; then, if node->right != nil, continue node <- node->right
  jnz .insert.2
  ; if node->right == nil, node->right <- new and balance
  call objects.new.chunk
  stid [rax + object.internal.content], di
  id_from_addr a
  stid [rsi + object.internal.content + word.size * 2], a
  jmp .insert.4
.insert.3:
  movid a, di
  ldid d, [rsi + object.internal.content]
  call objects.lt
  testid a
  ; if it found in the set, break and end without balance
  jz .insert.5
  ; [si:o.i.c.] > value
  ; push node, false
  movid a, bp
  mov rdx, rsi
  id_from_addr d
  call stack.push.move
  xor edx, edx
  call stack.push.move
  ldaddr a, [rsi + object.internal.content + word.size]
  testaddr a
  mov rsi, rax
  ; then, if node->left != nil, continue node <- node->left
  jnz .insert.2
  call objects.new.chunk
  stid [rax + object.internal.content], di
  id_from_addr a
  stid [rsi + object.internal.content + word.size], a
.insert.4:
  ldid a, [rcx + object.content]
  movid d, bp
  call .insert.balance
  stid [rcx + object.content], a
  movid a, di
  call objects.ref
.insert.5:
  movid a, bp
  call stack.clear.move
  call objects.unref
.insert.6:
  pops a, c, d, si, di, bp
  ret

  ; in: a = set id
  ; in: d = value id
.insert.move:
  pushs a, c, d, si, di, bp
  addr_from_id c, a
  ldaddr si, [rcx + object.content]
  testaddr si
  jnz .insert.move.1
  call objects.new.chunk
  stid [rax + object.internal.content], d
  id_from_addr a
  stid [rcx + object.content], a
  jmp .insert.move.6
.insert.move.1:
  call stack.new
  movid bp, a
  movid di, d
.insert.move.2:
  ; c: address of the set
  ; si: address of the current node
  ; di: value id
  ; bp: stack id indicates path
  ldid a, [rsi + object.internal.content]
  movid d, di
  call objects.lt
  testid a
  jz .insert.move.3
  ; [si:o.i.c.] < value
  ; push node, true
  movid a, bp
  mov rdx, rsi
  id_from_addr d
  call stack.push.move
  ldt d
  call stack.push.move
  ldaddr a, [rsi + object.internal.content + word.size * 2]
  testaddr a
  mov rsi, rax
  ; then, if node->right != nil, continue node <- node->right
  jnz .insert.move.2
  ; if node->right == nil, node->right <- new and balance
  call objects.new.chunk
  stid [rax + object.internal.content], di
  id_from_addr a
  stid [rsi + object.internal.content + word.size * 2], a
  jmp .insert.move.4
.insert.move.3:
  movid a, di
  ldid d, [rsi + object.internal.content]
  call objects.lt
  testid a
  ; if it found in the set, break and end without balance
  jz .insert.move.5
  ; [si:o.i.c.] > value
  ; push node, false
  movid a, bp
  mov rdx, rsi
  id_from_addr d
  call stack.push.move
  xor edx, edx
  call stack.push.move
  ldaddr a, [rsi + object.internal.content + word.size]
  testaddr a
  mov rsi, rax
  ; then, if node->left != nil, continue node <- node->left
  jnz .insert.move.2
  call objects.new.chunk
  stid [rax + object.internal.content], di
  id_from_addr a
  stid [rsi + object.internal.content + word.size], a
.insert.move.4:
  ldid a, [rcx + object.content]
  movid d, bp
  call .insert.balance
  stid [rcx + object.content], a
.insert.move.5:
  movid a, bp
  call stack.clear.move
  call objects.unref
.insert.move.6:
  pops a, c, d, si, di, bp
  ret

  ; in: a: root node id
  ; in: d: stack id indicates path
  ; out: a: root node id
.insert.balance:
  pushs b, c, d, si, di
  ; b: address of the pnode
  ; c: stack id
  ; si: address of the new-node
  ; di: root node id
  movid di, a
  ; while path.len > 0
  movid a, d
  call stack.empty
  test rax, rax
  jnz .insert.balance.8
  movid c, d
  ldnil si
.insert.balance.1:
  ; pnode, dir <- path.pop()
  movid a, c
  call stack.pop.move
  movid d, a
  movid a, c
  call stack.pop.move
  addr_from_id b, a
  ; if dir == LEFT: pnode.balance++ else: pnode.balance--
  ; note: dir == 0(LEFT) or dir == 1(RIGHT).
  add edx, edx
  dec edx
  sub [rbx + object.internal.padding], dl
  ; if pnode.balance == 0: return root
  mov dl, [rbx + object.internal.padding]
  test dl, dl
  jz .insert.balance.8
  ; if pnode.balance > 1:
  cmp dl, 1
  jng .insert.balance.3
  ; if pnode.left.balance < 0:
  ldaddr d, [rbx + object.internal.content + word.size]
  cmp byte [rdx + object.internal.padding], 0
  jnl .insert.balance.2
  ; pnode.left <- rotate.left pnode.left
  mov rax, rdx
  call .rotate.left
  id_from_addr a
  stid [rbx + object.internal.content + word.size], a
  ; new-node <- rotate.right pnode
  mov rax, rbx
  call .rotate.right
  mov rsi, rax
  ; balance.update new-node
  call .balance.update
  jmp .insert.balance.6
  ; else:
.insert.balance.2:
  ; new-node <- rotate.right pnode
  mov rax, rbx
  call .rotate.right
  mov rsi, rax
  ; new-node.balance <- 0
  ; pnode.balance <- 0
  mov byte [rax + object.internal.padding], 0
  mov byte [rbx + object.internal.padding], 0
  ; break
  jmp .insert.balance.6
  ; elif pnode.balance < -1:
.insert.balance.3:
  cmp dl, -1
  jnl .insert.balance.5
  ; if pnode.right.balance > 0:
  ldaddr d, [rbx + object.internal.content + word.size * 2]
  cmp byte [rdx + object.internal.padding], 0
  jng .insert.balance.4
  ; pnode.right <- rotate.right pnode.right
  mov rax, rdx
  call .rotate.right
  id_from_addr a
  stid [rbx + object.internal.content + word.size * 2], a
  ; new-node <- rotate.left pnode
  mov rax, rbx
  call .rotate.left
  mov rsi, rax
  ; balance.update new-node
  call .balance.update
  jmp .insert.balance.6
  ; else:
.insert.balance.4:
  ; new-node <- rotate.left pnode
  mov rax, rbx
  call .rotate.left
  mov rsi, rax
  ; new-node.balance <- 0
  ; pnode.balance <- 0
  mov byte [rax + object.internal.padding], 0
  mov byte [rbx + object.internal.padding], 0
  ; break
  jmp .insert.balance.6
.insert.balance.5:  ; wend
  movid a, c
  call stack.empty
  testid a
  jz .insert.balance.1
.insert.balance.6:
  ; if path.len > 0:
  movid a, c
  call stack.empty
  testid a
  jnz .insert.balance.7
  ; gnode, gdir <- path.pop()
  movid a, c
  call stack.pop.move
  clear_before_ld d
  movid d, a
  movid a, c
  call stack.pop.move
  addr_from_id b, a
  ; if gdir == LEFT: gnode.left <- new-node else: gnode.right <- new-node
  id_from_addr si
  stid [rbx + object.internal.content + word.size + rdx * word.size], si
  jmp .insert.balance.8
.insert.balance.7:
  ; elif new-node is not nil: return new-node
  id_from_addr si
  jz .insert.balance.8
  movid di, si
.insert.balance.8:
  movid a, di
  pops b, c, d, si, di
  ret

  ; in: a = set id
  ; in: d = value id
.remove:
  pushs a, b, c, d, si, di, bp
  addr_from_id c, a
  ; if root-node == nil: do nothing
  ldaddr si, [rcx + object.content]
  testaddr si
  jz .remove.12
  call stack.new
  movid bp, a
  movid di, d
  ; c: address of the set
  ; si: address of the current node
  ; di: value id
  ; bp: stack id indicates path
.remove.1:
  ; while node != nil:
  ldid a, [rsi + object.internal.content]
  movid d, di
  call objects.lt
  testid a
  jz .remove.2
  ; [si:o.i.c.] < value
  ; push node, true
  movid a, bp
  mov rdx, rsi
  id_from_addr d
  call stack.push.move
  ldt d
  call stack.push.move
  ; node <- node.right
%ifdef OBJECT_32_BYTES
  ldaddr si, [rsi + object.internal.content + word.size * 2]
%else  ; OBJECT_32_BYTES
  ldid a, [rsi + object.internal.content + word.size * 2]
  addr_from_id si, a
%endif  ; OBJECT_32_BYTES
  jmp .remove.3
.remove.2:
  movid a, di
  ldid d, [rsi + object.internal.content]
  call objects.lt
  testid a
  jz .remove.4
  ; [si:o.i.c] > value
  ; push node, false
  movid a, bp
  mov rdx, rsi
  id_from_addr d
  call stack.push.move
  ldnil d
  call stack.push.move
  ; node <- node.left
%ifdef OBJECT_32_BYTES
  ldaddr si, [rsi + object.internal.content + word.size]
%else  ; OBJECT_32_BYTES
  ldid a, [rsi + object.internal.content + word.size]
  addr_from_id si, a
%endif  ; OBJECT_32_BYTES
.remove.3:
  ; wend
  ; test rsi, rsi ;  test not needed; the shl sets/clears flags.z
  jnz .remove.1
  jmp .remove.11  ; if not found: dispose stack and return.
.remove.4:
  ; [si:o.i.c] == value
  ldid a, [rsi + object.internal.content]
  call objects.unref
  ; if it has childlen:
  ldid a, [rsi + object.internal.content + word.size]
  testid a
  jz .remove.7
  ldid a, [rsi + object.internal.content + word.size * 2]
  testid a
  jz .remove.7
  ; find node.right.left.left.left. ... .left that is not nil
  ; push node, true
  movid a, bp
  mov rdx, rsi
  id_from_addr d
  call stack.push.move
  ldt d
  call stack.push.move
  ; that <- node.right
  ldaddr b, [rsi + object.internal.content + word.size * 2]
.remove.5:
  ; while that.left != nil:
  ldid a, [rbx + object.internal.content + word.size]
  testid a
  jz .remove.6
  ; push that, false
  movid a, bp
  mov rdx, rbx
  id_from_addr d
  call stack.push.move
  ldnil d
  call stack.push.move
  ; that <- that.left
%ifdef OBJECT_32_BYTES
  ldaddr b, [rbx + object.internal.content + word.size]
%else  ; OBJECT_32_BYTES
  ldid a, [rbx + object.internal.content + word.size]
  addr_from_id b, a
%endif  ; OBJECT_32_BYTES
  jmp .remove.5
.remove.6:
  ; node.value <- that.value
  ldid d, [rbx + object.internal.content]
  stid [rsi + object.internal.content], d
  ; node <- that
  mov rsi, rbx
.remove.7:
  ; if path.len != 0: pnode <- path.top().node else: pnode <- nil
  ldnil b
  movid a, bp
  call stack.empty
  testid a
  jnz .remove.8
  movid a, bp
  mov rdx, 1
  call stack.nth
  addr_from_id b, a
.remove.8:
  ; now, (node.left && node.right) == nil
  ; if node.left == nil: node <- node.right else: node <- node.left
  ldid d, [rsi + object.internal.content + word.size]
  testid d
  jnz .remove.9
  ldid d, [rsi + object.internal.content + word.size * 2]
.remove.9:
  mov rax, rsi
  call objects.dispose.raw
  ; if root-node removed, root-node <- node
  test rbx, rbx
  jnz .remove.10
  stid [rcx + object.content], d
  jmp .remove.11
.remove.10:
  ; if dir == LEFT: pnode.left <- node else: pnode.right <- node
  movid a, bp
  call stack.top  ; it's safe; if stack is empty, ebx == nil
  clear_before_ld di
  movid di, a
  stid [rbx + object.internal.content + word.size + rdi * word.size], d
  ldid a, [rcx + object.content]
  movid d, bp
  call .remove.balance
  stid [rcx + object.content], a
.remove.11:
  movid a, bp
  call stack.clear.move
  call objects.unref
.remove.12:
  pops a, b, c, d, si, di, bp
  ret

  ; in: a = set id
  ; in: d = value id
.remove.move:
  pushs a, b, c, d, si, di, bp
  addr_from_id c, a
  ; if root-node == nil: do nothing
  ldaddr si, [rcx + object.content]
  testaddr si
  jz .remove.move.12
  call stack.new
  movid bp, a
  movid di, d
  ; c: address of the set
  ; si: address of the current node
  ; di: value id
  ; bp: stack id indicates path
.remove.move.1:
  ; while node != nil:
  ldid a, [rsi + object.internal.content]
  movid d, di
  call objects.lt
  testid a
  jz .remove.move.2
  ; [si:o.i.c.] < value
  ; push node, true
  movid a, bp
  mov rdx, rsi
  id_from_addr d
  call stack.push.move
  ldt d
  call stack.push.move
  ; node <- node.right
%ifdef OBJECT_32_BYTES
  ldaddr si, [rsi + object.internal.content + word.size]
%else  ; OBJECT_32_BYTES
  ldid a, [rsi + object.internal.content + word.size]
  addr_from_id si, a
%endif  ; OBJECT_32_BYTES
  jmp .remove.move.3
.remove.move.2:
  movid a, di
  ldid d, [rsi + object.internal.content]
  call objects.lt
  testid a
  jz .remove.move.4
  ; [si:o.i.c] > value
  ; push node, false
  movid a, bp
  mov rdx, rsi
  id_from_addr d
  call stack.push.move
  ldnil d
  call stack.push.move
  ; node <- node.left
%ifdef OBJECT_32_BYTES
  ldaddr si, [rsi + object.internal.content + word.size]
%else  ; OBJECT_32_BYTES
  ldid a, [rsi + object.internal.content + word.size]
  addr_from_id si, a
%endif  ; OBJECT_32_BYTES
.remove.move.3:
  ; wend
  ; test rsi, rsi ;  test not needed; the shl sets/clears flags.z
  jnz .remove.move.1
  jmp .remove.move.11  ; if not found: dispose stack and return.
.remove.move.4:
  ; [si:o.i.c] == value
  ; if it has childlen:
  ldid a, [rsi + object.internal.content + word.size]
  testid a
  jz .remove.move.7
  ldid a, [rsi + object.internal.content + word.size * 2]
  testid a
  jz .remove.move.7
  ; find node.right.left.left.left. ... .left that is not nil
  ; push node, true
  movid a, bp
  mov rdx, rsi
  id_from_addr d
  call stack.push.move
  ldt d
  call stack.push.move
  ; that <- node.right
  ldaddr b, [rsi + object.internal.content + word.size * 2]
.remove.move.5:
  ; while that.left != nil:
  ldid a, [rbx + object.internal.content + word.size]
  testid a
  jz .remove.move.6
  ; push that, false
  movid a, bp
  mov rdx, rbx
  id_from_addr d
  call stack.push.move
  ldnil d
  call stack.push.move
  ; that <- that.left
%ifdef OBJECT_32_BYTES
  ldaddr b, [rbx + object.internal.content + word.size]
%else  ; OBJECT_32_BYTES
  ldid a, [rbx + object.internal.content + word.size]
  addr_from_id b, a
%endif  ; OBJECT_32_BYTES
  jmp .remove.move.5
.remove.move.6:
  ; node.value <- that.value
  ldid d, [rbx + object.internal.content]
  stid [rsi + object.internal.content], d
  ; node <- that
  mov rsi, rbx
.remove.move.7:
  ; if path.len != 0: pnode <- path.top().node else: pnode <- nil
  ldnil b
  movid a, bp
  call stack.empty
  testid a
  jnz .remove.move.8
  movid a, bp
  ldt d
  call stack.nth
  addr_from_id b, a
.remove.move.8:
  ; now, (node.left && node.right) == nil
  ; if node.left == nil: node <- node.right else: node <- node.left
  ldid d, [rsi + object.internal.content + word.size]
  testid d
  jnz .remove.move.9
  ldid d, [rsi + object.internal.content + word.size * 2]
.remove.move.9:
  mov rax, rsi
  call objects.dispose.raw
  ; if root-node removed, root-node <- node
  test rbx, rbx
  jnz .remove.move.10
  stid [rcx + object.content], d
  jmp .remove.move.11
.remove.move.10:
  ; if dir == LEFT: pnode.left <- node else: pnode.right <- node
  movid a, bp
  call stack.top  ; it's safe; if stack is empty, ebx == nil
  clear_before_ld di
  movid di, a
  stid [rbx + object.internal.content + word.size + rdi * word.size], d
  ldid a, [rcx + object.content]
  movid d, bp
  call .remove.balance
  stid [rcx + object.content], a
.remove.move.11:
  movid a, bp
  call stack.clear.move
  call objects.unref
.remove.move.12:
  pops a, b, c, d, si, di, bp
  ret

  ; in: a: root node id
  ; in: d: stack id indicates path
  ; out: a: root node id
.remove.balance:
  pushs b, c, si, di
  ; b: address of the pnode
  ; c: stack id
  ; si: address of the new-node
  ; di: root node id
  movid di, a
  movid c, d
  ; while path.len > 0
.remove.balance.1:
  movid a, c
  call stack.empty
  testid a
  jnz .remove.balance.10
  ; new-node <- nil
  ldnil si
  ; pnode, dir <- path.pop()
  movid a, c
  call stack.pop.move
  movid d, a
  movid a, c
  call stack.pop.move
  addr_from_id b, a
  ; if dir == LEFT: pnode.balance-- else: pnode.balance++
  add edx, edx
  dec edx
  add [rbx + object.internal.padding], dl
  ; if pnode.balance > 1:
  mov dl, [rbx + object.internal.padding]
  cmp dl, 1
  jng .remove.balance.4
  ; if pnode.left.balance < 0:
  ldaddr d, [rbx + object.internal.content + word.size]
  cmp byte [rdx + object.internal.padding], 0
  jnl .remove.balance.2
  ; pnode.left <- rotate.left pnode.left
  mov rax, rdx
  call .rotate.left
  id_from_addr a
  stid [rbx + object.internal.content + word.size], a
  ; new-node <- rotate.right pnode
  mov rax, rbx
  call .rotate.right
  mov rsi, rax
  ; balance.update new-node
  call .balance.update
  jmp .remove.balance.8
.remove.balance.2:
  ; new-node <- rotate.right pnode
  mov rax, rbx
  call .rotate.right
  mov rsi, rax
  ; if new-node.balance == 0: new-node.balance <- -1; pnode.balance <- 1
  cmp byte [rax + object.internal.padding], 0
  jne .remove.balance.3
  mov byte [rax + object.internal.padding], -1
  mov byte [rbx + object.internal.padding], 1
  jmp .remove.balance.8
.remove.balance.3:
  ; else: new-node.balance <- 0; pnode.balance <- 0
  mov byte [rax + object.internal.padding], 0
  mov byte [rbx + object.internal.padding], 0
  jmp .remove.balance.8
.remove.balance.4:
  ; elif pnode.balance < -1:
  cmp dl, -1
  jnl .remove.balance.7
  ; if pnode.right.balance > 0:
  ldaddr d, [rbx + object.internal.content + word.size * 2]
  cmp byte [rdx + object.internal.padding], 0
  jng .remove.balance.5
  ; pnode.right <- rotate.right pnode.right
  mov rax, rdx
  call .rotate.right
  id_from_addr a
  stid [rbx + object.internal.content + word.size * 2], a
  ; new-node <- rotate.left pnode
  mov rax, rbx
  call .rotate.left
  mov rsi, rax
  ; balance.update new-node
  call .balance.update
  jmp .remove.balance.8
.remove.balance.5:
  ; new-node <- rotate.left pnode
  mov rax, rbx
  call .rotate.left
  mov rsi, rax
  ; if new-node.balance == 0: new-node.balance <- 1; pnode.balance <- -1
  cmp byte [rax + object.internal.padding], 0
  jne .remove.balance.6
  mov byte [rax + object.internal.padding], 1
  mov byte [rbx + object.internal.padding], -1
  jmp .remove.balance.8
.remove.balance.6:
  ; else: new-node.balance <- 0; pnode.balance <- 0
  mov byte [rax + object.internal.padding], 0
  mov byte [rbx + object.internal.padding], 0
  jmp .remove.balance.8
.remove.balance.7:
  ; elif pnode.balance != 0: break
  cmp dl, 0
  jne .remove.balance.10
.remove.balance.8:
  ; if new-node != nil:
  test rsi, rsi
  jz .remove.balance.1
  ; if path.len == 0: return new-node
  movid a, c
  call stack.empty
  testid a
  jz .remove.balance.9
  id_from_addr si
  movid di, si
  jmp .remove.balance.10
.remove.balance.9:
  ; gnode, gdir <- path.top()
  movid a, c
  mov rdx, 1
  call stack.nth
  addr_from_id b, a
  movid a, c
  call stack.top
  ; if gdir == LEFT: gnode.left <- new-node else: gnode.right <- new-node
  clear_before_ld d
  movid d, a
  mov rax, rsi
  id_from_addr a
  stid [rbx + object.internal.content + word.size + rdx * word.size], a
  ; if new-node.balance != 0: break
  cmp byte [rsi + object.internal.padding], 0
  je .remove.balance.1
.remove.balance.10:
  movid a, di
  pops b, c, si, di
  ret

  ; in/out: a = address of the node
.rotate.right:
  pushs c, d
  ; lnode <- node.left
  ldaddr d, [rax + object.internal.content + word.size]
  ; node.left <- lnode.right
  ldid c, [rdx + object.internal.content + word.size * 2]
  stid [rax + object.internal.content + word.size], c
  ; lnode.right <- node
  id_from_addr a
  stid [rdx + object.internal.content + word.size * 2], a
  ; return lnode
  mov rax, rdx
  pops c, d
  ret

  ; in/out: a = address of the node
.rotate.left:
  pushs c, d
  ; rnode <- node.right
  ldaddr d, [rax + object.internal.content + word.size * 2]
  ; node.right <- rnode.left
  ldid c, [rdx + object.internal.content + word.size]
  stid [rax + object.internal.content + word.size * 2], c
  ; rnode.left <- node
  id_from_addr a
  stid [rdx + object.internal.content + word.size], a
  ; return rnode
  mov rax, rdx
  pops c, d
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

%endif  ; SET_ASM_

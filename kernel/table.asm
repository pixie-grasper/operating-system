%ifndef TABLE_ASM_
%define TABLE_ASM_

; structure
;   table = {root-node | nil, reserved}
;     node = {internal-node, left | nil, right | nil}, extra-field = balance: 8 bits
;     internal-node = {key, value, weight}
;     balance = -2 .. 2 (includes internal-state-value)

table:
.new:
  call objects.new.raw
  mov byte [rax + object.class], object.table
  shr rax, 4
  ret

.dispose.raw:
  push rax
  shr rax, 4
  call .clear
  pop rax
  ret

  ; in: a = table id
.clear:
  push rax
  push rcx
  push rdx
  xor rdx, rdx
  mov edx, eax
  shl rdx, 4
  xor rax, rax
  mov eax, [rdx + object.content]
  shl rax, 4
  jz .clear.1
  mov rdx, rax
  call .clear.2
.clear.1:
  pop rdx
  pop rcx
  pop rax
  ret
.clear.2:
  xor rcx, rcx
  mov ecx, [rdx + object.internal.content]
  shl rcx, 4
  mov eax, [rcx + object.internal.content]
  call objects.unref
  mov eax, [rcx + object.internal.content + 4]
  call objects.unref
  mov rax, rcx
  call objects.dispose.raw
  mov rax, rdx
  xor rdx, rdx
  mov edx, [rax + object.internal.content + 4]
  shl rdx, 4
  jz .clear.3
  push rax
  call .clear.2
  pop rax
.clear.3:
  xor rdx, rdx
  mov edx, [rax + object.internal.content + 8]
  shl rdx, 4
  jz .clear.4
  push rax
  call .clear.2
  pop rax
.clear.4:
  call objects.dispose.raw
  ret

  ; @const
  ; in: a = table id
  ; in: d = key id
  ; out: a = value id or nil
.index:
  push rcx
  push rdx
  push rsi
  push rdi
  xor rdi, rdi
  mov edi, eax
  shl rdi, 4
  xor rsi, rsi
  mov esi, [rdi + object.content]
  shl rsi, 4
  jz .index.4
  mov edi, edx
.index.1:
  ; si: address of the current node
  ; di: key id
  xor rcx, rcx
  mov ecx, [rsi + object.internal.content]
  shl rcx, 4
  mov eax, [rcx + object.internal.content]
  mov edx, edi
  call objects.lt
  test eax, eax
  jz .index.2
  ; [si:o.i.c].key < key
  xor rax, rax
  mov eax, [rsi + object.internal.content + 8]
  shl rax, 4
  jz .index.4
  mov rsi, rax
  jmp .index.1
.index.2:
  mov eax, edi
  mov edx, [rcx + object.internal.content]
  call objects.lt
  jz .index.3
  ; [si:o.i.c].key > key
  xor rax, rax
  mov eax, [rsi + object.internal.content + 4]
  shl rax, 4
  jz .index.4
  mov rsi, rax
  jmp .index.1
.index.3:
  mov eax, [rcx + object.internal.content + 4]
  jmp .index.5
.index.4:
  xor rax, rax
.index.5:
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  ret

  ; in: a = table id
  ; in: d = key id
  ; in: c = value id or nil
.newindex:
  push rax
  push rbx
  push rcx
  push rdx
  push rsi
  push rdi
  push rbp
  push r8
  xor rbx, rbx
  mov ebx, eax
  shl rbx, 4
  mov edi, edx
  call stack.new
  mov ebp, eax
  xor rsi, rsi
  mov esi, [rbx + object.content]
  shl rsi, 4
  ; b: address of the table
  ; c: value id or nil
  ; si: address of the current node
  ; di: key id
  ; bp: stack id
.newindex.1:
  jz .newindex.4
  xor r8, r8
  mov r8d, [rsi + object.internal.content]
  shl r8, 4
  mov eax, [r8 + object.internal.content]
  mov edx, edi
  call objects.lt
  test eax, eax
  jz .newindex.2
  ; [si:o.i.c].key < key
  ; push node, true
  mov eax, ebp
  mov rdx, rsi
  shr rdx, 4
  call stack.push.move
  mov edx, 1
  call stack.push.move
  ; node <- node.right
  xor rax, rax
  mov eax, [rsi + object.internal.content + 8]
  shl rax, 4
  mov rsi, rax
  jmp .newindex.1
.newindex.2:
  mov eax, edi
  mov edx, [r8 + object.internal.content]
  call objects.lt
  test eax, eax
  jz .newindex.3
  ; [si:o.i.c].key > key
  ; push node, false
  mov eax, ebp
  mov rdx, rsi
  shr rdx, 4
  call stack.push.move
  xor edx, edx
  call stack.push.move
  ; node <- node.left
  xor rax, rax
  mov eax, [rsi + object.internal.content + 4]
  shl rax, 4
  mov rsi, rax
  jmp .newindex.1
.newindex.3:
  ; if value == nil: remove pair form the table
  test ecx, ecx
  jz .newindex.remove.1
  ; else: update pair
  xor rdx, rdx
  mov edx, [rsi + object.internal.content]
  shl rdx, 4
  mov eax, [rdx + object.internal.content + 4]
  cmp eax, ecx
  je .newindex.5
  mov eax, ecx
  call objects.ref
  mov eax, [rdx + object.internal.content + 4]
  call objects.unref
  mov [rdx + object.internal.content + 4], ecx
  jmp .newindex.5
.newindex.4:
  ; if value == nil: do nothing
  test ecx, ecx
  jz .newindex.5
  ; else: insert the pair
  call objects.new.chunk
  mov rsi, rax
  call objects.new.chunk
  mov [rax + object.internal.content], edi
  mov [rax + object.internal.content + 4], ecx
  mov dword [rax + object.internal.content + 8], 1
  shr rax, 4
  mov [rsi + object.internal.content], eax
  mov eax, edi
  call objects.ref
  mov eax, ecx
  call objects.ref
  jmp .newindex.insert.1
.newindex.5:
  mov eax, ebp
  call stack.clear.move
  call objects.unref
  pop r8
  pop rbp
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  pop rax
  ret

.newindex.insert.1:
  ; b: address of the table
  ; si: address of the dangling node (at the top of the loop) or new-node
  ; bp: stack id indicates path
  ; while path.len != 0:
  mov eax, ebp
  call stack.empty
  test eax, eax
  jnz .newindex.insert.8
  ; pnode, pdir <- path.pop()
  mov eax, ebp
  call stack.pop.move
  xor rdx, rdx
  mov edx, eax
  mov eax, ebp
  call stack.pop.move
  xor rcx, rcx
  mov ecx, eax
  shl rcx, 4
  ; if pdir == LEFT: pnode.left <- node else: pnode.right <- node
  shr rsi, 4
  mov [rcx + object.internal.content + 4 + rdx * 4], esi
  ; if pdir == LEFT: pnode.balance++ else: pnode.balance--
  add edx, edx
  dec edx
  sub [rcx + object.internal.padding], dl
  ; pnode.weight <- pnode.left.weight + pnode.right.weight + 1
  ; if pnode.* == nil: pnode.*.weight == 0
  xor rdx, rdx
  xor rax, rax
  mov eax, [rcx + object.internal.content + 4]
  shl rax, 4
  jz .newindex.insert.2
  xor rsi, rsi
  mov esi, [rax + object.internal.content]
  shl rsi, 4
  add edx, [rsi + object.internal.content + 8]
.newindex.insert.2:
  xor rax, rax
  mov eax, [rcx + object.internal.content + 8]
  shl rax, 4
  jz .newindex.insert.3
  xor rsi, rsi
  mov esi, [rax + object.internal.content]
  shl rsi, 4
  add edx, [rsi + object.internal.content + 8]
.newindex.insert.3:
  inc edx
  xor rax, rax
  mov eax, [rcx + object.internal.content]
  shl rax, 4
  mov [rax + object.internal.content + 8], edx
  ; if pnode.balance == 0: break
  mov dl, [rcx + object.internal.padding]
  test dl, dl
  jz .newindex.insert.13
  ; if pnode.balance > 1:
  cmp dl, 1
  jng .newindex.insert.5
  ; if pnode.left.balance < 0:
  xor rax, rax
  mov eax, [rcx + object.internal.content + 4]
  shl rax, 4
  cmp byte [rax + object.internal.padding], 0
  jnl .newindex.insert.4
  ; pnode.left <- rotate.left pnode.left
  call .rotate.left
  shr rax, 4
  mov [rcx + object.internal.content + 4], eax
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
  xor rax, rax
  mov eax, [rcx + object.internal.content + 8]
  shl rax, 4
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
  mov eax, ebp
  call stack.empty
  test eax, eax
  jz .newindex.insert.9
.newindex.insert.8:
  shr rsi, 4
  mov [rbx + object.content], esi
  jmp .newindex.5
.newindex.insert.9:
  ; else:
  ; pnode, pdir <- path.pop()
  mov eax, ebp
  call stack.pop.move
  xor rdx, rdx
  mov edx, eax
  mov eax, ebp
  call stack.pop.move
  xor rcx, rcx
  mov ecx, eax
  shl rcx, 4
  ; if pdir == LEFT: pnode.left <- new-node else: pnode.right <- new-node
  shr rsi, 4
  mov [rcx + object.internal.content + 4 + rdx * 4], esi
.newindex.insert.10:
  ; b: address of the table
  ; c: address of the pnode
  ; bp: stack id indicates path
  ; while true:
  ; pnode.weight <- pnode.left.weight + pnode.right.weight + 1
  ; if pnode.* == nil: pnode.*.weight == 0
  xor rdx, rdx
  xor rax, rax
  mov eax, [rcx + object.internal.content + 4]
  shl rax, 4
  jz .newindex.insert.11
  xor rsi, rsi
  mov esi, [rax + object.internal.content]
  shl rsi, 4
  add edx, [rsi + object.internal.content + 8]
.newindex.insert.11:
  xor rax, rax
  mov eax, [rcx + object.internal.content + 8]
  shl rax, 4
  jz .newindex.insert.12
  xor rsi, rsi
  mov esi, [rax + object.internal.content]
  shl rsi, 4
  add edx, [rsi + object.internal.content + 8]
.newindex.insert.12:
  inc edx
  xor rax, rax
  mov eax, [rcx + object.internal.content]
  shl rax, 4
  mov [rax + object.internal.content + 8], edx
.newindex.insert.13:
  ; if path.len == 0: break
  mov eax, ebp
  call stack.empty
  test eax, eax
  jnz .newindex.5
  ; pnode, pdir <- path.pop()
  mov eax, ebp
  call stack.pop.move
  mov eax, ebp
  call stack.pop.move
  xor rcx, rcx
  mov ecx, eax
  shl rcx, 4
  jmp .newindex.insert.10

.newindex.remove.1:
  ; b: address of the table
  ; si: address of the current node
  ; bp: stack id
  xor rdx, rdx
  mov edx, [rsi + object.internal.content]
  shl rdx, 4
  xor rax, rax
  mov eax, [rdx + object.internal.content]
  call objects.unref
  mov eax, [rdx + object.internal.content + 4]
  call objects.unref
  ; if it has childlen:
  mov eax, [rsi + object.internal.content + 4]
  test eax, eax
  jz .newindex.remove.4
  mov eax, [rsi + object.internal.content + 8]
  test eax, eax
  jz .newindex.remove.4
  ; find node.right.left.left.left. ... .left that is not nil
  ; push node, true
  mov eax, ebp
  mov rdx, rsi
  shr rdx, 4
  call stack.push.move
  mov edx, 1
  call stack.push.move
  ; that <- node.right
  xor rdi, rdi
  mov edi, [rsi + object.internal.content + 8]
  shl rdi, 4
.newindex.remove.2:
  ; while that.left != nil:
  mov eax, [rdi + object.internal.content + 4]
  test eax, eax
  jz .newindex.remove.3
  ; push that, false
  mov eax, ebp
  mov rdx, rdi
  shr rdx, 4
  call stack.push.move
  xor edx, edx
  call stack.push.move
  ; that <- that.left
  mov eax, [rdi + object.internal.content + 4]
  xor rdi, rdi
  mov edi, eax
  shl rdi, 4
  jmp .newindex.remove.2
.newindex.remove.3:
  ; node.key, node.value <- that.key, that.value
  xor rax, rax
  mov eax, [rdi + object.internal.content]
  shl rax, 4
  xor rcx, rcx
  mov ecx, [rsi + object.internal.content]
  shl rcx, 4
  mov edx, [rax + object.internal.content]
  mov [rcx + object.internal.content], edx
  mov edx, [rax + object.internal.content + 4]
  mov [rcx + object.internal.content + 4], edx
  ; node <- that
  mov rsi, rdi
.newindex.remove.4:
  ; if path.len != 0: pnode <- path.top().node else: pnode <- nil
  xor rdi, rdi
  mov eax, ebp
  call stack.empty
  test eax, eax
  jnz .newindex.remove.5
  mov eax, ebp
  mov rdx, 1
  call stack.nth
  mov edi, eax
  shl rdi, 4
.newindex.remove.5:
  ; now, (node.left && node.right) == nil
  ; if node.left == nil: node <- node.right else: node <- node.left
  xor rdx, rdx
  mov edx, [rsi + object.internal.content + 4]
  test edx, edx
  jnz .newindex.remove.6
  mov edx, [rsi + object.internal.content + 8]
.newindex.remove.6:
  xor rax, rax
  mov eax, [rsi + object.internal.content]
  shl rax, 4
  call objects.dispose.raw
  mov rax, rsi
  call objects.dispose.raw
  ; if root-node removed: root-node <- node
  test rdi, rdi
  jnz .newindex.remove.7
  mov [rbx + object.content], edx
  jmp .newindex.5
  ; table.node <- nil
.newindex.remove.7:
  ; if path.top().dir == LEFT: pnode.left <- node else: pnode.right <- node
  mov eax, ebp
  call stack.top
  xor rcx, rcx
  mov ecx, eax
  mov eax, [rdi + object.internal.content + 4 + rcx * 4]
  mov [rdi + object.internal.content + 4 + rcx * 4], edx
  xor rsi, rsi
  mov esi, eax
  shl rsi, 4
  xor rax, rax
  mov eax, [rsi + object.internal.content]
  shl rax, 4
  call objects.dispose.raw
  mov rax, rsi
  call objects.dispose.raw
.newindex.remove.8:
  ; b: address of the table
  ; si: address of the new-node
  ; di: address of the pnode
  ; bp: stack id indicates path
  ; while path.len != 0:
  mov eax, ebp
  call stack.empty
  test eax, eax
  jnz .newindex.5
  ; new-node <- nil
  xor rsi, rsi
  ; pnode, pdir <- path.pop()
  mov eax, ebp
  call stack.pop.move
  mov edx, eax
  mov eax, ebp
  call stack.pop.move
  xor rdi, rdi
  mov edi, eax
  shl rdi, 4
  ; if pdir == LEFT: pnode.balance-- else: pnode.balance++
  add edx, edx
  dec edx
  add [rdi + object.internal.padding], dl
  ; pnode.weight <- pnode.left.weight + pnode.right.weight + 1
  ; if pnode.* == nil: pnode.*.weight == 0
  xor edx, edx
  xor rax, rax
  mov eax, [rdi + object.internal.content + 4]
  shl rax, 4
  jz .newindex.remove.9
  xor rcx, rcx
  mov ecx, [rax + object.internal.content]
  shl rcx, 4
  add edx, [rcx + object.internal.content + 8]
.newindex.remove.9:
  xor rax, rax
  mov eax, [rdi + object.internal.content + 8]
  shl rax, 4
  jz .newindex.remove.10
  xor rcx, rcx
  mov ecx, [rax + object.internal.content]
  shl rcx, 4
  add edx, [rcx + object.internal.content + 8]
.newindex.remove.10:
  inc edx
  xor rax, rax
  mov eax, [rdi + object.internal.content]
  shl rax, 4
  mov [rax + object.internal.content + 8], edx
  ; if pnode.balance > 1:
  mov dl, [rdi + object.internal.padding]
  cmp dl, 1
  jng .newindex.remove.13
  ; if pnode.left.balance < 0:
  xor rax, rax
  mov eax, [rdi + object.internal.content + 4]
  shl rax, 4
  cmp byte [rax + object.internal.padding], 0
  jnl .newindex.remove.11
  ; pnode.left <- rotate.left pnode.left
  call .rotate.left
  shr rax, 4
  mov [rdi + object.internal.content + 4], eax
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
  xor rax, rax
  mov eax, [rdi + object.internal.content + 8]
  shl rax, 4
  cmp byte [rax + object.internal.padding], 0
  jng .newindex.remove.14
  ; pnode.right <- rotate.right pnode.right
  call .rotate.right
  shr rax, 4
  mov [rdi + object.internal.content + 8], eax
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
  mov eax, ebp
  call stack.empty
  test eax, eax
  jz .newindex.remove.18
  ; table.node <- new-node
  shr rsi, 4
  mov [rbx + object.content], esi
  ; break
  jmp .newindex.5
.newindex.remove.18:
  ; gnode, gdir <- path.top()
  mov eax, ebp
  mov rdx, 1
  call stack.nth
  xor rdx, rdx
  mov edx, eax
  shl rdx, 4
  mov eax, ebp
  call stack.top
  xor rcx, rcx
  mov ecx, eax
  ; if gdir == LEFT: gnode.left <- new-node else: gnode.right <- new-node
  mov rax, rsi
  shr rsi, 4
  mov [rdx + object.internal.content + 4 + rcx * 4], esi
  ; if new-node.balance != 0: break
  cmp byte [rax + object.internal.padding], 0
  je .newindex.remove.8
.newindex.remove.19:
  ; di: address of the pnode
  ; bp: stack id indicates path
  ; while path.len != 0:
  mov eax, ebp
  call stack.empty
  test eax, eax
  jnz .newindex.5
  ; pnode <- path.pop().node
  mov eax, ebp
  call stack.pop.move
  mov eax, ebp
  call stack.pop.move
  xor rdi, rdi
  mov edi, eax
  shl rdi, 4
  ; pnode.weight <- pnode.left.weight + pnode.right.weight + 1
  ; if pnode.* == nil: pnode.*.weight == 0
  xor edx, edx
  xor rax, rax
  mov eax, [rdi + object.internal.content + 4]
  shl rax, 4
  jz .newindex.remove.20
  xor rcx, rcx
  mov ecx, [rax + object.internal.content]
  shl rcx, 4
  add edx, [rcx + object.internal.content + 8]
.newindex.remove.20:
  xor rax, rax
  mov eax, [rdi + object.internal.content + 8]
  shl rax, 4
  jz .newindex.remove.21
  xor rcx, rcx
  mov ecx, [rax + object.internal.content]
  shl rcx, 4
  add edx, [rcx + object.internal.content + 8]
.newindex.remove.21:
  inc edx
  xor rax, rax
  mov eax, [rdi + object.internal.content]
  shl rax, 4
  mov [rax + object.internal.content + 8], edx
  jmp .newindex.remove.19

  ; in/out: a = address of the node
  ; note: node.left has to exist
.rotate.right:
  push rcx
  push rdx
  push rsi
  push rdi
  ; lnode <- node.left
  xor rdx, rdx
  mov edx, [rax + object.internal.content + 4]
  shl rdx, 4
  ; node.left <- lnode.right
  mov ecx, [rdx + object.internal.content + 8]
  mov [rax + object.internal.content + 4], ecx
  ; lnode.right <- node
  mov rsi, rax
  shr rsi, 4
  mov [rdx + object.internal.content + 8], esi
  ; lnode.weight <- node.weight
  xor rsi, rsi
  mov esi, [rax + object.internal.content]
  shl rsi, 4
  xor rdi, rdi
  mov edi, [rdx + object.internal.content]
  shl rdi, 4
  mov ecx, [rsi + object.internal.content + 8]
  mov [rdi + object.internal.content + 8], ecx
  ; node.weight <- lnode.weight - lnode.left.weight - 1
  xor rdi, rdi
  mov edi, [rdx + object.internal.content + 4]
  shl rdi, 4
  jz .rotate.right.1
  sub ecx, [rdi + object.internal.content + 8]
.rotate.right.1:
  dec ecx
  mov [rsi + object.internal.content + 8], ecx
  ; return lnode
  mov rax, rdx
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  ret

  ; in/out: a = address of the node
.rotate.left:
  push rcx
  push rdx
  push rsi
  push rdi
  ; rnode <- node.right
  xor rdx, rdx
  mov edx, [rax + object.internal.content + 8]
  shl rdx, 4
  ; node.right <- rnode.left
  mov ecx, [rdx + object.internal.content + 4]
  mov [rax + object.internal.content + 8], ecx
  ; rnode.left <- node
  mov rsi, rax
  shr rsi, 4
  mov [rdx + object.internal.content + 4], esi
  ; rnode.weight <- node.weight
  xor rsi, rsi
  mov esi, [rax + object.internal.content]
  shl rsi, 4
  xor rdi, rdi
  mov edi, [rdx + object.internal.content]
  shl rdi, 4
  mov ecx, [rsi + object.internal.content + 8]
  mov [rdi + object.internal.content + 8], ecx
  ; node.weight <- rnode.weight - rnode.right.weight - 1
  xor rdi, rdi
  mov edi, [rdx + object.internal.content + 8]
  shl rdi, 4
  jz .rotate.left.1
  sub ecx, [rdi + object.internal.content + 8]
.rotate.left.1:
  dec ecx
  mov [rsi + object.internal.content + 8], ecx
  ; return rnode
  mov rax, rdx
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  ret

  ; in: a = address of the node
.balance.update:
  push rdx
  cmp byte [rax + object.internal.padding], 1
  jne .balance.update.1
  xor rdx, rdx
  mov edx, [rax + object.internal.content + 8]
  shl rdx, 4
  mov byte [rdx + object.internal.padding], -1
  xor rdx, rdx
  mov edx, [rax + object.internal.content + 4]
  shl rdx, 4
  mov byte [rdx + object.internal.padding], 0
  jmp .balance.update.3
.balance.update.1:
  cmp byte [rax + object.internal.padding], -1
  jne .balance.update.2
  xor rdx, rdx
  mov edx, [rax + object.internal.content + 8]
  shl rdx, 4
  mov byte [rdx + object.internal.padding], 0
  xor rdx, rdx
  mov edx, [rax + object.internal.content + 4]
  shl rdx, 4
  mov byte [rdx + object.internal.padding], 1
  jmp .balance.update.3
.balance.update.2:
  xor rdx, rdx
  mov edx, [rax + object.internal.content + 8]
  shl rdx, 4
  mov byte [rdx + object.internal.padding], 0
  xor rdx, rdx
  mov edx, [rax + object.internal.content + 4]
  shl rdx, 4
  mov byte [rdx + object.internal.padding], 0
.balance.update.3:
  mov byte [rax + object.internal.padding], 0
  pop rdx
  ret

%endif  ; TABLE_ASM_

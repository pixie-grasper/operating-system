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
  shr rax, 4
  ret

.dispose.raw:
  push rax
  shr rax, 4
  call .clear
  pop rax
  ret

  ; in: a = set id
.clear:
  push rax
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
  pop rax
  ret
.clear.2:
  mov eax, [rdx + object.internal.content]
  call objects.unref
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

  ; in: a = set id
.clear.move:
  push rax
  push rdx
  xor rdx, rdx
  mov edx, eax
  shl rdx, 4
  xor rax, rax
  mov eax, [rdx + object.content]
  shl rax, 4
  jz .clear.move.1
  call .clear.move.2
.clear.move.1:
  pop rdx
  pop rax
  ret
.clear.move.2:
  mov rdx, rax
  xor rax, rax
  mov eax, [rdx + object.internal.content + 4]
  shl rax, 4
  jz .clear.move.3
  push rdx
  call .clear.move.2
  pop rdx
.clear.move.3:
  xor rax, rax
  mov eax, [rdx + object.internal.content + 8]
  shl rax, 4
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
  push rcx
  ; rdx not changed
  push rsi
  xor rcx, rcx
  mov ecx, eax
  shl rcx, 4
  xor rsi, rsi
  mov esi, [rcx + object.content]
  shl rsi, 4
  jz .find.4  ; an empty set has nothing elements
.find.1:
  mov eax, [rsi + object.internal.content]
  call objects.lt
  test eax, eax
  jnz .find.2
  push rdx
  mov eax, edx
  mov edx, [rsi + object.internal.content]
  call objects.lt
  pop rdx
  test eax, eax
  jz .find.3
  ; value < node
  xor rax, rax
  mov eax, [rsi + object.internal.content + 4]
  shl rax, 4
  jz .find.4
  mov rsi, rax
  jmp .find.1
.find.2:  ; node < value
  xor rax, rax
  mov eax, [rsi + object.internal.content + 8]
  shl rax, 4
  jz .find.4
  mov rsi, rax
  jmp .find.1
.find.3:
  call objects.new.true
  pop rsi
  pop rcx
  ret
.find.4:
  call objects.new.false
  pop rsi
  pop rcx
  ret

  ; in: a = set id
  ; in: d = value id
.insert:
  push rax
  push rcx
  push rdx
  push rsi
  push rdi
  push rbp
  xor rcx, rcx
  mov ecx, eax
  shl rcx, 4
  xor rsi, rsi
  mov esi, [rcx + object.content]
  shl rsi, 4
  jnz .insert.1
  call objects.new.chunk
  mov [rax + object.internal.content], edx
  shr rax, 4
  mov [rcx + object.content], eax
  mov eax, edx
  call objects.ref
  pop rbp
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  pop rax
.insert.1:
  call stack.new
  mov ebp, eax
  mov edi, edx
.insert.2:
  ; c: address of the set
  ; si: address of the current node
  ; di: value id
  ; bp: stack id indicates path
  mov eax, [rsi + object.internal.content]
  mov edx, edi
  call objects.lt
  test eax, eax
  jz .insert.3
  ; [si:o.i.c.] < value
  ; push node, true
  mov eax, ebp
  mov rdx, rsi
  shr rdx, 4
  call stack.push.move
  mov edx, 1
  call stack.push.move
  xor rax, rax
  mov eax, [rsi + object.internal.content + 8]
  shl rax, 4
  mov rsi, rax
  ; then, if node->right != null, continue node <- node->right
  jnz .insert.2
  ; if node->right == null, node->right = new and balance
  call objects.new.chunk
  mov [rax + object.internal.content], edi
  shr rax, 4
  mov [rsi + object.internal.content + 8], eax
  jmp .insert.4
.insert.3:
  mov eax, edi
  mov edx, [rsi + object.internal.content]
  call objects.lt
  test eax, eax
  ; if it found in the set, break and end without balance
  jz .insert.5
  ; [si:o.i.c.] > value
  ; push node, false
  mov eax, ebp
  mov rdx, rsi
  shr rdx, 4
  call stack.push.move
  xor edx, edx
  call stack.push.move
  xor rax, rax
  mov eax, [rsi + object.internal.content + 4]
  shl rax, 4
  mov rsi, rax
  ; then, if node->left != null, continue node <- node->left
  jnz .insert.2
  call objects.new.chunk
  mov [rax + object.internal.content], edi
  shr rax, 4
  mov [rsi + object.internal.content + 4], eax
.insert.4:
  mov eax, [rcx + object.content]
  mov edx, ebp
  call .insert.balance
  mov [rcx + object.content], eax
  mov eax, edi
  call objects.ref
.insert.5:
  mov eax, ebp
  call stack.clear.move
  call objects.unref
  pop rbp
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  pop rax
  ret

  ; in: a = set id
  ; in: d = value id
.insert.move:
  push rax
  push rcx
  push rdx
  push rsi
  push rdi
  push rbp
  xor rcx, rcx
  mov ecx, eax
  shl rcx, 4
  xor rsi, rsi
  mov esi, [rcx + object.content]
  shl rsi, 4
  jnz .insert.move.1
  call objects.new.chunk
  mov [rax + object.internal.content], edx
  shr rax, 4
  mov [rcx + object.content], eax
  pop rbp
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  pop rax
.insert.move.1:
  call stack.new
  mov ebp, eax
  mov edi, edx
.insert.move.2:
  ; c: address of the set
  ; si: address of the current node
  ; di: value id
  ; bp: stack id indicates path
  mov eax, [rsi + object.internal.content]
  mov edx, edi
  call objects.lt
  test eax, eax
  jz .insert.move.3
  ; [si:o.i.c.] < value
  ; push node, true
  mov eax, ebp
  mov rdx, rsi
  shr rdx, 4
  call stack.push.move
  mov edx, 1
  call stack.push.move
  xor rax, rax
  mov eax, [rsi + object.internal.content + 8]
  shl rax, 4
  mov rsi, rax
  ; then, if node->right != null, continue node <- node->right
  jnz .insert.move.2
  ; if node->right == null, node->right = new and balance
  call objects.new.chunk
  mov [rax + object.internal.content], edi
  shr rax, 4
  mov [rsi + object.internal.content + 8], eax
  jmp .insert.move.4
.insert.move.3:
  mov eax, edi
  mov edx, [rsi + object.internal.content]
  call objects.lt
  test eax, eax
  ; if it found in the set, break and end without balance
  jz .insert.move.5
  ; [si:o.i.c.] > value
  ; push node, false
  mov eax, ebp
  mov rdx, rsi
  shr rdx, 4
  call stack.push.move
  xor edx, edx
  call stack.push.move
  xor rax, rax
  mov eax, [rsi + object.internal.content + 4]
  shl rax, 4
  mov rsi, rax
  ; then, if node->left != null, continue node <- node->left
  jnz .insert.move.2
  call objects.new.chunk
  mov [rax + object.internal.content], edi
  shr rax, 4
  mov [rsi + object.internal.content + 4], eax
.insert.move.4:
  mov eax, [rcx + object.content]
  mov edx, ebp
  call .insert.balance
  mov [rcx + object.content], eax
.insert.move.5:
  mov eax, ebp
  call stack.clear.move
  call objects.unref
  pop rbp
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  pop rax
  ret

  ; in: a: root node id
  ; in: d: stack id indicates path
  ; out: a: root node id
.insert.balance:
  push rbx
  push rcx
  push rdx
  push rsi
  push rdi
  ; b: address of the pnode
  ; c: stack id
  ; si: address of the new-node
  ; di: root node id
  mov edi, eax
  ; while path.len > 0
  mov eax, edx
  call stack.empty
  test eax, eax
  jnz .insert.balance.8
  mov ecx, edx
  xor esi, esi
.insert.balance.1:
  ; pnode, dir = path.pop()
  mov eax, ecx
  call stack.pop.move
  mov edx, eax
  mov eax, ecx
  call stack.pop.move
  xor rbx, rbx
  mov ebx, eax
  shl rbx, 4
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
  xor rdx, rdx
  mov edx, [rbx + object.internal.content + 4]
  shl rdx, 4
  cmp byte [rdx + object.internal.padding], 0
  jnl .insert.balance.2
  ; pnode.left = rotate.left pnode.left
  mov rax, rdx
  call .rotate.left
  shr rax, 4
  mov [rbx + object.internal.content + 4], eax
  ; new-node = rotate.right pnode
  mov rax, rbx
  call .rotate.right
  mov rsi, rax
  ; balance.update new-node
  call .balance.update
  jmp .insert.balance.6
  ; else:
.insert.balance.2:
  ; new-node = rotate.right pnode
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
  xor rdx, rdx
  mov edx, [rbx + object.internal.content + 8]
  shl rdx, 4
  cmp byte [rdx + object.internal.padding], 0
  jng .insert.balance.4
  ; pnode.right = rotate.right pnode.right
  mov rax, rdx
  call .rotate.right
  shr rax, 4
  mov [rbx + object.internal.content + 8], eax
  ; new-node = rotate.left pnode
  mov rax, rbx
  call .rotate.left
  mov rsi, rax
  ; balance.update new-node
  call .balance.update
  jmp .insert.balance.6
  ; else:
.insert.balance.4:
  ; new-node = rotate.left pnode
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
  mov eax, ecx
  call stack.empty
  test eax, eax
  jz .insert.balance.1
.insert.balance.6:
  ; if path.len > 0:
  mov eax, ecx
  call stack.empty
  test eax, eax
  jnz .insert.balance.7
  ; gnode, gdir = path.pop()
  mov eax, ecx
  call stack.pop.move
  xor rdx, rdx
  mov edx, eax
  mov eax, ecx
  call stack.pop.move
  xor rbx, rbx
  mov ebx, eax
  shl rbx, 4
  ; if gdir == LEFT: gnode.left = new-node else: gnode.right = new-node
  shr rsi, 4
  mov [rbx + object.internal.content + 4 + rdx * 4], esi
  jmp .insert.balance.8
.insert.balance.7:
  ; elif new-node is not nil: return new-node
  shr rsi, 4
  jz .insert.balance.8
  mov edi, esi
.insert.balance.8:
  mov eax, edi
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  ret

  ; in/out: a = address of the node
.rotate.right:
  push rcx
  push rdx
  ; lnode = node.left
  xor rdx, rdx
  mov edx, [rax + object.internal.content + 4]
  shl rdx, 4
  ; node.left = lnode.right
  mov ecx, [rdx + object.internal.content + 8]
  mov [rax + object.internal.content + 4], ecx
  ; lnode.right = node
  shr rax, 4
  mov [rdx + object.internal.content + 8], eax
  ; return lnode
  mov rax, rdx
  pop rdx
  pop rcx
  ret

  ; in/out: a = address of the node
.rotate.left:
  push rcx
  push rdx
  ; rnode = node.right
  xor rdx, rdx
  mov edx, [rax + object.internal.content + 8]
  shl rdx, 4
  ; node.right = rnode.left
  mov ecx, [rdx + object.internal.content + 4]
  mov [rax + object.internal.content + 8], ecx
  ; rnode.left = node
  shr rax, 4
  mov [rdx + object.internal.content + 4], eax
  ; return rnode
  mov rax, rdx
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

%endif  ; SET_ASM_

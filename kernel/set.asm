%ifndef SET_ASM_
%define SET_ASM_

; structure
;   set = {root-node | nil, reserved}
;     node = {value, left | nil, right | nil}, extra-field = balance: 2 bits
;     balance = 1 .. 0: 00 = left = right, 01 = left < right, 10 = left > right

set:
.new:
  call objects.new.raw
  mov byte [rax + object.class], object.set
  shr rax, 4
  ret

.dispose.raw:
  push rax
  push rdx
  xor rdx, rdx
  mov edx, [rax + object.content]
  shl rdx, 4
  jz .dispose.raw.1
  call .dispose.raw.2
.dispose.raw.1:
  pop rdx
  pop rax
  ret
.dispose.raw.2:
  mov eax, [rdx + object.internal.content]
  call objects.unref
  push rdx
  mov rax, rdx
  xor rdx, rdx
  mov edx, [rax + object.internal.content + 4]
  shl rdx, 4
  jz .dispose.raw.3
  call .dispose.raw.2
.dispose.raw.3:
  pop rax
  xor rdx, rdx
  mov edx, [rax + object.internal.content + 8]
  shl rdx, 4
  jz .dispose.raw.4
  call .dispose.raw.2
.dispose.raw.4:
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
  ; in: a: root node id
  ; in: d: stack id indicates path
  ; out: a: root node id
  ; TODO: implement
.insert.balance:
  ret

%endif  ; SET_ASM_

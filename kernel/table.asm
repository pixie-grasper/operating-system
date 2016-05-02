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
  ; di: value id
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

%endif  ; TABLE_ASM_

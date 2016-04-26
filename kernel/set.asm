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
  push rdx
  push rsi
  push rdi
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
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  ret
.find.4:
  call objects.new.false
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  ret

%endif  ; SET_ASM_

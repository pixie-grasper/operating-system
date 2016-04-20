%ifndef INTEGER_ASM_
%define INTEGER_ASM_

integer:
  ; out: a = integer id
.new:
  call objects.new.raw
  mov byte [rax + object.class], object.integer
  shr rax, 4
  ret

.dispose.raw:
  ret

  ; in: a = object id
  ; out: d = int:64
.get:
  xor rdx, rdx
  mov edx, eax
  shl rdx, 4
  mov rdx, [rdx + object.content]
  ret

  ; in: a = object id
  ; in: d = int:64
.set:
  push rcx
  xor rcx, rcx
  mov ecx, eax
  shl rcx, 4
  mov [rcx + object.content], rdx
  pop rcx
  ret

  ; in: a = integer id 1
  ; in: d = integer id 2
  ; out: a = result
.lt:
  xor rcx, rcx
  mov ecx, eax
  shl rcx, 4
  mov rax, rcx
  xor rcx, rcx
  mov ecx, edx
  shl rcx, 4
  mov rax, [rax + object.content]
  mov rcx, [rcx + object.content]
  cmp rax, rcx
  jl objects.new.true
  jmp objects.new.false

.lt@s:
  push rcx
  call .lt
  pop rcx
  ret

%endif  ; INTEGER_ASM_

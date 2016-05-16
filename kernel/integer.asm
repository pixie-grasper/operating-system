%ifndef INTEGER_ASM_
%define INTEGER_ASM_

integer:
  ; out: a = integer id
.new:
  call objects.new.raw
  mov byte [rax + object.class], object.integer
  id_from_addr a
  ret

  ; in: a = int:64
  ; out: a = integer id
.new.with.value:
  push rdx
  mov rdx, rax
  call .new
  call .set
  pop rdx
  ret

.dispose.raw:
  ret

  ; in: a = integer id
  ; out: a = int:64
.get:
  push rdx
  addr_from_id d, a
  mov rax, [rdx + object.content]
  pop rdx
  ret

  ; in: a = integer id
  ; in: d = int:64
.set:
  push rcx
  addr_from_id c, a
  mov [rcx + object.content], rdx
  pop rcx
  ret

  ; in: a = integer id 1
  ; in: d = integer id 2
  ; out: a = result
.lt@us:
  addr_from_id c, a
  addr_from_id a, d
  mov rcx, [rcx + object.content]
  mov rax, [rax + object.content]
  cmp rcx, rax
  jl objects.new.true
  jmp objects.new.false

.lt:
  push rcx
  call .lt@us
  pop rcx
  ret

%endif  ; INTEGER_ASM_

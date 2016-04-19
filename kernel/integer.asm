%ifndef INTEGER_ASM_
%define INTEGER_ASM_

integer:
.new:
  call objects.new
  mov byte [rax + object.class], object.integer
  ret

.dispose:
  ret

.get:
  mov rdx, [rax + object.content]
  ret

.set:
  mov [rax + object.content], rdx
  ret

  ; in: a = integer 1
  ; in: d = integer 2
  ; out: a = result
.lt:
  mov rsi, [rax + object.content]
  mov rdi, [rdx + object.content]
  cmp rsi, rdi
  jl objects.new.true
  jmp objects.new.false

%endif  ; INTEGER_ASM_

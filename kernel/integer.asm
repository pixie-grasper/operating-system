%ifndef INTEGER_ASM_
%define INTEGER_ASM_

integer:
.new:
  call objects.new.integer
  ret

.dispose:
  ret

.get:
  mov rdx, [rax + object.content]
  ret

.set:
  mov [rax + object.content], rdx
  ret

%endif  ; INTEGER_ASM_

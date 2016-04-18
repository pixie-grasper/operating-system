%ifndef INTEGER_ASM_
%define INTEGER_ASM_

integer:
.new:
  push rdx
  push rax
  call objects.new.integer
  pop rdx
  mov [rax + object.content], rdx
  pop rdx
  ret

.dispose:
  ret

%endif  ; INTEGER_ASM_

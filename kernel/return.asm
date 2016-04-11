%ifndef RETURN_ASM_
%define RETURN_ASM_

return:
.true:
  clc
  ret

.false:
  stc
  ret

%endif  ; RETURN_ASM_

%ifndef STORAGE_DEVICE_ASM_
%define STORAGE_DEVICE_ASM_

storage_device:
.readsector:
  call [ebx + .vtable.readsector]
  ret

.vtable.readsector equ 0

%endif  ; STORAGE_DEVICE_ASM_

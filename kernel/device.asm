%ifndef DEVICE_ASM_
%define DEVICE_ASM_

; structure
;   device = {tuple, dependes on the flag}, extra-field = flag: 8 bit
;   tuple = {octet-buffer x 3(buffer, ready-bitmap, modified-bitmap)}
;   flag: 0 = port-mapped I/O
;           device = {buffer, dep}
;           dep = {port-number, device-number, type}

%include "ide.asm"

device:
.init:
  call table.new
  mov [.table], eax
  xor rdx, rdx
  call ide.init
  mov rax, rdx
  call console_out.printi@s
  mov rax, msg.device.found
  call console_out.prints
  ret

.new:
  push rdx
  call objects.new.chunk
  mov rdx, rax
  call octet_buffer.new
  mov [rdx + object.internal.content], eax
  call octet_buffer.new
  mov [rdx + object.internal.content + 4], eax
  call octet_buffer.new
  mov [rdx + object.internal.content + 8], eax
  shr rdx, 4
  call objects.new.raw
  mov byte [rax + object.class], object.device
  mov [rax + object.content], edx
  shr rax, 4
  pop rdx
  ret

.dispose.raw:
  push rax
  push rdx
  xor rdx, rdx
  mov edx, [rax + object.content]
  shl rdx, 4
  mov eax, [rdx + object.internal.content]
  call objects.unref
  mov eax, [rdx + object.internal.content + 4]
  call objects.unref
  mov eax, [rdx + object.internal.content + 8]
  call objects.unref
  pop rdx
  pop rax
  ret

.table: dd 0

.ata   equ 0
.atapi equ 1


%endif  ; DEVICE_ASM_

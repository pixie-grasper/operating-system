%ifndef ISO9660_ASM_
%define ISO9660_ASM_

; structure
;   iterator = {device, status}
;   status = {LBA of the directory-record, length of the directory-record, relative current pos}

iso9660:
  ; in: a = device
  ; out: a = iterator of the root | nil
.begin:
  push rcx
  push rdx
  push rsi
  mov esi, eax
  mov edx, 2048 * 15
.begin.1:
  mov eax, esi
  add edx, 2048
  call device.index
  test rax, rax
  jz .begin.3
  cmp byte [rax + 0], 1  ; finding primary volume descriptor
  je .begin.2
  cmp byte [rax + 0], 0xff
  je .begin.3
  jmp .begin.1
.begin.2:
  ; now, the root directory record starts at rax + 156
  mov ecx, [rax + 156 + 2]  ; location
  mov edx, [rax + 156 + 10]  ; length
  call objects.new.chunk
  mov [rax + object.internal.content], ecx
  mov [rax + object.internal.content + 4], edx
  shr rax, 4
  mov ecx, eax
  call objects.new.raw
  mov [rax + object.content], esi
  mov [rax + object.content + 4], ecx
  shr rax, 4
  pop rsi
  pop rdx
  pop rcx
  ret
.begin.3:
  xor rax, rax
  pop rsi
  pop rdx
  pop rcx
  ret

.iterator.succ:
  ret

%endif  ; ISO9660_ASM_

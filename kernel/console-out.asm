%ifndef CONSOLE_OUT_ASM_
%define CONSOLE_OUT_ASM_

%include "atomic.asm"

console_out:
  ; in: si = address of asciz string
.prints:
  mov rdi, .lock
  call atomic.lock
  mov ah, 0x07
  mov rdx, [.current_pos]
.prints.1:
  mov al, [rsi]
  test al, al
  jz .prints.2
  mov [rdx], ax
  add rdx, 2
  inc rsi
  jmp .prints.1
.prints.2:
  mov [.current_pos], rdx
  call atomic.unlock
  ret

.printdot@s:
  push rdi
  push rax
  push rdx
  mov rdi, .lock
  call atomic.lock
  mov rax, [.current_pos]
  mov word [rax], 0x072e
  add rax, 2
  mov [.current_pos], rax
  call atomic.unlock
  pop rdx
  pop rax
  pop rdi
  ret

  ; in: a = signed integer
.printi:
  xor rdx, rdx
  xor rcx, rcx
  push rcx  ; terminater
  mov rdi, 10
  test rax, rax
  jns .printi.1
  neg rax
  not ecx
.printi.1:
  test rax, rax
  jz .printi.2
  div rdi
  add edx, 0x0730
  push rdx
  xor edx, edx
  jmp .printi.1
.printi.2:
  test ecx, ecx
  jns .printi.3
  push 0x072d
.printi.3:
  mov rdi, .lock
  call atomic.lock
  mov rdx, [.current_pos]
.printi.4:
  pop rax
  test eax, eax
  jz .printi.5
  mov [rdx], ax
  add rdx, 2
  jmp .printi.4
.printi.5:
  mov [.current_pos], rdx
  call atomic.unlock
  ret

  ; in: a = bit stream
.printx:
  bswap rax
  mov rdx, rax
  mov rcx, 0xf0f0f0f0f0f0f0f0
  and rax, rcx
  shr rcx, 4
  and rdx, rcx
  shr rax, 4
  shl rdx, 4
  add rdx, rax
  push rdx
  mov ecx, 16
  mov rdi, .lock
  call atomic.lock
  mov rsi, [.current_pos]
  mov ah, 0x07
  pop rdx
.printx.1:
  mov al, dl
  and al, 0x0f
  add al, 0x30
  cmp al, 0x39
  jbe .printx.2
  add al, 0x07
.printx.2:
  mov [rsi], ax
  add rsi, 2
  shr rdx, 4
  dec ecx
  jnz .printx.1
  mov [.current_pos], rsi
  call atomic.unlock
  ret

.printx@s:
  push rax
  push rcx
  push rdx
  push rsi
  push rdi
  call .printx
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  pop rax
  ret

.current_pos: dq 0x000b8000
.lock: dd 0

%endif  ; CONSOLE_OUT_ASM_

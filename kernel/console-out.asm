%ifndef CONSOLE_OUT_ASM_
%define CONSOLE_OUT_ASM_

%include "atomic.asm"

console_out:
  ; in: si = address of asciz string
.prints:
  mov rdi, .lock
  call atomic.lock
  mov ah, 0x07
  mov rdi, [.current_pos]
.prints.1:
  mov al, [rsi]
  test al, al
  jz .prints.2
  mov [rdi], ax
  add rdi, 2
  inc rsi
  jmp .prints.1
.prints.2:
  mov [.current_pos], rdi
  mov rdi, .lock
  call atomic.unlock
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
  mov rdi, .lock
  call atomic.lock
  mov rdi, [.current_pos]
  test ecx, ecx
  jns .printi.3
  push 0x072d
.printi.3:
  pop rax
  test eax, eax
  jz .printi.4
  mov [edi], ax
  add edi, 2
  jmp .printi.3
.printi.4:
  mov [.current_pos], rdi
  mov rdi, .lock
  call atomic.unlock
  ret

.current_pos: dq 0x000b8000
.lock: dd 0

%endif  ; CONSOLE_OUT_ASM_

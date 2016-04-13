%ifndef CONSOLE_OUT_ASM_
%define CONSOLE_OUT_ASM_

%include "atomic.asm"

console_out:
.init:
  ; set cursor to left-top corner
  mov edi, 0x000b8000
  call .cursor.set
  ; clear screen
  mov eax, 0x07200720
  mov ecx, 80 * 25 * 2 / 4
.init.1:
  mov [edi], eax
  add edi, 4
  dec ecx
  jnz .init.1
  ret

.cursor.set:
  mov ecx, edi
  sub ecx, 0x000b8000
  shr ecx, 1
  mov dx, 0x03d4
  mov al, 0x0e
  out dx, al
  inc edx
  mov al, ch
  out dx, al
  dec edx
  mov al, 0x0f
  out dx, al
  inc edx
  mov al, cl
  out dx, al
  ret

  ; in: si = address of asciz string
.prints@us:
  mov rdi, .lock
  call atomic.lock
  mov ah, 0x07
  mov edx, 0x000b8000
.prints@us.1:
  mov al, [rsi]
  test al, al
  jz .prints@us.2
  mov [edx], ax
  add edx, 2
  inc rsi
  jmp .prints@us.1
.prints@us.2:
  call atomic.unlock
  ret

  ; in: si = address of asciz string
.prints:
  mov rdi, .lock
  call atomic.lock
  mov ah, 0x07
  mov edi, [.current.pos]
.prints.1:
  mov al, [rsi]
  test al, al
  jz .prints.2
  cmp al, 0x0a
  je .prints.n
  cmp al, 0x0d
  je .prints.r
  cmp edi, 0x000b8000 + 80 * 25 * 2
  jae .prints.scroll
  mov [edi], ax
  add edi, 2
  inc rsi
  jmp .prints.1
.prints.2:
  cmp edi, 0x000b8000 + 80 * 25 * 2
  jb .prints.3
  call .scroll
  jmp .prints.2
.prints.3:
  mov [.current.pos], edi
  call .cursor.set
  mov rdi, .lock
  call atomic.unlock
  ret
.prints.scroll:
  call .scroll
  jmp .prints.1
.prints.n:
  push rax
  mov eax, edi
  sub eax, 0x000b8000
  xor edx, edx
  mov ecx, 80 * 2
  div ecx
  sub edi, edx
  add edi, 80 * 2
  pop rax
  inc rsi
  jmp .prints.1
.prints.r:
  push rax
  mov eax, edi
  sub eax, 0x000b8000
  xor edx, edx
  mov ecx, 80 * 2
  div ecx
  sub edi, edx
  pop rax
  inc rsi
  jmp .prints.1

.scroll:
  push rax
  push rcx
  push rsi
  push rdi
  mov ecx, 80 * 24 * 2 / 4
  mov esi, 0x000b8000 + 80 * 2
  mov edi, 0x000b8000
.scroll.1:
  mov eax, [esi]
  mov [edi], eax
  add esi, 4
  add edi, 4
  dec ecx
  jnz .scroll.1
  mov eax, 0x07200720
  mov ecx, 80 * 2 / 4
.scroll.2:
  mov [edi], eax
  add edi, 4
  dec ecx
  jnz .scroll.2
  pop rdi
  pop rsi
  pop rcx
  pop rax
  sub edi, 80 * 2
  ret

.printdot@s:
  push rax
  push rcx
  push rdx
  push rdi
  mov rdi, .lock
  call atomic.lock
  mov edi, [.current.pos]
  mov word [edi], 0x072e
  add edi, 2
  cmp edi, 0x000b8000 + 80 * 25 * 2
  jb .printdot@s.1
  call .scroll
.printdot@s.1:
  mov [.current.pos], edi
  call .cursor.set
  mov rdi, .lock
  call atomic.unlock
  pop rdi
  pop rdx
  pop rcx
  pop rax
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
  mov edi, [.current.pos]
.printi.4:
  pop rax
  test eax, eax
  jz .printi.5
  mov [edi], ax
  add edi, 2
  cmp edi, 0x000b8000 + 80 * 25 * 2
  jb .printi.4
  call .scroll
  jmp .printi.4
.printi.5:
  mov [.current.pos], edi
  call .cursor.set
  mov rdi, .lock
  call atomic.unlock
  ret

.printi@s:
  push rax
  push rcx
  push rdx
  push rdi
  call .printi
  pop rdi
  pop rdx
  pop rcx
  pop rax
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
  mov edi, [.current.pos]
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
  mov [edi], ax
  add edi, 2
  shr rdx, 4
  dec ecx
  jnz .printx.1
  mov [.current.pos], edi
  call .cursor.set
  mov rdi, .lock
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

.current.pos: dd 0x000b8000
.lock: dd 0

%endif  ; CONSOLE_OUT_ASM_

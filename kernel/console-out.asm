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

  ; in: a = address of asciz string
.prints@us:
  mov rsi, rax
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

  ; in: a = address of asciz string
.prints:
  pushs a, c, d, si, di
  mov rsi, rax
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
  pops a, c, d, si, di
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
  pushs a, c, si, di
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
  pops a, c, si, di
  sub edi, 80 * 2
  ret

.printdot@s:
  pushs a, c, d, di
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
  pops a, c, d, di
  ret

.printcolon@s:
  pushs a, c, d, di
  mov rdi, .lock
  call atomic.lock
  mov edi, [.current.pos]
  mov word [edi], 0x073a
  add edi, 2
  cmp edi, 0x000b8000 + 80 * 25 * 2
  jb .printcolon@s.1
  call .scroll
.printcolon@s.1:
  mov [.current.pos], edi
  call .cursor.set
  mov rdi, .lock
  call atomic.unlock
  pops a, c, d, di
  ret

  ; in: a = signed integer
.printi:
  pushs a, c, d, di
  xor rdx, rdx
  xor rcx, rcx
  push rcx  ; terminater
  mov rdi, 10
  test rax, rax
  jns .printi.1
  neg rax
  not ecx
.printi.1:
  jz .printi.7
.printi.2:
  test rax, rax
  jz .printi.3
  div rdi
  add edx, 0x0730
  push rdx
  xor edx, edx
  jmp .printi.2
.printi.3:
  test ecx, ecx
  jns .printi.4
  push 0x072d
.printi.4:
  mov rdi, .lock
  call atomic.lock
  mov edi, [.current.pos]
.printi.5:
  pop rax
  test eax, eax
  jz .printi.6
  mov [edi], ax
  add edi, 2
  cmp edi, 0x000b8000 + 80 * 25 * 2
  jb .printi.5
  call .scroll
  jmp .printi.5
.printi.6:
  mov [.current.pos], edi
  call .cursor.set
  mov rdi, .lock
  call atomic.unlock
  pops a, c, d, di
  ret
.printi.7:
  push 0x0730
  jmp .printi.4

  ; in: a = bit stream
.printx:
  pushs a, c, d, si, di
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
  pops a, c, d, si, di
  ret

.current.pos: dd 0x000b8000
.lock: dd 0

%endif  ; CONSOLE_OUT_ASM_

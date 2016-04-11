%ifndef MEMORY_ASM_
%define MEMORY_ASM_

%include "return.asm"
%include "atomic.asm"

memory:
.init:
  ; first, check already initialized
  mov rdi, .initialized
  call atomic.trylock
  jc return.false
  ; first, disable caching
  mov rax, cr0
  push rax
  or rax, 0x60000000  ; set CD, NW
  mov cr0, rax
  ; then, get size of the installed memory
  call .calcsize
  ; then, enable caching
  pop rax
  mov cr0, rax
  ; if memory not enough, return
  call .getsize
  cmp rax, 2 * 1024 * 1024
  jb return.false
  jmp return.true

.calcsize:
  mov rax, 1 << 36  ; 64 GiB
  mov rsi, rax
  call .check
  jnc .calcsize.3
  xor rdi, rdi
  mov r8, 36 - 3
.calcsize.1:
  dec r8
  jz .calcsize.3
  mov rax, rdi
  add rax, rsi
  shr rax, 1
  call .check
  jc .calcsize.2
  mov rdi, rax
  jmp .calcsize.1
.calcsize.2:
  mov rsi, rax
  jmp .calcsize.1
.calcsize.3:
  mov [.size], rdi
  ret

  ; in: a = assuming size of installed memory
.check:
  mov rdx, [rax - 8]
  mov rcx, rdx
  not rdx
  mov [rax - 8], rdx
  wbinvd
  cmp rdx, [rax - 8]
  mov [rax - 8], rcx
  je return.true
  jmp return.false

  ; out: a = size of installed memory
.getsize:
  mov rax, [.size]
  ret

.size: dq 0
.initialized: dd 0
%endif

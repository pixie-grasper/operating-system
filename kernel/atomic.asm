%ifndef ATOMIC_ASM_
%define ATOMIC_ASM_

%include "return.asm"

  ; in: rdi = address of lock
  ; out: flags.c; set = failed, cleared = succeed
atomic:
.ctor:
  xor eax, eax
  mov dword [rdi], eax
  ret

.lock:
  call .trylock
  jc .lock
  ret

.lockh:
  call .trylock
  jc .lockh.1
  ret
.lockh.1:
  hlt
  jmp .lockh

.trylock:
  xor eax, eax
  or edx, -1
  lock cmpxchg [rdi], edx
  je return.true
  jmp return.false

.unlock:
  call .tryunlock
  ret

.tryunlock:
  or eax, -1
  xor edx, edx
  lock cmpxchg [rdi], edx
  je return.true
  jmp return.false

.incd:
  call .tryincd
  jc .incd
  ret

.tryincd:
  mov eax, [rdi]
  mov edx, eax
  inc edx
  lock cmpxchg [rdi], edx
  je return.true
  jmp return.false

.decd:
  call .trydecd
  jc .decd
  ret

.trydecd:
  mov eax, [rdi]
  mov edx, eax
  dec edx
  lock cmpxchg [rdi], edx
  je return.true
  jmp return.false

.incq:
  call .tryincq
  jc .incq
  ret

.tryincq:
  mov rax, [rdi]
  mov rdx, rax
  inc rdx
  lock cmpxchg [rdi], rdx
  je return.true
  jmp return.false

.decq:
  call .trydecq
  jc .decq
  ret

.trydecq:
  mov rax, [rdi]
  mov rdx, rax
  dec rdx
  lock cmpxchg [rdi], rdx
  je return.true
  jmp return.false

%endif  ; ATOMIC_ASM_

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
  ; check size of the installed memory
  call .calcsize
  ; if memory not enough, return
  cmp rdi, 2 * 1024 * 1024
  jb return.false
  ; initialize memory map
  call .initmap
  jmp return.true

  ; out: di = memory size
.calcsize:
  ; first, disable caching
  mov rax, cr0
  push rax
  or rax, 0x60000000  ; set CD, NW
  mov cr0, rax
  ; then, check installed
  mov rax, 1 << 36  ; 64 GiB
  mov rsi, rax
  mov rdi, rax
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
  ; enable caching
  pop rax
  mov cr0, rax
  ; save memory size
  mov [.size], rdi
  ret

  ; map begins 0x00100000
  ; note:
  ;   memory size >= 0x00200000
  ;   0x00100000--0x0010001f: free space
  ;   0x00100020--0x00100000 + .size / (4096 * 8): memory management area
  ; in the area, page id = (addr - 0x00100000) * 8 + bit pos [addr]
  ; page address = id * 4096
  ; in: di = memory size
.initmap:
  mov rcx, rdi
  shr rcx, 12 + 3 + 2  ; 1 page 4 KiB per 1 bit = 128 KiB per 1 DWord
  mov edi, 0x00100000
  mov esi, edi
  xor edx, edx
.initmap.1:
  mov [edi], edx
  add edi, 4
  dec ecx
  jnz .initmap.1
  ; map ends edi. set fill flag.
  ; Incidentally, allocate sequencial buffer for the kernel
  mov [global_page_addr], edi
  shr edi, 12
  add edi, global_page_size  ; number of allocate pages
  mov eax, edi
  and eax, 0x07
  shr edi, 3
  add edi, esi
  not edx
.initmap.2:
  mov [esi], edx
  add esi, 4
  cmp esi, edi
  jb .initmap.2
  mov ecx, edx
  test eax, eax
  jz .initmap.4
.initmap.3:
  shl ecx, 1
  dec eax
  jz .initmap.4
  jmp .initmap.3
.initmap.4:
  not ecx
  mov [esi], ecx
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

  ; out: a = page address
.newpage:
  pushs d, si, di
  xor rax, rax
  mov edi, [fs:TLS.memory.tablelookahead]
  mov esi, edi
.newpage.2:
  ; try to set a bit
  mov eax, [edi]
  mov edx, eax
  inc edx
  jz .newpage.3
  or edx, eax
  lock cmpxchg [edi], edx
  jne .newpage.2
  ; then, get bit's position
  xor eax, edx  ; only single bit on
  dec eax
  popcnt eax, eax
  ; then, get page address
  mov [fs:TLS.memory.tablelookahead], edi
  sub edi, 0x00100000  ; least 2 bits are cleared
  shl edi, 3  ; make least 5 bits are cleard
  add eax, edi  ; calc the id,
  shl rax, 12  ; and calc the address
  pops d, si, di
  ret
.newpage.3:
  add edi, 4
  cmp esi, edi
  je return.false
  call .getsize
  shr rax, 12 + 3
  add eax, 0x00100000
  cmp edi, eax
  jb .newpage.2
  mov edi, 0x00100020
  jmp .newpage.2

  ; in: a = page address
.disposepage:
  pushs c, d, di
  shr rax, 12
  mov edi, eax
  mov ecx, eax
  shr edi, 3
  and edi, ~0x03
  add edi, 0x00100000
  and ecx, 0x1f
  mov edx, 1
  shl edx, cl
  not edx
.disposepage.1:
  mov eax, [edi]
  mov ecx, eax
  and ecx, edx
  lock cmpxchg [edi], ecx
  jne .disposepage.1
  pops c, d, di
  ret

  ; in: a = page address
.zerofill:
  pushs a, c, d
  xor edx, edx
  mov ecx, 4096 / 4
.zerofill.1:
  mov [rax], edx
  add rax, 4
  dec ecx
  jnz .zerofill.1
  pops a, c, d
  ret

.size: dq 0
.initialized: dd 0
%endif

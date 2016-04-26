%ifndef OCTET_BUFFER_ASM_
%define OCTET_BUFFER_ASM_

; structure
;   octet-buffer = {[address of the page directory pointer table entry (PDPTE)]:64}
;   PDPTE = {[page directory entry (PDE) id]:32} x 1024
;   PDE = {[page table entry (PTE) id]:32} x 1024
;   PTE = {[page id]:32} x 1024
;   page = 4096 octet

octet_buffer:
.new:
  call objects.new.raw
  mov byte [rax + object.class], object.octetbuffer
  shr rax, 4
  ret

.dispose.raw:
  push rax
  push rcx
  push rdx
  push rsi
  push rdi
  push rbp
  push r8
  mov r8, [rax + object.content]
  test r8, r8
  jz .dispose.raw.2
  mov rcx, 4096 / 4
.dispose.raw.1:  ; PDPT
  xor rdx, rdx
  mov edx, [r8]
  shl rdx, 4
  call .dispose.raw.3
  add rax, 4
  dec ecx
  jnz .dispose.raw.1
.dispose.raw.2:
  pop r8
  pop rbp
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  pop rax
  ret
.dispose.raw.3:  ; PD
  mov rdi, 4096 / 4
.dispose.raw.4:
  xor rsi, rsi
  mov esi, [rdx]
  shl rsi, 4
  call .dispose.raw.5
  add rdx, 4
  dec edi
  jnz .dispose.raw.4
  ret
.dispose.raw.5:  ; PT
  mov rbp, 4096 / 4
.dispose.raw.6:
  xor rax, rax
  mov eax, [rsi]
  shl rax, 4
  call memory.disposepage@s
  add rsi, 4
  dec ebp
  jnz .dispose.raw.6
  ret

  ; @const
  ; in: a = octet-buffer id
  ; in: d = octet-wised index
  ; out: a = nil | mapped address
.index:
  push rcx
  push rdx
  push rsi
  xor rcx, rcx
  mov ecx, eax
  shl rcx, 4
  mov rax, rdx
  shr rax, 10 + 10 + 10 + 12
  jnz .index.1  ; invalid index
  mov rax, rdx
  shr rax, 10 + 10 + 12
  xor rsi, rsi
  mov esi, [rcx + rax * 4]
  shl rsi, 4
  jz .index.1
  mov rax, rdx
  shr rax, 10 + 12
  and eax, 0x03ff
  xor rcx, rcx
  mov ecx, [rsi + rax * 4]
  shl rcx, 4
  jz .index.1
  mov rax, rdx
  shr rax, 12
  and eax, 0x03ff
  xor rsi, rsi
  mov esi, [rcx + rax * 4]
  shl rsi, 4
  jz .index.1
  and rdx, 0x0fff
  lea rax, [rsi + rdx]
  pop rsi
  pop rdx
  pop rcx
  ret
.index.1:
  pop rsi
  pop rdx
  pop rcx
  jmp objects.new.nil

  ; in: a = octet-buffer id
  ; in: d = octet-wised index
  ; out: a = mapped address
.newindex:
  push rcx
  push rdx
  push rsi
  push rdi
  xor rcx, rcx
  mov ecx, eax
  shl rcx, 4
  mov rdi, rdx
  shr rdi, 10 + 10 + 10 + 12
  jnz .newindex.nil  ; invalid index
  mov rdi, rdx
  shr rdi, 10 + 10 + 12
  xor rsi, rsi
  mov esi, [rcx + rdi * 4]
  shl rsi, 4
  jnz .newindex.1
  call memory.newpage@s
  call memory.zerofill
  mov rsi, rax
  shr rax, 4
  mov [rcx + rdi * 4], eax
.newindex.1:
  mov rdi, rdx
  shr rdi, 10 + 12
  and rdi, 0x03ff
  xor rcx, rcx
  mov ecx, [rsi + rdi * 4]
  shl rcx, 4
  jnz .newindex.2
  call memory.newpage@s
  call memory.zerofill
  mov rcx, rax
  shr rax, 4
  mov [rsi + rdi * 4], eax
.newindex.2:
  mov rdi, rdx
  shr rdi, 12
  and rdi, 0x03ff
  xor rsi, rsi
  mov esi, [rcx + rdi * 4]
  shl rsi, 4
  jnz .newindex.3
  call memory.newpage@s
  call memory.zerofill
  mov rsi, rax
  shr rax, 4
  mov [rcx + rdi * 4], eax
.newindex.3:
  and rdx, 0x0fff
  lea rax, [rsi + rdx]
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  ret
.newindex.nil:
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  jmp objects.new.nil

%endif  ; OCTET_BUFFER_ASM_

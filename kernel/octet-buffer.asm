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
  id_from_addr a
  ret

.dispose.raw:
  pushs a, b, c, d, si, di, bp
  mov rbp, [rax + object.content]
  test rbp, rbp
  jz .dispose.raw.2
  mov ecx, 4096 / word.size
.dispose.raw.1:  ; PDPT
  ldaddr d, [rbp]
  call .dispose.raw.3
  add rbp, word.size
  dec ecx
  jnz .dispose.raw.1
.dispose.raw.2:
  pops a, b, c, d, si, di, bp
  ret
.dispose.raw.3:  ; PD
  mov edi, 4096 / word.size
.dispose.raw.4:
  ldaddr si, [rdx]
  call .dispose.raw.5
  add rdx, word.size
  dec edi
  jnz .dispose.raw.4
  ret
.dispose.raw.5:  ; PT
  mov ebp, 4096 / word.size
.dispose.raw.6:
  ldaddr a, [rsi]
  call memory.disposepage
  add rsi, word.size
  dec ebp
  jnz .dispose.raw.6
  ret

  ; @const
  ; in: a = octet-buffer id
  ; in: d = octet-wised index
  ; out: a = nil | mapped address
.index:
  pushs c, d, si
  addr_from_id c, a
  mov rcx, [rcx + object.content]
  test rcx, rcx
  jz .index.2
  mov rax, rdx
%ifdef OBJECT_32_BYTES
  shr rax, 9 + 9 + 9 + 12
%else  ; OBJECT_32_BYTES
  shr rax, 10 + 10 + 10 + 12
%endif
  jnz .index.2  ; invalid index
  mov rax, rdx
%ifdef OBJECT_32_BYTES
  shr rax, 9 + 9 + 12
%else  ; OBJECT_32_BYTES
  shr rax, 10 + 10 + 12
%endif
  ldaddr si, [rcx + rax * word.size]
  jz .index.2
  mov rax, rdx
%ifdef OBJECT_32_BYTES
  shr rax, 9 + 12
%else  ; OBJECT_32_BYTES
  shr rax, 10 + 12
%endif  ; OBJECT_32_BYTES
  and eax, 0x03ff
  ldaddr c, [rsi + rax * word.size]
  jz .index.2
  mov rax, rdx
  shr rax, 12
  and eax, 0x03ff
  xor rsi, rsi
  mov esi, [rcx + rax * word.size]
  shl rsi, 4
  jz .index.2
  and rdx, 0x0fff
  lea rax, [rsi + rdx]
.index.1:
  pops c, d, si
  ret
.index.2:
  ldnil a
  jmp .index.1

  ; in: a = octet-buffer id
  ; in: d = octet-wised index
  ; out: a = mapped address
.newindex:
  pushs c, d, si, di
  addr_from_id c, a
  mov rsi, [rcx + object.content]
  test rsi, rsi
  jnz .newindex.1
  call memory.newpage
  call memory.zerofill
  mov rsi, rax
  mov [rcx + object.content], rax
.newindex.1:
  mov rcx, rsi
  mov rdi, rdx
%ifdef OBJECT_32_BYTES
  shr rdi, 9 + 9 + 9 + 12
%else  ; OBJECT_32_BYTES
  shr rdi, 10 + 10 + 10 + 12
%endif  ; OBJECT_32_BYTES
  jnz .newindex.nil  ; invalid index
  mov rdi, rdx
%ifdef OBJECT_32_BYTES
  shr rdi, 9 + 9 + 12
%else  ; OBJECT_32_BYTES
  shr rdi, 10 + 10 + 12
%endif  ; OBJECT_32_BYTES
  ldaddr si, [rcx + rdi * word.size]
  testaddr si
  jnz .newindex.2
  call memory.newpage
  call memory.zerofill
  mov rsi, rax
  id_from_addr a
  stid [rcx + rdi * word.size], a
.newindex.2:
  mov rdi, rdx
%ifdef OBJECT_32_BYTES
  shr rdi, 9 + 12
  and rdi, 0x01ff
%else  ; OBJECT_32_BYTES
  shr rdi, 10 + 12
  and rdi, 0x03ff
%endif  ; OBJECT_32_BYTES
  ldaddr c, [rsi + rdi * word.size]
  testaddr c
  jnz .newindex.3
  call memory.newpage
  call memory.zerofill
  mov rcx, rax
  id_from_addr a
  stid [rsi + rdi * word.size], a
.newindex.3:
  mov rdi, rdx
  shr rdi, 12
%ifdef OBJECT_32_BYTES
  and rdi, 0x01ff
%else  ; OBJECT_32_BYTES
  and rdi, 0x03ff
%endif  ; OBJECT_32_BYTES
  ldaddr si, [rcx + rdi * word.size]
  testaddr si
  jnz .newindex.4
  call memory.newpage
  call memory.zerofill
  mov rsi, rax
  id_from_addr a
  stid [rcx + rdi * word.size], a
.newindex.4:
  and rdx, 0x0fff
  lea rax, [rsi + rdx]
.newindex.5:
  pops c, d, si, di
  ret
.newindex.nil:
  ldnil a
  jmp .newindex.5

%endif  ; OCTET_BUFFER_ASM_

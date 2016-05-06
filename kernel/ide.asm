%ifndef IDE_ASM_
%define IDE_ASM_

ide:
  ; in: a = table id
  ; in/out: d = int:64 next entry number
.init:
  push rax
  push rbx
  push rcx
  push rsi
  push rdi
  push rbp
  mov esi, eax
  mov rdi, rdx
  ; first, detect device
  mov ecx, 0x01f0
  call .init.1
  mov ecx, 0x0170
  call .init.1
  ; then, enable interrupts
  mov al, 0x00
  mov dx, 0x03f6
  out dx, al
  call interrupts.enable.ata
  mov rdx, rdi
  pop rbp
  pop rdi
  pop rsi
  pop rcx
  pop rbx
  pop rax
  ret

  ; in: c = port number
  ; in: si = table id
  ; in/out: di = int:64 next entry number
.init.1:
  ; Device that command completed or power-on, hardware or software resetted,
  ; state is the HIx.
  ; so first, wait BSY = 0 & DRQ = 0
  call .wait.bsy.drq
  jc return.false
  ; then, run EXECUTE DEVICE DIAGNOSTIC command
  lea edx, [ecx + 7]
  mov al, 0x90
  out dx, al
  ; Note that in this time, do not use IRQ-wait because device may not present.
  call .wait.bsy
  jc return.false
  lea edx, [ecx + 6]
  mov al, 0x00
  out dx, al
  call .wait.bsy.drq
  jc .init.2
  xor ebx, ebx
  call .init.3
.init.2:
  lea edx, [ecx + 6]
  mov al, 0x10
  out dx, al
  call .wait.bsy.drq
  jc return.false
  mov ebx, 1
  call .init.3
  jmp return.true

  ; in: b = device number
  ; in: c = port number
  ; in: si = table id
  ; in/out: di = int:64 next entry number
.init.3:
  ; read diagnostic code
  lea edx, [ecx + 1]
  in al, dx
  and al, 0x7f
  cmp al, 0x01
  jne return.false
  ; read signature
  lea edx, [ecx + 4]
  in al, dx
  mov ah, al
  inc edx
  in al, dx
  test ah, ah
  jz .init.ata
  cmp ah, 0x14
  je .init.atapi
  jmp return.false
.init.ata:
  test al, al
  jnz return.false
  mov ebp, device.ata
  jmp .init.4
.init.atapi:
  cmp al, 0xeb
  jne return.false
  mov ebp, device.atapi
.init.4:
  call device.new
  xor rdx, rdx
  mov edx, eax
  shl rdx, 4
  call objects.new.chunk
  mov [rax + object.internal.content], ecx
  mov [rax + object.internal.content + 4], ebx
  mov [rax + object.internal.content + 8], ebp
  shr rax, 4
  mov [rdx + object.content + 4], eax
  shr rdx, 4
  push rcx
  mov ecx, edx
  call integer.new
  mov rdx, rdi
  inc rdi
  call integer.set
  mov edx, eax
  mov eax, esi
  call table.newindex
  mov eax, edx
  call objects.unref
  pop rcx
  ret

  ; in: a = output address
  ; in: si = LBA
.readsector:
  ; HI4
  push rax
  push rbx
  push rdx
  push rsi
  push rdi
  push rax
  mov ebx, [edi + 4]
  call .wait.bsy.drq
  jc .readsector.failed
  ; HP0
  ; first, send PACKET Command
  lea edx, [ebx + 1]
  mov al, 0x00
  out dx, al  ; OVL = 0, DMA = 0
  lea edx, [ebx + 4]
  out dx, al
  mov al, 2048 / 256
  inc edx
  out dx, al
  lea edx, [ebx + 7]
  mov al, 0xa0
  out dx, al
  call .wait.bsy.ndrq
  jc .readsector.failed
  ; HP1
  ; then, create packet and send it
  xor edx, edx
  sub rsp, 16
  mov [rsp], edx
  mov [rsp + 4], edx
  mov [rsp + 8], edx
  mov byte [rsp], 0xa8  ; READ (12) Command
  bswap esi
  mov [rsp + 2], esi
  mov byte [rsp + 8], 2048 / 256
  mov rsi, rsp
  mov ecx, 6
  mov edx, ebx
  rep outsw
  add rsp, 16
  ; HP3
  ; wait interrupt
  call .hlt.bsy.ndrq
  jc .readsector.failed
  mov edx, ebx
  pop rdi
  mov ecx, 2048 / 2
  rep insw
  pop rdi
  pop rsi
  pop rdx
  pop rbx
  pop rax
  jmp return.true
.readsector.failed:
  pop rax
  pop rdi
  pop rsi
  pop rdx
  pop rbx
  pop rax
  jmp return.false

.wait.bsy.drq:
  lea edx, [ecx + 7]
.wait.bsy.drq.1:
  in al, dx
  test al, 0x21  ; ERR | DF
  jnz return.false
  test al, 0x88  ; BSY | DRQ
  jnz .wait.bsy.drq.1
  jmp return.true

.wait.bsy:
  lea edx, [ecx + 7]
.wait.bsy.1:
  in al, dx
  test al, 0x21  ; ERR | DF
  jnz return.false
  test al, 0x80  ; BSY
  jnz .wait.bsy.1
  jmp return.true

.wait.bsy.ndrq:
  lea edx, [ecx + 7]
.wait.bsy.ndrq.1:
  in al, dx
  test al, 0x21  ; ERR | DF
  jnz return.false
  test al, 0x80  ; BSY
  jnz .wait.bsy.ndrq.1
  test al, 0x08  ; DRQ
  jz .wait.bsy.ndrq.1
  jmp return.true

.wait.drdy:
  lea edx, [ecx + 7]
.wait.drdy.1:
  in al, dx
  test al, 0x21  ; ERR | DF
  jnz return.false
  test al, 0x40  ; DRDY
  jz .wait.drdy
  jmp return.true

.hlt.bsy.ndrq:
  lea edx, [ecx + 7]
.hlt.bsy.ndrq.1:
  hlt
  in al, dx
  test al, 0x21  ; ERR | DF
  jnz return.false
  test al, 0x80  ; BSY
  jnz .hlt.bsy.ndrq.1
  test al, 0x08  ; DRQ
  jz .hlt.bsy.ndrq.1
  jmp return.true

  align 8
.vtable.atapi:
  dq .readsector

%endif  ; IDE_ASM_

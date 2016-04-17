%ifndef ATA_ASM_
%define ATA_ASM_

ata:
.init:
  ; first, detect device
  mov edi, .info0
  call .init.1
  mov edi, .info1
  call .init.1
  ; then, enable interrupts
  mov al, 0x00
  mov dx, 0x03f6
  out dx, al
  ; mov dx, 0x0376
  ; out dx, al
  call interrupts.enable.ata
  ret
.init.1:
  ; Device that command completed or power-on, hardware or software resetted,
  ; state is the HIx.
  ; so first, wait BSY = 0 & DRQ = 0
  mov ebx, [edi + 4]
  call .wait.bsy.drq
  jc return.false
  ; then, run EXECUTE DEVICE DIAGNOSTIC command
  lea edx, [ebx + 7]
  mov al, 0x90
  out dx, al
  ; Note that in this time, do not use IRQ-wait because device may not present.
  call .wait.bsy
  jc return.false
  ; read signature
  lea edx, [ebx + 4]
  in al, dx
  test al, al
  jz .init.ata
  cmp al, 0x14
  jne return.false
.init.atapi:
  inc edx
  in al, dx
  cmp al, 0xeb
  jne return.false
  ; to set DRDY, run IDENTIFY PACKET DEVICE command
  call .wait.bsy.drq
  jc return.false
  lea edx, [ebx + 6]
  mov al, 0x00
  out dx, al
  call .wait.bsy.drq
  jc return.false
  lea edx, [ebx + 7]
  mov al, 0xa1
  out dx, al
  call .wait.bsy.ndrq
  jc return.false
  call memory.newpage@s
  push rax
  push rdi
  mov rdi, rax
  mov edx, ebx
  mov ecx, 256
  rep insw
  pop rdi
  pop rax
  call memory.disposepage@s
  mov byte [edi], 3
  ret
.init.ata:
  mov byte [edi], 1
  ret

.select.boot:
  mov ax, [0x0800]
  cmp ax, 2
  je .select.cd
  jmp return.false

.select.cd:
  mov ebx, .vtable
  mov edi, .info0
  mov eax, [edi]
  test eax, 2
  jnz return.true
  mov edi, .info1
  mov eax, [edi]
  test eax, 2
  jnz return.true
  jmp return.false

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
  lea edx, [ebx + 7]
.wait.bsy.drq.1:
  in al, dx
  test al, 0x21  ; ERR | DF
  jnz return.false
  test al, 0x88  ; BSY | DRQ
  jnz .wait.bsy.drq.1
  jmp return.true

.wait.bsy:
  lea edx, [ebx + 7]
.wait.bsy.1:
  in al, dx
  test al, 0x21  ; ERR | DF
  jnz return.false
  test al, 0x80  ; BSY
  jnz .wait.bsy.1
  jmp return.true

.wait.bsy.ndrq:
  lea edx, [ebx + 7]
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
  lea edx, [ebx + 7]
.wait.drdy.1:
  in al, dx
  test al, 0x21  ; ERR | DF
  jnz return.false
  test al, 0x40  ; DRDY
  jz .wait.drdy
  jmp return.true

.hlt.bsy.ndrq:
  lea edx, [ebx + 7]
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

  align 4
; bit field: 0 = Exist, 1 = Packet
.info0:
  dd 0
  dd 0x01f0
.info1:
  dd 0
  dd 0x0170

  align 8
.vtable:
  dq .readsector

%endif  ; ATA_ASM_

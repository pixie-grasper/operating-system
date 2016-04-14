%ifndef ATA_ASM_
%define ATA_ASM_

ata:
.init:
  ; first, detect device
  mov bx, 0x01f0
  mov edi, .info0
  call .init.1
  mov bx, 0x0170
  mov edi, .info1
  call .init.1
  ; then, enable interrupts
  mov dx, 0x03f6
  mov al, 0x0a
  out dx, al
  call interrupts.enable.ata
  ret
.init.1:
  ; Device that command completed or power-on, hardware or software resetted,
  ; state is the HIx.
  ; so first, wait BSY = 0 & DRQ = 0
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
  mov rdi, rax
  mov edx, ebx
  mov ecx, 256
  rep insw
  pop rax
  call memory.disposepage@s
  mov byte [edi], 3
  ret

.init.ata:
  mov byte [edi], 1
  ret

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

.info0: dd 0
.info1: dd 0

%endif  ; ATA_ASM_

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
  mov dx, 0x0376
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
  addr_from_id d, a
  ldaddr a, [rdx + object.content + word.size]
  mov [rax + object.internal.content], ecx
  mov [rax + object.internal.content + word.size], ebx
  mov [rax + object.internal.padding], bpl
  id_from_addr d
  push rcx
  mov ecx, edx
  call integer.new
  mov rdx, rdi
  inc rdi
  call integer.set
  movid d, a
  movid a, si
  call table.newindex
  movid a, d
  call objects.unref
  pop rcx
  ret

  ; in: a = port number
  ; in: d = device number
.isdiskdevice:
  push rax
  push rbx
  push rcx
  push rdx
  push rsi
  push rdi
  mov ecx, eax
  mov ebx, edx
  shl ebx, 4
  call .wait.bsy.drq
  jc .isdiskdevice.failed
  ; first, select device
  lea edx, [ecx + 6]
  mov al, bl
  out dx, al
  call .wait.bsy.drq
  ; then, send PACKET Command
  lea edx, [ecx + 1]
  mov al, 0x00
  out dx, al
  inc edx
  out dx, al
  add edx, 2
  out dx, al
  mov al, 4096 / 256
  inc edx
  out dx, al
  lea edx, [ecx + 7]
  mov al, 0xa0
  out dx, al
  call .wait.bsy.ndrq
  jc .isdiskdevice.failed
  ; then, create packet and send it
  xor edx, edx
  sub rsp, 16
  mov [rsp], edx
  mov [rsp + 4], edx
  mov [rsp + 8], edx
  mov byte [rsp], 0x12  ; Inquiry Command
  mov byte [rsp + 4], 96
  mov rsi, rsp
  mov edx, ecx
  mov ecx, 6
  rep outsw
  add rsp, 16
  mov ecx, edx
  call .hlt.bsy.ndrq
  jc .isdiskdevice.failed
  call memory.newpage@s
  mov rdi, rax
  mov edx, ecx
  mov ecx, 96 / 2
  rep insw
  mov ebx, [rax]
  and ebx, 0x1f
  call memory.disposepage@s
  cmp ebx, 5
  jne .isdiskdevice.failed
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  pop rax
  jmp return.true
.isdiskdevice.failed:
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  pop rax
  jmp return.false

  ; in: a = port number
  ; in: d = device number
.cd.lock:
  push rax
  push rbx
  push rcx
  push rdx
  push rsi
  mov ecx, eax
  mov ebx, edx
  shl ebx, 4
  call .wait.bsy.drq
  jc .cd.lock.end
  ; first, select device
  lea edx, [ecx + 6]
  mov al, bl
  out dx, al
  call .wait.bsy.drq
  ; then, send PACKET Command
  lea edx, [ecx + 1]
  mov al, 0x00
  out dx, al
  inc edx
  out dx, al
  add edx, 2
  out dx, al
  inc edx
  out dx, al
  lea edx, [ecx + 7]
  mov al, 0xa0
  out dx, al
  call .wait.bsy.ndrq
  jc .cd.lock.end
  ; then, create packet and send it
  xor edx, edx
  sub rsp, 16
  mov [rsp], edx
  mov [rsp + 4], edx
  mov [rsp + 8], edx
  mov byte [rsp], 0x1e  ; Prevent medium removal Command
  mov byte [rsp + 4], 1
  mov rsi, rsp
  mov edx, ecx
  mov ecx, 6
  rep outsw
  add rsp, 16
.cd.lock.end:
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  pop rax
  ret

  ; in: a = port number
  ; in: d = device number
.cd.unlock:
  push rax
  push rbx
  push rcx
  push rdx
  push rsi
  mov ecx, eax
  mov ebx, edx
  shl ebx, 4
  call .wait.bsy.drq
  jc .cd.unlock.end
  ; first, select device
  lea edx, [ecx + 6]
  mov al, bl
  out dx, al
  call .wait.bsy.drq
  ; then, send PACKET Command
  lea edx, [ecx + 1]
  mov al, 0x00
  out dx, al
  inc edx
  out dx, al
  add edx, 2
  out dx, al
  inc edx
  out dx, al
  lea edx, [ecx + 7]
  mov al, 0xa0
  out dx, al
  call .wait.bsy.ndrq
  jc .cd.unlock.end
  ; then, create packet and send it
  xor edx, edx
  sub rsp, 16
  mov [rsp], edx
  mov [rsp + 4], edx
  mov [rsp + 8], edx
  mov byte [rsp], 0x1e  ; Allow medium removal Command
  mov rsi, rsp
  mov edx, ecx
  mov ecx, 6
  rep outsw
  add rsp, 16
.cd.unlock.end:
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  pop rax
  ret

  ; in: a = address of the buffer
  ; in: b = LBA
  ; in: c = port number
  ; in: d = device number
  ; out: a = address of the buffer or nil
.read.atapi:
  push rbx
  push rcx
  push rdx
  push rsi
  push rdi
  mov rdi, rax
  mov esi, edx
  shl esi, 4
  call .wait.bsy.drq
  jc .read.atapi.failed
  ; first, select device
  lea edx, [ecx + 6]
  mov eax, esi
  out dx, al
  call .wait.bsy.drq
  ; then, send PACKET Command
  lea edx, [ecx + 1]
  mov al, 0x00
  out dx, al
  inc edx
  out dx, al
  add edx, 2
  out dx, al
  mov al, 4096 / 256
  inc edx
  out dx, al
  lea edx, [ecx + 7]
  mov al, 0xa0
  out dx, al
  call .wait.bsy.ndrq
  jc .read.atapi.failed
  ; then, create packet and send it
  xor edx, edx
  sub rsp, 16
  mov [rsp], edx
  mov [rsp + 4], edx
  mov [rsp + 8], edx
  mov byte [rsp], 0xa8  ; Read Command
  bswap ebx
  mov [rsp + 2], ebx
  mov byte [rsp + 9], 2  ; sector count = 2
  mov rsi, rsp
  mov edx, ecx
  mov ecx, 6
  rep outsw
  add rsp, 16
  mov ecx, edx
  call .hlt.bsy.ndrq
  jc .read.atapi.failed
  mov rax, rdi
  mov edx, ecx
  mov ecx, 4096 / 2
  rep insw
  jmp .read.atapi.end
.read.atapi.failed:
  xor rax, rax
.read.atapi.end:
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  ret

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

%endif  ; IDE_ASM_

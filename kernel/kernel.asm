  section .text vstart=0x2000
  bits 64

entry:
  mov rsp, 0x00080000
  call memory.init
  jc error.notenoughmemory
  mov rsi, msg.ok
  call console_out.prints
  jmp end

error:
.notenoughmemory:
  mov rsi, msg.nem
  call console_out.prints
  jmp end

end:
  hlt
  jmp end

%include "console-out.asm"
%include "memory.asm"

msg:
.ok: db 'OK.', 0
.nem: db 'Memory: ', 0

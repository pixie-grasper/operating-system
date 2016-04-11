  section .text vstart=0x2000
  bits 64
  cpu x64

entry:
  mov rsp, 0x00080000
  mov rsi, okmsg
  call console_out.prints
  mov rax, 1234567890
  call console_out.printi
  jmp end

end:
  hlt
  jmp end

%include "console-out.asm"

okmsg: db 'Hello.', 0


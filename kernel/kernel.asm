  section .text vstart=0x2000
  bits 64

entry:
  mov rsp, 0x00080000
  call memory.init
  jc error.notenoughmemory
  call descriptor_tables.init
  mov rsi, msg.ok
  call console_out.prints
  jmp end

error:
.notenoughmemory:
  mov rsi, msg.nem
  call console_out.prints
  jmp end

.failed:
  mov rsi, msg.bad
  call console_out.prints
  jmp end

end:
  hlt
  jmp end

%include "console-out.asm"
%include "memory.asm"
%include "descriptor-tables.asm"

msg:
.ok: db 'OK.', 0
.bad: db 'bad.', 0
.nem: db 'Not enough memory.', 0

; one page for the GDT, one for the TLS
global_page_size equ 2
global_page_addr: dd 0

  section .text vstart=0x00042000
  bits 64

entry:
  mov rsp, 0x00080000
  call memory.init
  jc error.notenoughmemory
  call descriptor_tables.init
  call console_out.init
  mov rsi, msg.initializing
  call console_out.prints
  call interrupts.init
  call objects.init
  call device.init
  mov rsi, msg.ok
  call console_out.prints
  jmp end

error:
.notenoughmemory:
  mov rsi, msg.nem
  call console_out.prints@us  ; console_out is not initialized, use unsafe function
  jmp end

.failed:
  mov rsi, msg.bad
  call console_out.prints
  jmp end

end:
  hlt
  jmp end

%include "console-out.asm"
%include "device.asm"
%include "descriptor-tables.asm"
%include "memory.asm"
%include "objects.asm"

msg:
.initializing: db 'Initializing... ', 0
.disc: db 'Disc Loading... ', 0
.ok: db 'OK.', 0x0a, 0
.bad: db 'Failed.', 0
.nem: db 'Not enough memory.', 0
.device.found: db ' Device(s) found.', 0

; one page for the GDT, one for the IDT, one for the TLS
global_page_size equ 3
global_page_addr: dd 0

TLS:
.memory.tablelookahead equ 0  ; .. 3
.objects.heap equ 8  ; .. 15

  section .text vstart=0x2000
  bits 64
  cpu x64

entry:
  mov rsp, 0x00080000
  mov rsi, okmsg
  call print
  jmp end

end:
  hlt
  jmp end

print:
  mov ah, 0x07
  mov edi, [graphics_current_pos]
.l1:
  mov al, [rsi]
  test al, al
  jz .l2
  mov [edi], ax
  add edi, 2
  inc rsi
  jmp .l1
.l2:
  mov [graphics_current_pos], edi
  ret

  align 16
  section .data vstart=0x2000+($-$$)
graphics_current_pos: dd 0x000b8000
okmsg: db 'Hello.', 0


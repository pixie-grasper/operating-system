%ifndef MACRO_ASM_
%define MACRO_ASM_

%define a.32 eax
%define b.32 ebx
%define c.32 ecx
%define d.32 edx
%define si.32 esi
%define di.32 edi
%define bp.32 ebp
%define sp.32 esp
%define r8.32 r8d
%define r9.32 r9d
%define r10.32 r10d
%define r11.32 r11d
%define r12.32 r12d
%define r13.32 r13d
%define r14.32 r14d
%define r15.32 r15d

%define a.64 rax
%define b.64 rbx
%define c.64 rcx
%define d.64 rdx
%define si.64 rsi
%define di.64 rdi
%define bp.64 rbp
%define sp.64 rsp
%define r8.64 r8
%define r9.64 r9
%define r10.64 r10
%define r11.64 r11
%define r12.64 r12
%define r13.64 r13
%define r14.64 r14
%define r15.64 r15

; %define OBJECT_32_BYTES

%ifdef OBJECT_32_BYTES

%define word.size 8
%define did dq

%macro addr_from_id 2
  mov %1.64, %2.64
%endmacro

%macro id_from_addr 1
%endmacro

%macro ldaddr 2
  mov %1.64, %2
%endmacro

%macro testaddr 1
  test %1.64, %1.64
%endmacro

%macro staddr 2
  mov %1, %2.64
%endmacro

%macro ldid 2
  mov %1.64, %2
%endmacro

%macro stid 2
  mov %1, %2.64
%endmacro

%macro movid 2
  mov %1.64, %2.64
%endmacro

%macro testid 1
  test %1.64, %1.64
%endmacro

%macro cmpid 2
  cmp %1.64, %2.64
%endmacro

%macro clear_before_ld 1
%endmacro

%macro ldt 1
  mov %1.64, 1
%endmacro

%else  ; OBJECT_32_BYTES

%define word.size 4
%define did dd

%macro addr_from_id 2
  xor %1.64, %1.64
  mov %1.32, %2.32
  shl %1.64, 4
%endmacro

%macro id_from_addr 1
  shr %1.64, 4
%endmacro

%macro ldaddr 2
  xor %1.64, %1.64
  mov %1.32, %2
  shl %1.64, 4
%endmacro

%macro testaddr 1
%endmacro

%macro staddr 2
  shr %2.64, 4
  mov %1, %2.32
%endmacro

%macro ldid 2
  mov %1.32, %2
%endmacro

%macro stid 2
  mov %1, %2.32
%endmacro

%macro movid 2
  mov %1.32, %2.32
%endmacro

%macro testid 1
  test %1.32, %1.32
%endmacro

%macro cmpid 2
  cmp %1.32, %2.32
%endmacro

%macro clear_before_ld 1
  xor %1.64, %1.64
%endmacro

%macro ldt 1
  mov %1.32, 1
%endmacro

%endif  ; OBJECT_32_BYTES

%macro ldnil 1
  xor %1.64, %1.64
%endmacro

%macro pushs 1-*
%rep %0
  push %1.64
%rotate 1
%endrep
%endmacro

%macro pops 1-*
%rep %0
%rotate -1
  pop %1.64
%endrep
%endmacro

%endif  ; MACRO_ASM_

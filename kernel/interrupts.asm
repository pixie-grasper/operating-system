%ifndef INTERRUPTS_ASM_
%define INTERRUPTS_ASM_

interrupts:
.init:
  ; configure pic
  mov al, 0x11  ; configure start
  out 0x20, al
  dd 0x00eb00eb
  out 0xa0, al
  dd 0x00eb00eb
  mov al, 0x20  ; shift to 0x20..0x27
  out 0x21, al
  dd 0x00eb00eb
  mov al, 0x28  ; shift to 0x28..0x2f
  out 0xa1, al
  dd 0x00eb00eb
  mov al, 0x04
  out 0x21, al  ; master.2 <-> slave.int
  dd 0x00eb00eb
  mov al, 0x02
  out 0xa1, al
  dd 0x00eb00eb
  mov al, 0x01  ; use 8086 mode
  out 0x21, al
  dd 0x00eb00eb
  out 0xa1, al
  dd 0x00eb00eb
  ; disable pic without timer
  mov al, 0xff
  out 0xa1, al
  dd 0x00eb00eb
  mov al, 0xfa
  out 0x21, al
  dd 0x00eb00eb
  ; enable interrupt
  sti
  ret

.handler_00:
.handler_01:
.handler_02:
.handler_03:
.handler_04:
.handler_05:
.handler_06:
.handler_07:
.handler_08:
.handler_09:
.handler_0A:
.handler_0B:
.handler_0C:
.handler_0D:
.handler_0E:
.handler_0F:
.handler_10:
.handler_11:
.handler_12:
.handler_13:
.handler_14:
.handler_15:
.handler_16:
.handler_17:
.handler_18:
.handler_19:
.handler_1A:
.handler_1B:
.handler_1C:
.handler_1D:
.handler_1E:
.handler_1F:
  iretq

.handler_20:  ; timer
  pushfq
  push rax
  mov ax, ds
  push rax
  mov ax, 1 * 8
  mov ds, ax
  mov al, 0x20
  out 0x20, al
  inc qword [.timer.count]
  pop rax
  mov ds, ax
  pop rax
  popfq
  iretq

.timer.count dq 0

.handler_21:
.handler_22:
.handler_23:
.handler_24:
.handler_25:
.handler_26:
.handler_27:
.handler_28:
.handler_29:
.handler_2A:
.handler_2B:
.handler_2C:
.handler_2D:
.handler_2E:
.handler_2F:
.handler_30:
.handler_31:
.handler_32:
.handler_33:
.handler_34:
.handler_35:
.handler_36:
.handler_37:
.handler_38:
.handler_39:
.handler_3A:
.handler_3B:
.handler_3C:
.handler_3D:
.handler_3E:
.handler_3F:
.handler_40:
.handler_41:
.handler_42:
.handler_43:
.handler_44:
.handler_45:
.handler_46:
.handler_47:
.handler_48:
.handler_49:
.handler_4A:
.handler_4B:
.handler_4C:
.handler_4D:
.handler_4E:
.handler_4F:
.handler_50:
.handler_51:
.handler_52:
.handler_53:
.handler_54:
.handler_55:
.handler_56:
.handler_57:
.handler_58:
.handler_59:
.handler_5A:
.handler_5B:
.handler_5C:
.handler_5D:
.handler_5E:
.handler_5F:
.handler_60:
.handler_61:
.handler_62:
.handler_63:
.handler_64:
.handler_65:
.handler_66:
.handler_67:
.handler_68:
.handler_69:
.handler_6A:
.handler_6B:
.handler_6C:
.handler_6D:
.handler_6E:
.handler_6F:
.handler_70:
.handler_71:
.handler_72:
.handler_73:
.handler_74:
.handler_75:
.handler_76:
.handler_77:
.handler_78:
.handler_79:
.handler_7A:
.handler_7B:
.handler_7C:
.handler_7D:
.handler_7E:
.handler_7F:
.handler_80:
.handler_81:
.handler_82:
.handler_83:
.handler_84:
.handler_85:
.handler_86:
.handler_87:
.handler_88:
.handler_89:
.handler_8A:
.handler_8B:
.handler_8C:
.handler_8D:
.handler_8E:
.handler_8F:
.handler_90:
.handler_91:
.handler_92:
.handler_93:
.handler_94:
.handler_95:
.handler_96:
.handler_97:
.handler_98:
.handler_99:
.handler_9A:
.handler_9B:
.handler_9C:
.handler_9D:
.handler_9E:
.handler_9F:
.handler_A0:
.handler_A1:
.handler_A2:
.handler_A3:
.handler_A4:
.handler_A5:
.handler_A6:
.handler_A7:
.handler_A8:
.handler_A9:
.handler_AA:
.handler_AB:
.handler_AC:
.handler_AD:
.handler_AE:
.handler_AF:
.handler_B0:
.handler_B1:
.handler_B2:
.handler_B3:
.handler_B4:
.handler_B5:
.handler_B6:
.handler_B7:
.handler_B8:
.handler_B9:
.handler_BA:
.handler_BB:
.handler_BC:
.handler_BD:
.handler_BE:
.handler_BF:
.handler_C0:
.handler_C1:
.handler_C2:
.handler_C3:
.handler_C4:
.handler_C5:
.handler_C6:
.handler_C7:
.handler_C8:
.handler_C9:
.handler_CA:
.handler_CB:
.handler_CC:
.handler_CD:
.handler_CE:
.handler_CF:
.handler_D0:
.handler_D1:
.handler_D2:
.handler_D3:
.handler_D4:
.handler_D5:
.handler_D6:
.handler_D7:
.handler_D8:
.handler_D9:
.handler_DA:
.handler_DB:
.handler_DC:
.handler_DD:
.handler_DE:
.handler_DF:
.handler_E0:
.handler_E1:
.handler_E2:
.handler_E3:
.handler_E4:
.handler_E5:
.handler_E6:
.handler_E7:
.handler_E8:
.handler_E9:
.handler_EA:
.handler_EB:
.handler_EC:
.handler_ED:
.handler_EE:
.handler_EF:
.handler_F0:
.handler_F1:
.handler_F2:
.handler_F3:
.handler_F4:
.handler_F5:
.handler_F6:
.handler_F7:
.handler_F8:
.handler_F9:
.handler_FA:
.handler_FB:
.handler_FC:
.handler_FD:
.handler_FE:
.handler_FF:
  iretq

.addresslist:
  dd .handler_00, .handler_01, .handler_02, .handler_03, .handler_04, .handler_05, .handler_06, .handler_07
  dd .handler_08, .handler_09, .handler_0A, .handler_0B, .handler_0C, .handler_0D, .handler_0E, .handler_0F
  dd .handler_10, .handler_11, .handler_12, .handler_13, .handler_14, .handler_15, .handler_16, .handler_17
  dd .handler_18, .handler_19, .handler_1A, .handler_1B, .handler_1C, .handler_1D, .handler_1E, .handler_1F
  dd .handler_20, .handler_21, .handler_22, .handler_23, .handler_24, .handler_25, .handler_26, .handler_27
  dd .handler_28, .handler_29, .handler_2A, .handler_2B, .handler_2C, .handler_2D, .handler_2E, .handler_2F
  dd .handler_30, .handler_31, .handler_32, .handler_33, .handler_34, .handler_35, .handler_36, .handler_37
  dd .handler_38, .handler_39, .handler_3A, .handler_3B, .handler_3C, .handler_3D, .handler_3E, .handler_3F
  dd .handler_40, .handler_41, .handler_42, .handler_43, .handler_44, .handler_45, .handler_46, .handler_47
  dd .handler_48, .handler_49, .handler_4A, .handler_4B, .handler_4C, .handler_4D, .handler_4E, .handler_4F
  dd .handler_50, .handler_51, .handler_52, .handler_53, .handler_54, .handler_55, .handler_56, .handler_57
  dd .handler_58, .handler_59, .handler_5A, .handler_5B, .handler_5C, .handler_5D, .handler_5E, .handler_5F
  dd .handler_60, .handler_61, .handler_62, .handler_63, .handler_64, .handler_65, .handler_66, .handler_67
  dd .handler_68, .handler_69, .handler_6A, .handler_6B, .handler_6C, .handler_6D, .handler_6E, .handler_6F
  dd .handler_70, .handler_71, .handler_72, .handler_73, .handler_74, .handler_75, .handler_76, .handler_77
  dd .handler_78, .handler_79, .handler_7A, .handler_7B, .handler_7C, .handler_7D, .handler_7E, .handler_7F
  dd .handler_80, .handler_81, .handler_82, .handler_83, .handler_84, .handler_85, .handler_86, .handler_87
  dd .handler_88, .handler_89, .handler_8A, .handler_8B, .handler_8C, .handler_8D, .handler_8E, .handler_8F
  dd .handler_90, .handler_91, .handler_92, .handler_93, .handler_94, .handler_95, .handler_96, .handler_97
  dd .handler_98, .handler_99, .handler_9A, .handler_9B, .handler_9C, .handler_9D, .handler_9E, .handler_9F
  dd .handler_A0, .handler_A1, .handler_A2, .handler_A3, .handler_A4, .handler_A5, .handler_A6, .handler_A7
  dd .handler_A8, .handler_A9, .handler_AA, .handler_AB, .handler_AC, .handler_AD, .handler_AE, .handler_AF
  dd .handler_B0, .handler_B1, .handler_B2, .handler_B3, .handler_B4, .handler_B5, .handler_B6, .handler_B7
  dd .handler_B8, .handler_B9, .handler_BA, .handler_BB, .handler_BC, .handler_BD, .handler_BE, .handler_BF
  dd .handler_C0, .handler_C1, .handler_C2, .handler_C3, .handler_C4, .handler_C5, .handler_C6, .handler_C7
  dd .handler_C8, .handler_C9, .handler_CA, .handler_CB, .handler_CC, .handler_CD, .handler_CE, .handler_CF
  dd .handler_D0, .handler_D1, .handler_D2, .handler_D3, .handler_D4, .handler_D5, .handler_D6, .handler_D7
  dd .handler_D8, .handler_D9, .handler_DA, .handler_DB, .handler_DC, .handler_DD, .handler_DE, .handler_DF
  dd .handler_E0, .handler_E1, .handler_E2, .handler_E3, .handler_E4, .handler_E5, .handler_E6, .handler_E7
  dd .handler_E8, .handler_E9, .handler_EA, .handler_EB, .handler_EC, .handler_ED, .handler_EE, .handler_EF
  dd .handler_F0, .handler_F1, .handler_F2, .handler_F3, .handler_F4, .handler_F5, .handler_F6, .handler_F7
  dd .handler_F8, .handler_F9, .handler_FA, .handler_FB, .handler_FC, .handler_FD, .handler_FE, .handler_FF

%endif  ; INTERRUPTS_ASM_

.section .text
.code16
.global _start
_start:
  cli
  xor %ax, %ax
  mov %ax, %ds
  mov $0x3f8, %dx
  mov $'P', %al
  out %al, %dx
  mov $0xf4, %dx
  mov $0x10, %al
  out %al, %dx
1: hlt
   jmp 1b
.org 510
.word 0xaa55

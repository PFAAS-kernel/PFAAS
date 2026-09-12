#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/freestanding verification
clang --target=i386-unknown-none-elf -c freestanding/boot.S -o build/freestanding/boot.o
ld.lld -m elf_i386 -T freestanding/linker.ld --build-id=none build/freestanding/boot.o -o build/freestanding/pfaas-kernel.elf
llvm-objcopy -O binary build/freestanding/pfaas-kernel.elf build/freestanding/pfaas-boot.img
test "$(stat -c %s build/freestanding/pfaas-boot.img)" -eq 512
llvm-readelf -h -S build/freestanding/pfaas-kernel.elf > verification/freestanding-elf.txt
set +e
timeout 15 qemu-system-x86_64 -machine accel=tcg -display none -serial file:verification/qemu-serial.txt \
  -no-reboot -no-shutdown -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
  -drive file=build/freestanding/pfaas-boot.img,format=raw,if=floppy
qemu_rc=$?
set -e
# isa-debug-exit encodes the guest value as (value << 1) | 1; any prompt exit is evidence of execution.
if [[ $qemu_rc -eq 124 ]]; then
  echo "QEMU guest did not reach the debug-exit device" >&2
  exit 1
fi
grep -q P verification/qemu-serial.txt

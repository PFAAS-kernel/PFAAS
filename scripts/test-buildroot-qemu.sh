#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
kernel=build/buildroot/images/bzImage
initramfs=build/buildroot/images/rootfs.cpio.gz
log=verification/buildroot-qemu-serial.txt
[[ -s "$kernel" && -s "$initramfs" ]]
rm -f "$log"
set +e
timeout 20 qemu-system-x86_64 -machine accel=tcg -m 256M -display none \
  -serial "file:$log" -no-reboot -kernel "$kernel" -initrd "$initramfs" \
  -append 'console=ttyS0 panic=-1'
rc=$?
set -e
[[ $rc -eq 124 || $rc -eq 0 ]]
grep -Eq 'PFAAS minimal Linux baseline|pfaas-baseline login:|Run /init as init process' "$log"

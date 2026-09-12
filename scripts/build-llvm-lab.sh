#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/llvm-lab
CLANG="${CLANG:-clang}"
for src in common http_service_A http_service_B kv_service metrics_service; do
  "$CLANG" -O1 -emit-llvm -c "workloads/synthetic/$src.c" -I workloads/synthetic \
    -ffile-prefix-map="$PWD"=. -fdebug-prefix-map="$PWD"=. -o "build/llvm-lab/$src.bc"
done
llvm-link build/llvm-lab/common.bc build/llvm-lab/http_service_A.bc -o build/llvm-lab/combined.bc
llvm-dis build/llvm-lab/combined.bc -o build/llvm-lab/combined.ll
opt -passes='default<O2>' build/llvm-lab/combined.bc -o build/llvm-lab/optimized.bc
PLUGIN="$(find build -type f -name 'PfaasInventory.so' -print -quit)"
test -n "$PLUGIN"
opt -load-pass-plugin="$PLUGIN" -passes=pfaas-inventory -disable-output \
  build/llvm-lab/combined.bc 2> verification/function-inventory.jsonl
"$CLANG" -fuse-ld=lld -Wl,--build-id=none build/llvm-lab/optimized.bc -o build/llvm-lab/http_A_native
./build/llvm-lab/http_A_native > verification/native-run.txt

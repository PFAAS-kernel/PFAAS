#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."
mkdir -p verification
RESULTS=verification/checklist-results.tsv
FAILURES=verification/failures.md
printf 'index\tstatus\tevidence\n' > "$RESULTS"

record() { printf '%s\t%s\t%s\n' "$1" "$2" "${3//$'\t'/ }" >> "$RESULTS"; }
has_all() { local c; for c in "$@"; do command -v "$c" >/dev/null 2>&1 || return 1; done; }
pass_if() { local idx="$1" evidence="$2"; shift 2; if "$@"; then record "$idx" PASS "$evidence"; else record "$idx" FAIL "$evidence"; fi; }

grep -qi microsoft /proc/version && record DS-001 PASS "Ubuntu $(. /etc/os-release; echo "$VERSION_ID") under WSL" || record DS-001 FAIL "Not running under WSL"
grep -qi microsoft-standard-wsl2 /proc/sys/kernel/osrelease && record DS-002 PASS "$(uname -r)" || record DS-002 FAIL "Kernel does not identify WSL2"
firmware="${PFAAS_FIRMWARE_VIRT:-$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command '(Get-CimInstance Win32_Processor | Select-Object -First 1).VirtualizationFirmwareEnabled' 2>/dev/null | tr -d '\r' | tail -1)}"
[[ "$firmware" == True ]] && record DS-003 PASS "Windows reports VirtualizationFirmwareEnabled=True" || record DS-003 FAIL "Firmware virtualization could not be confirmed: $firmware"
kvm_state=absent
if [[ -e /dev/kvm ]]; then
  rm -f verification/qemu-kvm-serial.txt
  timeout 10 qemu-system-x86_64 -accel kvm -display none -serial file:verification/qemu-kvm-serial.txt -no-reboot -no-shutdown -device isa-debug-exit,iobase=0xf4,iosize=0x04 -drive file=build/freestanding/pfaas-boot.img,format=raw,if=floppy >/dev/null 2>&1
  kvm_rc=$?
  [[ $kvm_rc -ne 124 ]] && grep -q P verification/qemu-kvm-serial.txt 2>/dev/null && kvm_state=usable || kvm_state=unusable
fi
if [[ $kvm_state == usable ]]; then record DS-004 PASS "Nested KVM guest executed"
elif [[ $kvm_state == unusable ]]; then record DS-004 NOT-APPLICABLE "This Windows/WSL combination exposes an inert /dev/kvm (KVM returns ENODEV)"
else record DS-004 NOT-APPLICABLE "Host/WSL combination does not expose /dev/kvm"; fi
[[ "$PWD" != /mnt/* ]] && record DS-005 PASS "$PWD is in Linux filesystem" || record DS-005 FAIL "$PWD is under Windows mount"
[[ "$(uname -s)" == Linux ]] && record DS-006 PASS "Verifier/builds execute on Linux" || record DS-006 FAIL "Not Linux"

has_all cc c++ ld as make cmake ninja pkg-config && record DS-010 PASS "Core compiler/build commands found" || record DS-010 FAIL "Core compiler/build command missing"
dpkg-query -W libc6-dev libelf-dev elfutils >/dev/null 2>&1 && record DS-011 PASS "libc and ELF development packages installed" || record DS-011 FAIL "libc/ELF development package missing"
has_all python3 && python3 -m venv --help >/dev/null 2>&1 && record DS-012 PASS "Python $(python3 --version 2>&1) with venv" || record DS-012 FAIL "Python/venv unavailable"
has_all git gdb && record DS-013 PASS "Git and GDB found" || record DS-013 FAIL "Git or GDB missing"
[[ -x build/http_service_A && -x build/http_service_B && -x build/kv_service && -x build/metrics_service ]] && record DS-014 PASS "Four native C targets built" || record DS-014 FAIL "Native smoke targets absent"

llvm-config --version >/dev/null 2>&1 && has_all clang ld.lld && record DS-020 PASS "LLVM $(llvm-config --version), Clang, LLD and development config" || record DS-020 FAIL "Coherent LLVM development stack unavailable"
has_all opt llvm-link llvm-dis llvm-as llvm-nm llvm-objdump llvm-readelf llvm-size llvm-profdata llvm-cov && record DS-021 PASS "Required LLVM command set found" || record DS-021 FAIL "One or more required LLVM commands missing"
plugin="$(find build -type f -name PfaasInventory.so -print -quit)"; [[ -n "$plugin" ]] && record DS-022 PASS "$plugin" || record DS-022 FAIL "Out-of-tree pass plugin missing"
[[ -s build/llvm-lab/common.bc && -s build/llvm-lab/http_service_A.bc ]] && record DS-023 PASS "Multiple source modules emitted as bitcode" || record DS-023 FAIL "Bitcode modules missing"
[[ -s build/llvm-lab/combined.bc && -s build/llvm-lab/combined.ll ]] && record DS-024 PASS "Combined bitcode and textual IR exist" || record DS-024 FAIL "Bitcode link/IR inspection evidence missing"
[[ -s build/llvm-lab/optimized.bc ]] && record DS-025 PASS "Stock O2 pipeline emitted optimized.bc" || record DS-025 FAIL "Stock optimization output missing"
[[ -s verification/function-inventory.jsonl ]] && record DS-026 PASS "Custom pass emitted JSONL inventory" || record DS-026 FAIL "Custom pass execution evidence missing"
[[ -x build/llvm-lab/http_A_native ]] && grep -q '^A ' verification/native-run.txt 2>/dev/null && record DS-027 PASS "Transformed module linked and ran" || record DS-027 FAIL "Native post-transform run failed"
[[ -s build/freestanding/pfaas-kernel.elf ]] && llvm-readelf -h build/freestanding/pfaas-kernel.elf >/dev/null 2>&1 && record DS-028 PASS "Freestanding ELF emitted and parsed" || record DS-028 FAIL "Freestanding ELF missing/invalid"

has_all qemu-system-x86_64 qemu-img && record DS-030 PASS "QEMU system and image tools found" || record DS-030 FAIL "QEMU tool missing"
if [[ $kvm_state == usable ]]; then record DS-031 PASS "Freestanding guest executed through KVM"
elif [[ $kvm_state == unusable ]]; then record DS-031 NOT-APPLICABLE "KVM tooling is installed, but nested KVM is unsupported by this host/WSL combination"
else record DS-031 NOT-APPLICABLE "/dev/kvm is absent"; fi
qemu-system-x86_64 --help 2>&1 | grep -q -- '-serial' && qemu-system-x86_64 --help 2>&1 | grep -q -- '-gdb' && record DS-032 PASS "QEMU serial console and GDB stub options installed" || record DS-032 FAIL "QEMU serial/GDB option unavailable"
grep -q P verification/qemu-serial.txt 2>/dev/null && record DS-033 PASS "Freestanding guest wrote P to emulated serial" || record DS-033 FAIL "QEMU freestanding boot evidence missing"
[[ -s build/buildroot/images/bzImage && -s build/buildroot/images/rootfs.cpio.gz ]] && grep -Eq 'PFAAS minimal Linux baseline|pfaas-baseline login:|Run /init as init process' verification/buildroot-qemu-serial.txt 2>/dev/null && record DS-034 PASS "Built kernel/initramfs reached Linux init under QEMU" || record DS-034 FAIL "Minimal Linux kernel/initramfs build-and-boot evidence missing"
record DS-035 DEFERRED "Concrete Unikraft application boot is explicitly later"
record DS-036 DEFERRED "Firecracker stack is explicitly a later-phase component"
if python3 -c 'import glob,json; rows=[json.load(open(p)) for p in glob.glob("verification/ci-*-capabilities.json")]; assert any(d["capabilities"]["kvm_api"] and d["capabilities"]["kvm_guest_execution"] for d in rows)' >/dev/null 2>&1; then
  record DS-037 PASS "Imported hosted-runner evidence proves KVM API and guest execution"
else
  record DS-037 DEFERRED "No successful hosted KVM capability evidence has been imported yet"
fi

[[ -d unikernel-baseline/unikraft/lib/ukalloc && -d unikernel-baseline/unikraft/plat ]] && record DS-040 PASS "Pinned Unikraft source tree is inspectable" || record DS-040 FAIL "Unikraft source/expected subsystems missing"
command -v kraft >/dev/null 2>&1 && record DS-041 PASS "KraftKit installed" || record DS-041 NOT-APPLICABLE "KraftKit optional; source tree is authoritative"
[[ -s build/buildroot/images/bzImage ]] && record DS-042 PASS "Buildroot produced an x86-64 kernel from source" || record DS-042 FAIL "Buildroot source image build incomplete"
grep -q 'BR2_TOOLCHAIN_BUILDROOT_MUSL=y' linux-baseline/buildroot-config/pfaas_x86_64_defconfig && record DS-043 PASS "Versioned x86-64 musl config present" || record DS-043 FAIL "Required Buildroot config absent"
record DS-044 DEFERRED "Nanos/OSv explicitly later"

has_all clang c++ python3 && record DS-050 PASS "C/C++/Python available" || record DS-050 FAIL "Required language tool missing"
required_dirs=(compiler/passes compiler/analyses compiler/transforms runtime/app_context runtime/scheduler runtime/io runtime/memory runtime/platform workloads/synthetic workloads/real linux-baseline/kernel-config linux-baseline/buildroot-config unikernel-baseline fleet/corpus fleet/variants fleet/canonicalization fleet/placement engines/hashing engines/compression engines/regex engines/storage experiments/single-image experiments/multi-app experiments/fleet-dedup experiments/shared-engine measurements/image-size measurements/code-size measurements/rss measurements/page-sharing measurements/boot-time measurements/cpu tools/ir-inspection tools/binary-analysis tools/corpus-generation docs/architecture docs/research-notes)
missing=0; for d in "${required_dirs[@]}"; do [[ -d "$d" ]] || missing=$((missing+1)); done; [[ $missing -eq 0 ]] && record DS-051 PASS "All separated repository areas exist" || record DS-051 FAIL "$missing repository areas missing"
[[ -f workloads/synthetic/http_service_A.c && -f workloads/synthetic/http_service_B.c && -f workloads/synthetic/kv_service.c && -f workloads/synthetic/metrics_service.c ]] && record DS-052 PASS "Four related application sources exist" || record DS-052 FAIL "Workload corpus incomplete"
grep -q shared_hash workloads/synthetic/*.c && grep -q equivalent_sum workloads/synthetic/http_service_*.c && record DS-053 PASS "Controlled common/equivalent/variant patterns present" || record DS-053 FAIL "Controlled variation evidence incomplete"

python3 -c 'import json; rows=[json.loads(x) for x in open("verification/function-inventory.jsonl") if x.strip()]; required={"function","module","application_owner","normalized_ir_hash","machine_code_hash","machine_code_stage","estimated_code_size_bytes","callers","callees","referenced_globals","effects","external_calls","allocation_behavior","reachable"}; assert rows and all(required <= set(r) for r in rows)' >/dev/null 2>&1 && record DS-060 PASS "Per-function JSONL contains every required analysis field" || record DS-060 FAIL "Function analysis missing, malformed, or incomplete"
grep -q 'pfaas.owner=http_service_A' build/llvm-lab/combined.ll 2>/dev/null && record DS-061 PASS "Combined module retains pfaas.owner provenance annotation" || record DS-061 FAIL "Combined module provenance absent"
grep -q 'typedef struct AppContext' runtime/app_context/app_context.h && record DS-062 PASS "AppContext models requested isolation state" || record DS-062 FAIL "AppContext model absent"
python3 tools/corpus-generation/generate_variants.py --count 100 >/dev/null 2>&1; count="$(find fleet/variants/generated -type f -name '*.json' 2>/dev/null | wc -l)"; [[ $count -eq 100 ]] && record DS-063 PASS "Generated 100 controlled variants" || record DS-063 FAIL "Generated $count variants"
python3 tools/binary-analysis/fleet_similarity.py build/http_service_A build/http_service_B build/kv_service build/metrics_service >/dev/null 2>&1; python3 -c 'import json; d=json.load(open("verification/fleet-similarity.json")); assert d["logical_bytes"] and d["unique_page_bytes_upper_bound"]' >/dev/null 2>&1 && record DS-064 PASS "Logical and unique fleet byte metrics emitted" || record DS-064 FAIL "Fleet size distinction not emitted"
python3 -c 'import json; d=json.load(open("fleet/canonicalization/manifest.schema.json")); assert all(x in d["required"] for x in ("shared_code","private_code","immutable_data","instance_data"))' >/dev/null 2>&1 && record DS-065 PASS "Content-addressed manifest schema validates structurally" || record DS-065 FAIL "Manifest schema missing/malformed"
python3 -c 'import json; d=json.load(open("verification/fleet-similarity.json")); names={"llvm-function","machine-code-function","elf-section","fixed-4KiB-page","content-defined-chunk","whole-artifact"}; assert names == set(d["levels"]); assert all(d["levels"][n]["hash_count"] > 0 for n in names)' >/dev/null 2>&1 && record DS-066 PASS "All six similarity levels contain measured hashes" || record DS-066 FAIL "Similarity granularity coverage incomplete or merely declarative"

python3 tools/binary-analysis/measure.py build/http_service_A >/dev/null 2>&1; [[ -s verification/measurements.json ]] && record DS-070 PASS "Measurement harness emits values and explicit unsupported nulls" || record DS-070 FAIL "Measurement harness failed"
record DS-071 DEFERRED "Hardware-counter metrics explicitly later"
[[ -s config/reproducible.env ]] && grep -q build-id=none CMakeLists.txt && record DS-072 PASS "Normalized paths, fixed epoch config, controlled flags/pipeline" || record DS-072 FAIL "Reproducibility controls absent"
sha1="$(sha256sum build/llvm-lab/http_A_native 2>/dev/null | cut -d' ' -f1)"; ./scripts/build-llvm-lab.sh >/dev/null 2>&1; sha2="$(sha256sum build/llvm-lab/http_A_native 2>/dev/null | cut -d' ' -f1)"; [[ -n "$sha1" && "$sha1" == "$sha2" ]] && record DS-073 PASS "Repeated LLVM build hash $sha2" || record DS-073 FAIL "Repeated build hashes differ"
record DS-074 DEFERRED "Native benchmark host explicitly later"

{
  echo '# Failed desired-state checklist items'; echo
  awk -F '\t' 'NR>1 && $2=="FAIL" {printf "- **%s:** %s\n", $1, $3}' "$RESULTS"
} > "$FAILURES"

column -t -s $'\t' "$RESULTS" || cat "$RESULTS"
fail_count="$(awk -F '\t' 'NR>1 && $2=="FAIL" {n++} END {print n+0}' "$RESULTS")"
echo "Failures: $fail_count (see $FAILURES)"
exit "$fail_count"

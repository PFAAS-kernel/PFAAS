# Systems Research Environment — Indexed Desired-State Checklist

This checklist translates the supplied setup document into testable desired-state
requirements. Items marked **Phase 1** are required now. Items marked **Conditional**
are required only when the host exposes the necessary capability. Items marked
**Later** are explicitly not blockers for the initial environment.

## Windows host and WSL

- **DS-001 (Phase 1):** Windows has WSL2 enabled and a mainstream Ubuntu or Debian distribution installed.
- **DS-002 (Phase 1):** The selected distribution runs as WSL version 2.
- **DS-003 (Phase 1):** Hardware virtualization is enabled in firmware and visible to Windows.
- **DS-004 (Conditional, local host):** Nested virtualization is available inside WSL2 only when supported by the Windows/hardware combination; an unsupported local host is not a build-system failure.
- **DS-005 (Phase 1):** The authoritative project repository is stored in the Linux filesystem inside WSL, not under `/mnt/c`.
- **DS-006 (Phase 1):** Builds, tests, compilers, LLVM tools, and QEMU execute inside Linux.

## Core Linux build environment

- **DS-010 (Phase 1):** C compiler, C++ compiler, linker, assembler, GNU make, CMake, Ninja, and pkg-config are installed.
- **DS-011 (Phase 1):** Standard libc development headers and ELF development tooling are installed.
- **DS-012 (Phase 1):** Python 3 and virtual-environment support are installed.
- **DS-013 (Phase 1):** Git and GDB are installed.
- **DS-014 (Phase 1):** The native toolchain successfully builds and runs a nontrivial C/C++ smoke project from source.

## LLVM research toolchain

- **DS-020 (Phase 1):** Clang, LLVM libraries/headers/development packages, and LLD are installed from one coherent LLVM version.
- **DS-021 (Phase 1):** `opt`, `llvm-link`, `llvm-dis`, `llvm-as`, `llvm-nm`, `llvm-objdump`, `llvm-readelf`, `llvm-size`, `llvm-profdata`, and `llvm-cov` are callable.
- **DS-022 (Phase 1):** An out-of-tree LLVM new-pass-manager plugin can be configured and built in C++.
- **DS-023 (Phase 1):** Multiple C sources compile to LLVM bitcode.
- **DS-024 (Phase 1):** Multiple bitcode modules link into one module and can be inspected as textual IR.
- **DS-025 (Phase 1):** Stock LLVM optimization passes run on the combined module.
- **DS-026 (Phase 1):** The custom out-of-tree pass loads and runs on the combined module.
- **DS-027 (Phase 1):** Transformed bitcode links to a runnable native executable.
- **DS-028 (Phase 1):** A freestanding ELF artifact can be emitted and inspected.

## VM tooling

- **DS-030 (Phase 1):** QEMU x86-64 system emulation and QEMU image tooling are installed.
- **DS-031 (Conditional, local host):** QEMU can use KVM when the local `/dev/kvm` implements the KVM API; a merely present inert device does not qualify.
- **DS-032 (Phase 1):** QEMU serial-console and GDB-stub options are available.
- **DS-033 (Phase 1):** QEMU can boot/test a directly supplied freestanding ELF/kernel-like artifact.
- **DS-034 (Phase 1):** The environment contains a reproducible path for building a Linux kernel plus minimal initramfs/rootfs and booting it under QEMU.
- **DS-035 (Later):** Unikernel image boot support is exercised after a concrete Unikraft application image is selected.
- **DS-036 (Later):** Firecracker, jailer, TAP/network namespaces, and virtio inspection tools are added only on a host where KVM works cleanly.
- **DS-037 (Remote development capability):** At least one hosted Linux runner opens the KVM API and executes the checked freestanding guest through QEMU/KVM. This validates KVM functionality, not performance.

## Reference systems

- **DS-040 (Phase 1):** The Unikraft source tree is present and inspectable, including allocator, scheduler, libc, syscall, networking, filesystem, platform, and linker areas.
- **DS-041 (Optional):** KraftKit is installed when convenient; it is not a substitute for the Unikraft source tree.
- **DS-042 (Phase 1):** Buildroot source is present and can build a tiny custom Linux VM image from source.
- **DS-043 (Phase 1):** A versioned Buildroot configuration targets x86-64, Linux, musl, and a minimal BusyBox/initramfs baseline.
- **DS-044 (Later):** Nanos/OSv may be added for comparison but are not initial blockers.

## Languages and repository organization

- **DS-050 (Phase 1):** C is supported for guest applications/runtime experiments, C++ for LLVM passes, and Python for orchestration and measurement.
- **DS-051 (Phase 1):** Repository areas exist for compiler passes/analyses/transforms; runtime context/scheduler/I/O/memory/platform; synthetic/real workloads; Linux and Unikraft baselines; fleet corpus/variants/canonicalization/placement; shared engines; experiments; measurements; analysis tools; and documentation.
- **DS-052 (Phase 1):** A first corpus contains related `http_service_A`, `http_service_B`, `kv_service`, and `metrics_service` applications.
- **DS-053 (Phase 1):** The corpus deliberately includes identical functions, semantically equivalent variants, common code, differing constants, dead features, allocator variation, overlapping parsing/hashing/network logic, and app-specific globals.

## Research infrastructure

- **DS-060 (Phase 1):** LLVM analysis output is machine-readable and records function identity, application/module ownership, normalized IR hash, machine-code hash or placeholder stage, estimated code size, callers/callees, referenced globals, effects, external calls, allocation behavior, and reachability.
- **DS-061 (Phase 1):** Whole-workload compilation combines application, runtime, and library bitcode while retaining origin/provenance metadata.
- **DS-062 (Phase 1):** An `AppContext` isolation model exists for FD namespace, environment, cwd, allocator state, credentials, logical globals, and signal/event state.
- **DS-063 (Phase 1):** Fleet tooling can generate 100–1000 controlled workload variants.
- **DS-064 (Phase 1):** Fleet measurement distinguishes summed logical image size from unique physical bytes after canonicalization.
- **DS-065 (Phase 1):** A content-addressed manifest represents shared/private code chunks, immutable data, and per-instance data.
- **DS-066 (Phase 1):** Similarity tooling measures at LLVM-function, machine-code-function, ELF-section, 4 KiB-page, content-defined-chunk, and whole-artifact levels.

## Measurement and reproducibility

- **DS-070 (Phase 1):** A repeatable harness records artifact, text, rodata, writable-data, function/unique-function, byte-identical-function, identical-page, unique-fleet-byte, minimum-RAM, RSS, shared/private-page, boot-time, CPU-time, and compile-time metrics; unsupported runtime metrics are reported explicitly rather than fabricated.
- **DS-071 (Later):** VM exits, TLB/cache behavior, NUMA effects, shared-engine latency, and batching efficiency are measured on the later native-Linux host.
- **DS-072 (Phase 1):** Builds use deterministic linking/order where practical, normalized build paths, controlled flags, and recorded compiler version/optimization pipeline.
- **DS-073 (Phase 1):** A repeated clean build produces byte-identical checked artifacts, or any remaining nondeterminism is captured as a failed checklist item.
- **DS-074 (Later):** A native Linux KVM benchmark host with adequate cores, RAM, NVMe, virtualization/IOMMU, root/KVM, perf, and NUMA visibility is provisioned before hardware-valid benchmark claims.

## Verification result format

The automated verifier writes a result for every indexed item it can test. Any
unachieved Phase 1 or applicable Conditional item must be reported by its `DS-nnn`
index. Later and inapplicable Conditional items are reported as `DEFERRED` or
`NOT-APPLICABLE`, not failures.

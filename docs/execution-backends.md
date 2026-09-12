# Execution backends and experiment evidence

PFAAS separates artifact creation and semantic validation from hardware-valid
measurement. An experiment declares capabilities; it does not name a CI provider.

- Local WSL builds, analyzes, canonicalizes, bundles, and validates with native
  processes and QEMU TCG.
- Hosted CI may validate the Linux KVM API and functional KVM guest execution.
- A controlled native-Linux host is required for physical RAM, density, PMU,
  NUMA, cache/TLB, and contention claims.

`tools/experiment-runner/experiment_runner.py probe` is the acceptance boundary.
The existence of `/dev/kvm` is insufficient: the probe opens it, executes
`KVM_GET_API_VERSION`, launches the freestanding PFAAS guest with QEMU/KVM, and
requires the expected serial marker.

GitHub Actions and CircleCI are transport adapters around the same probe. Provider
documentation is not experimental evidence; only generated capability JSON is.

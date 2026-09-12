# PFAAS Systems-Research Laboratory

This repository defines and verifies the first-phase environment described in
[`docs/setup-checklist.md`](docs/setup-checklist.md). The authoritative checkout
is installed into the WSL Linux filesystem by `scripts/install-from-windows.ps1`.

## Bootstrap from Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-from-windows.ps1
```

## Verify inside WSL

```bash
cd ~/pfaas
./scripts/verify-desired-state.sh
```

Generated verification evidence is written beneath `verification/`.

## Execution backends

Local WSL owns builds and QEMU-TCG semantic tests. Hosted CI may provide genuine
KVM functional validation through the provider-independent capability probe.
Physical-performance claims remain reserved for a controlled native-Linux host.
See [`docs/execution-backends.md`](docs/execution-backends.md).

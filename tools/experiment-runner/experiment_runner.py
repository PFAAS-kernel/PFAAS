#!/usr/bin/env python3
"""Provider-independent host capability probe for PFAAS experiments."""
import argparse
import datetime as dt
import fcntl
import json
import os
import platform
import shutil
import subprocess
import tempfile
from pathlib import Path

KVM_GET_API_VERSION = 0xAE00

def read_int(path, default=0):
    try: return int(Path(path).read_text().strip())
    except (OSError, ValueError): return default

def memory_bytes():
    try:
        for line in Path('/proc/meminfo').read_text().splitlines():
            if line.startswith('MemTotal:'): return int(line.split()[1]) * 1024
    except OSError: pass
    return 0

def kvm_api(errors):
    try:
        fd = os.open('/dev/kvm', os.O_RDWR | os.O_CLOEXEC)
        try:
            version = fcntl.ioctl(fd, KVM_GET_API_VERSION, 0)
            return version == 12, version
        finally: os.close(fd)
    except OSError as exc:
        errors.append(f'KVM ioctl: {exc}')
        return False, None

def run_guest(image, errors):
    qemu = shutil.which('qemu-system-x86_64')
    if not qemu or not image: return False
    image = Path(image).resolve()
    if not image.is_file():
        errors.append(f'Guest image is absent: {image}')
        return False
    with tempfile.TemporaryDirectory(prefix='pfaas-kvm-') as temporary:
        serial = Path(temporary) / 'serial.log'
        command = [qemu, '-accel', 'kvm', '-display', 'none', '-serial', f'file:{serial}',
                   '-no-reboot', '-no-shutdown', '-device', 'isa-debug-exit,iobase=0xf4,iosize=0x04',
                   '-drive', f'file={image},format=raw,if=floppy']
        try:
            completed = subprocess.run(command, timeout=15, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        except subprocess.TimeoutExpired:
            errors.append('KVM guest timed out')
            return False
        output = serial.read_text(errors='replace') if serial.exists() else ''
        if 'P' not in output:
            errors.append(f'KVM guest produced no expected serial marker (rc={completed.returncode}): {completed.stderr.strip()}')
            return False
        return True

def probe(args):
    errors = []
    device = Path('/dev/kvm')
    api, api_version = kvm_api(errors) if device.exists() else (False, None)
    qemu = shutil.which('qemu-system-x86_64')
    guest_ok = run_guest(args.guest_image, errors) if api else False
    numa_root = Path('/sys/devices/system/node')
    numa_nodes = len(list(numa_root.glob('node[0-9]*'))) if numa_root.exists() else 0
    iommu_root = Path('/sys/kernel/iommu_groups')
    result = {
        'schema_version': 1,
        'host': {'architecture': platform.machine(), 'os': platform.platform(), 'cpu_count': os.cpu_count() or 0, 'memory_bytes': memory_bytes()},
        'capabilities': {
            'qemu_tcg': bool(qemu), 'kvm_device': device.exists(),
            'kvm_readable': os.access(device, os.R_OK), 'kvm_writable': os.access(device, os.W_OK),
            'kvm_api': api, 'kvm_api_version': api_version, 'kvm_guest_execution': guest_ok,
            'perf': bool(shutil.which('perf')), 'perf_event_paranoid': read_int('/proc/sys/kernel/perf_event_paranoid', -1),
            'numa_nodes': numa_nodes, 'huge_pages': read_int('/proc/sys/vm/nr_hugepages'),
            'iommu': iommu_root.exists() and any(iommu_root.iterdir())
        },
        'probe': {'provider': args.provider, 'timestamp_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
                  'guest_image': str(Path(args.guest_image).resolve()) if args.guest_image else None, 'errors': errors}
    }
    payload = json.dumps(result, indent=2, sort_keys=True) + '\n'
    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(payload)
    print(payload, end='')
    return 2 if args.require_kvm and not (api and guest_ok) else 0

def main():
    parser = argparse.ArgumentParser(); sub = parser.add_subparsers(required=True)
    command = sub.add_parser('probe')
    command.add_argument('--provider', default=os.environ.get('PFAAS_RUNNER_PROVIDER', 'local'))
    command.add_argument('--guest-image'); command.add_argument('--output'); command.add_argument('--require-kvm', action='store_true')
    command.set_defaults(function=probe); args = parser.parse_args(); raise SystemExit(args.function(args))

if __name__ == '__main__': main()

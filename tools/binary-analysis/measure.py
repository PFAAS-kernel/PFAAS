#!/usr/bin/env python3
import argparse, hashlib, json, subprocess, time
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('artifact', type=Path)
p.add_argument('--output', type=Path, default=Path('verification/measurements.json'))
a = p.parse_args()

def output(*cmd):
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)

size_fields = output('llvm-size', '-A', str(a.artifact))
sections = {}
for line in size_fields.splitlines():
    cols = line.split()
    if len(cols) >= 2 and cols[1].isdigit(): sections[cols[0]] = int(cols[1])
symbols = [line for line in output('llvm-nm', '--defined-only', str(a.artifact)).splitlines() if line.strip()]
t0 = time.perf_counter(); digest = hashlib.sha256(a.artifact.read_bytes()).hexdigest(); hash_seconds = time.perf_counter() - t0
result = {
  'artifact': str(a.artifact), 'artifact_bytes': a.artifact.stat().st_size,
  'text_bytes': sections.get('.text', 0), 'rodata_bytes': sections.get('.rodata', 0),
  'writable_data_bytes': sum(sections.get(k, 0) for k in ('.data', '.bss')),
  'defined_symbol_count': len(symbols), 'sha256': digest, 'cpu_time_seconds_for_hash': hash_seconds,
  'compile_time_seconds': None, 'minimum_bootable_ram_bytes': None, 'steady_state_rss_bytes': None,
  'private_pages': None, 'shared_pages': None, 'boot_time_seconds': None,
  'unsupported_runtime_metrics_reason': 'Require workload-specific long-running VM protocol; never inferred from host process data.'
}
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')

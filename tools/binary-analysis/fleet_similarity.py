#!/usr/bin/env python3
import argparse, hashlib, json, re, subprocess
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('artifacts', nargs='+', type=Path)
p.add_argument('--page-size', type=int, default=4096)
p.add_argument('--output', type=Path, default=Path('verification/fleet-similarity.json'))
a = p.parse_args()
def sha(data): return hashlib.sha256(data).hexdigest()

def machine_functions(path):
    text = subprocess.check_output(['llvm-objdump', '-d', str(path)], text=True, errors='replace')
    found, current, body = [], None, bytearray()
    for line in text.splitlines():
        m = re.match(r'^[0-9a-fA-F]+ <([^>]+)>:', line)
        if m:
            if current and body: found.append({'artifact': str(path), 'name': current, 'sha256': sha(body)})
            current, body = m.group(1), bytearray(); continue
        if current:
            m = re.match(r'^\s*[0-9a-fA-F]+:\s+((?:[0-9a-fA-F]{2}\s+)+)', line)
            if m: body.extend(bytes.fromhex(m.group(1)))
    if current and body: found.append({'artifact': str(path), 'name': current, 'sha256': sha(body)})
    return found

def elf_sections(path, data):
    text = subprocess.check_output(['llvm-readelf', '-S', '--wide', str(path)], text=True)
    found = []
    for line in text.splitlines():
        m = re.match(r'^\s*\[\s*\d+\]\s+(\S+)\s+\S+\s+[0-9a-fA-F]+\s+([0-9a-fA-F]+)\s+([0-9a-fA-F]+)', line)
        if m:
            name, offset, size = m.group(1), int(m.group(2), 16), int(m.group(3), 16)
            if size and offset + size <= len(data): found.append({'artifact': str(path), 'name': name, 'bytes': size, 'sha256': sha(data[offset:offset+size])})
    return found

def cdc_chunks(path, data, minimum=2048, maximum=16384, mask=0xfff):
    found, start, rolling = [], 0, 0
    for i, value in enumerate(data):
        rolling = ((rolling << 1) + value + 1) & 0xffffffff; length = i + 1 - start
        if length >= minimum and ((rolling & mask) == 0 or length >= maximum):
            chunk = data[start:i+1]; found.append({'artifact': str(path), 'offset': start, 'bytes': len(chunk), 'sha256': sha(chunk)}); start, rolling = i + 1, 0
    if start < len(data):
        chunk = data[start:]; found.append({'artifact': str(path), 'offset': start, 'bytes': len(chunk), 'sha256': sha(chunk)})
    return found

names = ('llvm-function', 'machine-code-function', 'elf-section', 'fixed-4KiB-page', 'content-defined-chunk', 'whole-artifact')
levels = {name: [] for name in names}
inventory = Path('verification/function-inventory.jsonl')
if inventory.exists():
    for line in inventory.read_text().splitlines():
        if line.strip():
            row = json.loads(line); levels['llvm-function'].append({'module': row['module'], 'name': row['function'], 'sha256': row['normalized_ir_hash']})
logical, artifacts = 0, []
for path in a.artifacts:
    data = path.read_bytes(); logical += len(data)
    pages = [{'artifact': str(path), 'offset': i, 'bytes': len(data[i:i+a.page_size]), 'sha256': sha(data[i:i+a.page_size])} for i in range(0, len(data), a.page_size)]
    levels['fixed-4KiB-page'].extend(pages); levels['machine-code-function'].extend(machine_functions(path))
    levels['elf-section'].extend(elf_sections(path, data)); levels['content-defined-chunk'].extend(cdc_chunks(path, data))
    whole = {'artifact': str(path), 'bytes': len(data), 'sha256': sha(data)}; levels['whole-artifact'].append(whole); artifacts.append(whole)
summary = {}
for name, rows in levels.items():
    hashes = [r['sha256'] for r in rows]; summary[name] = {'hash_count': len(hashes), 'unique_hash_count': len(set(hashes)), 'records': rows}
page_hashes = [r['sha256'] for r in levels['fixed-4KiB-page']]
result = {'logical_bytes': logical, 'unique_page_bytes_upper_bound': len(set(page_hashes))*a.page_size,
          'page_count': len(page_hashes), 'unique_page_count': len(set(page_hashes)), 'artifacts': artifacts, 'levels': summary}
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')

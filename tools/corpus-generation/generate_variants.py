#!/usr/bin/env python3
import argparse, hashlib, json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--count', type=int, default=100)
p.add_argument('--output', type=Path, default=Path('fleet/variants/generated'))
a = p.parse_args()
if not 100 <= a.count <= 1000:
    p.error('--count must be between 100 and 1000')
a.output.mkdir(parents=True, exist_ok=True)
for i in range(a.count):
    config = {'id': i, 'constant': i % 17, 'feature_set': i % 8, 'mixture': i % 4, 'opt_level': ('Os', 'O2')[i % 2]}
    raw = json.dumps(config, sort_keys=True, separators=(',', ':')).encode()
    config['configuration_hash'] = hashlib.sha256(raw).hexdigest()
    (a.output / f'{i:04d}.json').write_text(json.dumps(config, sort_keys=True) + '\n')

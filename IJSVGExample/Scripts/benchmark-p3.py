#!/usr/bin/env python3
"""Run sequential Release P3/CSS benchmarks and verify profiles, pixels and redraws."""
import argparse
import csv
import json
import math
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('output', type=Path)
parser.add_argument('--repeats', type=int, default=15)
args = parser.parse_args()
if args.repeats < 1:
    parser.error('--repeats must be positive')
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
scripts = Path(__file__).resolve().parent
subprocess.run([sys.executable, str(scripts / 'generate-p3-benchmarks.py'), str(output)], check=True)
env = dict(os.environ)
build = Path(env.get('IJSVG_BENCHMARK_BUILD_PATH', str(output / 'build'))).resolve()
env['IJSVG_BENCHMARK_BUILD_PATH'] = str(build)
records = []
hashes = {}
scenarios = [(profile, mode, filtered, profile) for filtered in (False, True)
             for profile in ('srgb', 'p3') for mode in ('direct', 'css', 'calc')]
scenarios += [(source, 'css', filtered, destination) for filtered in (False, True)
              for source, destination in (('p3', 'srgb'), ('srgb', 'p3'))]
for source, mode, filtered, destination in scenarios:
    fixture = f'{source}-{mode}' + ('-filters' if filtered else '')
    name = f'{fixture}-to-{destination}'
    command = ['sh', str(scripts / 'benchmark-rendering.sh')] if not records else [str(build / 'benchmark-rendering')]
    env['IJSVG_BENCHMARK_PNG'] = str(output / f'{name}.png')
    with (output / f'{name}.csv').open('w') as stdout, (output / f'{name}.log').open('w') as stderr:
        subprocess.run(command + [str(args.repeats), str(output / f'{fixture}.svg'), destination],
                       env=env, stdout=stdout, stderr=stderr, check=True)
    with (output / f'{name}.csv').open() as stream:
        rows = list(csv.DictReader(stream))
    if len(rows) != args.repeats or len({r['pixel_hash'] for r in rows}) != 1:
        raise RuntimeError(f'{name}: sample count or pixels changed')
    key = source, destination, filtered
    image_hash = rows[0]['pixel_hash']
    if key in hashes and hashes[key] != image_hash:
        raise RuntimeError(f'{name}: direct/CSS/calculated pixels differ')
    hashes[key] = image_hash
    probe_match = re.search(r'probe_extended_srgb=([^\n]+)', (output / f'{name}.log').read_text())
    if not probe_match:
        raise RuntimeError(f'{name}: missing pixel probe')
    probe = [float(value) for value in probe_match[1].split(',')]
    if source == destination == 'p3':
        # Independent D65 primary conversion of the solid (1, .3, 0) P3 stripe.
        green = ((.3 + .055) / 1.055) ** 2.4
        linear = [1.224940176 - .224940176 * green,
                  -.042056955 + 1.042056955 * green,
                  -.019637555 - .078636046 * green]
        expected = [math.copysign(12.92 * abs(v) if abs(v) <= .0031308
                    else 1.055 * abs(v) ** (1 / 2.4) - .055, v) for v in linear] + [1]
        if any(abs(actual - reference) > .006 for actual, reference in zip(probe, expected)):
            raise RuntimeError(f'{name}: P3 probe {probe} differs from independent reference {expected}')
    timings = {}
    for metric in ('xml_ms', 'nodes_ms', 'parse_ms', 'first_render_ms', 'redraw_ms'):
        values = sorted(float(row[metric]) for row in rows)
        timings[metric] = {'median': statistics.median(values), 'min': values[0],
                           'p90': values[math.ceil(.9 * len(values)) - 1], 'max': values[-1]}
    records.append({'name': name, 'samples': len(rows), 'timings': timings,
                    'pixel_hash': image_hash, 'probe_extended_srgb': probe})
    print(name, ' '.join(f'{key}={timings[key]["median"]:.3f}'
          for key in ('parse_ms', 'first_render_ms', 'redraw_ms')), flush=True)
metadata = {'platform': platform.platform(), 'cpu': subprocess.check_output(
    ['sysctl', '-n', 'machdep.cpu.brand_string'], text=True).strip(),
    'size': [1024, 768], 'warmups': 5, 'redraws_per_sample': 5,
    'configuration': 'Release', 'records': records}
(output / 'results.json').write_text(json.dumps(metadata, indent=2) + '\n')
print(f'Raw samples, SVGs, profile tagged PNGs and results: {output}', flush=True)

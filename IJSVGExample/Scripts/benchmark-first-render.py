#
#  benchmark-first-render.py
#  IJSVGExample
#
#  Created by Curtis Hard on 13/10/2026.
#  Copyright © 2026 Curtis Hard. All rights reserved.
#

"""Compare saved IJSVG frameworks using fresh SVG instances and Metal rendering."""
import argparse
import csv
import hashlib
import json
import platform
import shutil
import statistics
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, required=True, help='Directory containing IJSVG.framework')
    parser.add_argument('--candidate', type=Path, required=True, help='Directory containing IJSVG.framework')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--size', type=int, default=480)
    parser.add_argument('--repetitions', type=int, default=3)
    parser.add_argument('--memory', action='store_true', help='Measure each SVG in isolated processes after timing')
    parser.add_argument('svgs', nargs='+', type=Path)
    args = parser.parse_args()
    if not 1 <= args.size <= 2048 or args.repetitions < 1:
        parser.error('Size must be 1–2048 and repetitions must be positive')
    names = [path.stem for path in args.svgs]
    if len(names) != len(set(names)):
        parser.error('SVG filenames must have distinct stems')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    fixtures = output / 'fixtures.json'
    fixtures.write_text(json.dumps([{'id': path.stem, 'svg': path.read_text()}
                                    for path in args.svgs]))
    source = Path(__file__).with_name('FirstRenderBenchmark.m')
    metadata = {
        'recordedAt': datetime.now(timezone.utc).isoformat(),
        'platform': platform.platform(),
        'size': args.size, 'backingScale': 1,
        'method': 'Release frameworks supplied by caller. Metal required. Alternating process order. '
                  'Each process discards three warmups and takes medians of 15 fresh documents. '
                  'XML is in memory; bitmap allocation and clearing are outside timers. '
                  'Total is parse plus first draw. Redraw uses each instance after its first draw. '
                  'Initial per-process timings are recorded separately, not guaranteed cold startup. '
                  'Summary reports medians of process medians.',
        'fixtures': {str(path.resolve()): sha256(path) for path in args.svgs},
        'harnessSHA256': sha256(source), 'frameworks': {}, 'runs': [],
    }
    for label, products in [('baseline', args.baseline), ('candidate', args.candidate)]:
        directory = output / label
        directory.mkdir()
        framework = directory / 'IJSVG.framework'
        shutil.copytree(products / 'IJSVG.framework', framework, symlinks=True)
        metadata['frameworks'][label] = sha256(framework / 'IJSVG')
        subprocess.run(['xcrun', 'clang', '-O2', '-fobjc-arc', str(source),
                        '-F', str(directory), '-framework', 'IJSVG', '-framework', 'AppKit',
                        '-framework', 'QuartzCore', '-framework', 'Metal',
                        '-Wl,-rpath,@executable_path', '-o', str(directory / 'FirstRender')], check=True)
    for repetition in range(args.repetitions):
        order = ['baseline', 'candidate'] if repetition % 2 == 0 else ['candidate', 'baseline']
        for label in order:
            directory = output / label
            run = directory / str(repetition)
            run.mkdir()
            with (run / 'timings.csv').open('w') as stream, (run / 'console.log').open('w') as log:
                subprocess.run([str(directory / 'FirstRender'), str(fixtures), str(args.size), str(run)],
                               stdout=stream, stderr=log, check=True)
            rows = list(csv.DictReader((run / 'timings.csv').open()))
            if [row['case'] for row in rows] != names:
                raise RuntimeError('Incomplete benchmark output')
            metadata['runs'].append({'variant': label, 'repetition': repetition, 'rows': rows})
            (output / 'results.json').write_text(json.dumps(metadata, indent=2) + '\n')
            print(label, repetition, [(row['case'], row['total_ms']) for row in rows], flush=True)
    if args.memory:
        memory_source = source.with_name('FirstRenderMemory.m')
        metadata['memoryHarnessSHA256'] = sha256(memory_source)
        metadata['memoryMethod'] = ('Separate fresh processes after all timing runs. One small SVG warms common runtime state. '
                                    'Source and bitmap allocated before baseline. Physical footprint sampled after parse '
                                    'and first render with temporary autoreleases drained and the SVG retained. '
                                    'Peak RSS covers the whole process; deltas include allocator and rendering caches.')
        metadata['memoryRuns'] = []
        for label in ['baseline', 'candidate']:
            directory = output / label
            subprocess.run(['xcrun', 'clang', '-O2', '-fobjc-arc', str(memory_source),
                            '-F', str(directory), '-framework', 'IJSVG', '-framework', 'AppKit',
                            '-framework', 'Metal', '-Wl,-rpath,@executable_path',
                            '-o', str(directory / 'FirstRenderMemory')], check=True)
        for repetition in range(args.repetitions):
            order = ['baseline', 'candidate'] if repetition % 2 == 0 else ['candidate', 'baseline']
            for path in args.svgs:
                for label in order:
                    directory = output / label
                    result = subprocess.run([str(directory / 'FirstRenderMemory'), str(path), str(args.size)],
                                            capture_output=True, text=True, check=True)
                    measurements = json.loads(result.stdout)
                    if min(measurements.values()) <= 0:
                        raise RuntimeError('Memory measurement unavailable')
                    metadata['memoryRuns'].append({'case': path.stem, 'variant': label,
                                                   'repetition': repetition, **measurements})
            (output / 'results.json').write_text(json.dumps(metadata, indent=2) + '\n')
            print('Memory repetition', repetition + 1, 'complete', flush=True)
    summary = {}
    for name in names:
        summary[name] = {}
        references = {suffix: (output / 'baseline/0' / (name + suffix)).read_bytes()
                      for suffix in ['.first.rgba', '.rgba']}
        for label in ['baseline', 'candidate']:
            rows = [row for run in metadata['runs'] if run['variant'] == label
                    for row in run['rows'] if row['case'] == name]
            summary[name][label] = {stage: statistics.median(float(row[stage]) for row in rows)
                                   for stage in ['parse_ms', 'first_draw_ms', 'total_ms', 'warm_draw_ms']}
            if args.memory:
                samples = [row for row in metadata['memoryRuns'] if row['case'] == name and row['variant'] == label]
                summary[name][label]['parse_footprint_delta_bytes'] = statistics.median(row['parsed_bytes'] - row['before_bytes'] for row in samples)
                summary[name][label]['render_footprint_delta_bytes'] = statistics.median(row['rendered_bytes'] - row['before_bytes'] for row in samples)
                summary[name][label]['peak_rss_bytes'] = statistics.median(row['peak_rss_bytes'] for row in samples)
            for repetition in range(args.repetitions):
                for suffix, reference in references.items():
                    pixels = (output / label / str(repetition) / (name + suffix)).read_bytes()
                    if pixels != reference:
                        raise RuntimeError(f'Pixel mismatch: {name}{suffix}, {label}, run {repetition}')
        summary[name]['pixelsIdentical'] = True
        summary[name]['firstDrawPixelsIdentical'] = True
    metadata['summary'] = summary
    (output / 'results.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()

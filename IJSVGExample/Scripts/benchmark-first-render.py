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
    summary = {}
    for name in names:
        summary[name] = {}
        reference = (output / 'baseline/0' / (name + '.rgba')).read_bytes()
        for label in ['baseline', 'candidate']:
            rows = [row for run in metadata['runs'] if run['variant'] == label
                    for row in run['rows'] if row['case'] == name]
            summary[name][label] = {stage: statistics.median(float(row[stage]) for row in rows)
                                   for stage in ['parse_ms', 'first_draw_ms', 'total_ms', 'warm_draw_ms']}
            for repetition in range(args.repetitions):
                pixels = (output / label / str(repetition) / (name + '.rgba')).read_bytes()
                if pixels != reference:
                    raise RuntimeError(f'Pixel mismatch: {name}, {label}, run {repetition}')
        summary[name]['pixelsIdentical'] = True
    metadata['summary'] = summary
    (output / 'results.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()

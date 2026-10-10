"""Measure SVG loading, rendering and export using an existing Xcode build."""
import argparse
import csv
import hashlib
import json
import platform
import statistics
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('products', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--configuration', required=True)
    parser.add_argument('--sizes', type=int, nargs='+', default=[64, 256, 1024])
    parser.add_argument('--fixture-filter')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    products = args.products.resolve()
    corpus = json.loads((root / 'IJSVGExampleTests/MDN/corpus.json').read_text())
    fixtures = [{'id': case['id'], 'svg': case['svg']}
                for case in corpus['cases'] if 'skip' not in case]
    fixtures.extend({'id': 'local_' + path.stem, 'svg': path.read_text()}
                    for path in sorted((root / 'IJSVGExample').glob('*.svg')))
    if args.fixture_filter:
        fixtures = [case for case in fixtures if args.fixture_filter in case['id']]
    if not fixtures:
        parser.error('No matching fixtures')
    fixture_path = output / 'fixtures.json'
    fixture_path.write_text(json.dumps(fixtures))
    executable = output / 'CorpusBenchmark'
    subprocess.run(['xcrun', 'clang', '-O2', '-fobjc-arc', str(root / 'Scripts/CorpusBenchmark.m'),
                    '-F', str(products), '-framework', 'IJSVG', '-framework', 'AppKit',
                    '-framework', 'QuartzCore', '-Wl,-rpath,' + str(products),
                    '-o', str(executable)], check=True)
    metadata = {
        'recordedAt': datetime.now(timezone.utc).isoformat(timespec='seconds'),
        'configuration': args.configuration,
        'platform': platform.platform(),
        'revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
        'frameworkSHA256': hashlib.sha256((products / 'IJSVG.framework/IJSVG').read_bytes()).hexdigest(),
        'fixtureCount': len(fixtures),
        'fixtureSHA256': hashlib.sha256(fixture_path.read_bytes()).hexdigest(),
        'method': 'Median of five rounds after warmup. Parsing uses in memory XML. First draw uses a fresh SVG instance with process caches warm. Redraw uses a retained instance. Invalidation precedes its draw timer. PNG encoding starts from rendered pixels. Image and PDF export reuse the drawn instance. Bitmap allocation and clearing are outside draw timers. One sample per stage per round. Timings are observations without pass thresholds.',
        'sizes': {},
    }
    for size in args.sizes:
        csv_path = output / f'{size}.csv'
        with csv_path.open('w') as stream, (output / f'{size}.log').open('w') as errors:
            subprocess.run([str(executable), str(fixture_path), str(size)],
                           stdout=stream, stderr=errors, check=True)
        with csv_path.open() as stream:
            rows = list(csv.DictReader(stream))
        if len(rows) != len(fixtures):
            raise RuntimeError('Incomplete benchmark output')
        stages = {}
        for stage in rows[0]:
            if not stage.endswith('_ms'):
                continue
            values = sorted(float(row[stage]) for row in rows)
            stages[stage] = {
                'median': statistics.median(values),
                'p95': values[int((len(values) - 1) * .95)],
                'sum': sum(values),
                'slowest': [{'id': row['case'], 'ms': float(row[stage])}
                            for row in sorted(rows, key=lambda row: float(row[stage]), reverse=True)[:10]],
            }
        metadata['sizes'][str(size)] = stages
        (output / 'summary.json').write_text(json.dumps(metadata, indent=2) + '\n')
        print(f'{size}: {len(rows)} fixtures completed', flush=True)


if __name__ == '__main__':
    main()

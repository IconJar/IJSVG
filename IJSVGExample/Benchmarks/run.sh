#!/bin/sh
# Run from IJSVGExample after building in Xcode. Pass its products directory.
set -eu
products=${1:?Usage: sh Benchmarks/run.sh /path/to/Build/Products/Debug}
output=${2:-/tmp/ijsvg-filter-results}
mkdir -p "$output"
for source in FilterPipeline OpacityChain; do
    clang -O2 -fobjc-arc "Benchmarks/$source.m" -framework Foundation -framework CoreImage -framework CoreGraphics -framework Metal -framework QuartzCore -o "$output/$source"
    "$output/$source" > "$output/$source.csv"
done
clang -O2 -fobjc-arc Benchmarks/CarBatch.m -F "$products" -framework IJSVG -framework AppKit -framework CoreGraphics -framework QuartzCore -Wl,-rpath,"$products" -o "$output/CarBatch"
"$output/CarBatch" IJSVGExample/car.svg "$output" serial > "$output/serial.txt" 2> "$output/serial-sizes.txt"
"$output/CarBatch" IJSVGExample/car.svg "$output" batched > "$output/batched.txt" 2> "$output/batched-sizes.txt"
python3 - "$output" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
for width in (512, 900, 1800):
    a = (root / f'serial-{width}.rgba').read_bytes()
    b = (root / f'batched-{width}.rgba').read_bytes()
    assert len(a) == len(b)
    differences = [abs(x-y) for x,y in zip(a,b)]
    print(width, 'max:', max(differences), 'mean:', sum(differences)/len(a))
    assert max(differences) <= 2
PY

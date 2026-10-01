#!/bin/sh
# Run from IJSVGExample after building in Xcode.
set -eu
products=${1:?Usage: sh Benchmarks/run-chains.sh /path/to/Build/Products/Debug}
output=${2:-/tmp/ijsvg-chain-results}
mkdir -p "$output"
for source in FilterChains TransparentBlend; do
    clang -O2 -fobjc-arc "Benchmarks/$source.m" -F "$products" -framework IJSVG -framework AppKit -framework Metal -framework CoreGraphics -framework QuartzCore -Wl,-rpath,"$products" -o "$output/$source"
done
"$output/TransparentBlend" Benchmarks/color-chain-fixtures.json small > "$output/color-chain-results.csv"
"$output/TransparentBlend" Benchmarks/inner-shadow-fixtures.json > "$output/inner-shadow-results.csv"
python3 - "$output/health-worker.json" <<'PY'
import json, pathlib, sys
source = pathlib.Path('Benchmarks/health-worker-color-light.svg').read_text()
pathlib.Path(sys.argv[1]).write_text(json.dumps([{'name':'health-worker','tier':'complex','document':source}]))
PY
"$output/TransparentBlend" "$output/health-worker.json" > "$output/health-worker-results.csv"
# Optional inclusive per-filter profiling (includes cold renders and nested work):
# IJSVG_PROFILE_CHAINS=1 "$output/FilterChains" "$output/health-worker.json" "$output/reference" record

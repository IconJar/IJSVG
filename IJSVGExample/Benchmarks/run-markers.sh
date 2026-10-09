#!/bin/sh
#
#  Marker benchmark runner
#  IJSVGExample
#
#  Created by Curtis Hard on 09/10/2026.
#  Copyright © 2026 Curtis Hard. All rights reserved.
#

set -eu
products=${1:?Usage: sh Benchmarks/run-markers.sh /path/to/Build/Products/Debug [output-directory]}
output=${2:-/tmp/ijsvg-marker-benchmark}
mkdir -p "$output"
xcrun clang -O2 -fobjc-arc Benchmarks/MarkerBenchmark.m \
    -F "$products" -framework IJSVG -framework AppKit -framework QuartzCore \
    -Wl,-rpath,"$products" -o "$output/MarkerBenchmark"
"$output/MarkerBenchmark" IJSVGExample/marker3.svg > "$output/results.csv"
cat "$output/results.csv"

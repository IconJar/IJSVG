#!/bin/sh
# Build the framework with Xcode first, then supply its products directory.
set -eu
products=${1:?Usage: sh Benchmarks/run-quartz.sh /path/to/Build/Products/Debug [output-directory]}
output=${2:-/tmp/ijsvg-quartz-benchmark}
mkdir -p "$output"
clang -O2 -fobjc-arc Benchmarks/QuartzRenderer.m \
    -I ../Framework/IJSVG/IJSVG/Source/Rendering \
    -F "$products" -framework IJSVG -framework AppKit -framework QuartzCore \
    -Wl,-rpath,"$products" -o "$output/QuartzRenderer"
"$output/QuartzRenderer" "$output" \
    IJSVGExample/heart.svg IJSVGExample/gradients.svg \
    IJSVGExample/pattern-alignment.svg IJSVGExample/clipped.svg \
    IJSVGExample/mask.svg IJSVGExample/image.svg IJSVGExample/car.svg \
    IJSVGExample/5x5checkerboard.svg IJSVGExample/Chessboard480DiagonalStripe.svg \
    IJSVGExample/dashed.svg IJSVGExample/dropshadow-clipping-masks.svg \
    > "$output/results.csv"
cat "$output/results.csv"

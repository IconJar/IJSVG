#!/bin/sh
# Build the selected revision with Xcode first. Run from IJSVGExample.
set -eu
products=${1:?Usage: sh Benchmarks/run-sticker.sh products input.svg output-directory}
asset=${2:?Supply a representative sticker SVG}
output=${3:?Supply a separate directory for each revision}
mkdir -p "$output"
clang -O2 -fobjc-arc -dynamiclib -DIJSVG_BITMAP_PROBE Benchmarks/StickerRendering.m \
    -F "$products" -framework AppKit -framework CoreGraphics \
    -install_name @rpath/StickerBitmapProbe.dylib -o "$output/StickerBitmapProbe.dylib"
clang -O2 -fobjc-arc Benchmarks/StickerRendering.m \
    -F "$products" -framework IJSVG -framework AppKit -framework CoreImage \
    -framework QuartzCore -framework Metal "$output/StickerBitmapProbe.dylib" \
    -Wl,-rpath,"$products" -Wl,-rpath,@executable_path -o "$output/StickerRendering"
for size in 256 512 1024; do
    "$output/StickerRendering" "$asset" "$size" "$output/$size.rgba" \
        > "$output/$size-timing.csv" 2> "$output/$size-allocations.csv"
done

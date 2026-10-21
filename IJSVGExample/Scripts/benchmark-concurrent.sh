#!/bin/sh
# Build a Release package and benchmark independent concurrent loads/renders.
# Arguments are repeats, workers, side and the SVG file path.
set -eu
script_directory="$(cd "$(dirname "$0")" && pwd)"
repository_root="${IJSVG_BENCHMARK_PACKAGE_PATH:-$(cd "$script_directory/../.." && pwd)}"
scratch_directory="${IJSVG_BENCHMARK_BUILD_PATH:-$(mktemp -d "${TMPDIR:-/tmp}/ijsvg-concurrent.XXXXXX")}"
if [ -z "${IJSVG_BENCHMARK_BUILD_PATH:-}" ]; then
    trap 'rm -rf "$scratch_directory"' EXIT
fi
xcrun swift build --package-path "$repository_root" --scratch-path "$scratch_directory" -c release >&2
products="$(xcrun swift build --package-path "$repository_root" --scratch-path "$scratch_directory" -c release --show-bin-path)"
framework="$repository_root/Framework/IJSVG/IJSVG"
xcrun clang -O3 -fobjc-arc -fmodules \
    -I "$framework/include" -I "$framework/PrivateHeaders" \
    -I "$framework/Source/Stylesheets" -I "$framework/Source/Nodes" \
    -I "$framework/Source/Parsing" -I "$framework/Source/Rendering" \
    "$script_directory/benchmark-concurrent.m" \
    -Wl,-force_load,"$products/libIJSVG.a" \
    -framework Foundation -framework AppKit -framework Quartz -framework ImageIO \
    -framework CoreImage -framework Metal -framework Accelerate \
    -framework UniformTypeIdentifiers -lxml2 \
    -o "$scratch_directory/benchmark-concurrent"
ditto "$products/IJSVG_IJSVG.bundle" "$scratch_directory/IJSVG_IJSVG.bundle"
"$scratch_directory/benchmark-concurrent" "$@"

#!/bin/sh
# Run a Release package build and benchmark parser keywords and text tokenization.
set -eu
repository_root="$(cd "$(dirname "$0")/../.." && pwd)"
scratch_directory="${IJSVG_BENCHMARK_BUILD_PATH:-$(mktemp -d "${TMPDIR:-/tmp}/ijsvg-parser-keywords.XXXXXX")}"
if [ -z "${IJSVG_BENCHMARK_BUILD_PATH:-}" ]; then
    trap 'rm -rf "$scratch_directory"' EXIT
fi
xcrun swift build --package-path "$repository_root" --scratch-path "$scratch_directory" -c release
products="$(xcrun swift build --package-path "$repository_root" --scratch-path "$scratch_directory" -c release --show-bin-path)"
framework="$repository_root/Framework/IJSVG/IJSVG"
xcrun clang -O3 -fobjc-arc -fmodules \
    -I "$framework/include" -I "$framework/PrivateHeaders" \
    -I "$framework/Source/Stylesheets" -I "$framework/Source/Nodes" \
    -I "$framework/Source/Parsing" -I "$framework/Source/Rendering" \
    "$repository_root/IJSVGExample/Scripts/benchmark-parser-keywords.m" \
    -Wl,-force_load,"$products/libIJSVG.a" \
    -framework Foundation -framework AppKit -framework Quartz \
    -framework CoreImage -framework Metal -framework Accelerate \
    -framework UniformTypeIdentifiers -lxml2 \
    -o "$scratch_directory/benchmark-parser-keywords"
"$scratch_directory/benchmark-parser-keywords" "$@"

# Display P3 and CSS benchmark

From `IJSVGExample`, run:

```sh
python3 Scripts/benchmark-p3.py /tmp/ijsvg-p3-results --repeats 15
```

This builds the Release Swift package and compiles the benchmark executable in
Objective-C. It does not run any test suite. Run with normal system access so
Core Image can use Metal. To reuse a build directory, set
`IJSVG_BENCHMARK_BUILD_PATH=/tmp/ijsvg-p3-build`.

The runner generates 1024 × 768 SVGs with 768 tiles, P3 colors outside sRGB,
a gradient, 128 CSS rules, inherited custom properties and calculated colors.
Matched direct attribute and sRGB variants serve as controls. Filter variants
add blur and offset to 24 row groups. All scenarios run sequentially, including
P3 artwork in sRGB destinations and sRGB artwork in P3 destinations.

Five warmup samples are discarded. Each measured sample parses a fresh document,
renders it once, then averages five cached redraws. The first render therefore
measures a fresh document, not a cold process or initial GPU compilation.
Raw CSV samples and JSON medians/ranges/p90s are saved beside the SVGs and PNGs.
First render excludes image disposal; redraw timings include disposal.

Outside the timed sections, the executable checks the destination CGImage
profile and identical pixels on repeated draws. The runner checks identical
pixels across direct, CSS and calculated variants and validates a solid P3
stripe against an independent primary conversion and transfer function. The
0.006 probe tolerance permits quantization in the 8 bit destination. Profile
tagged PNGs permit visual inspection; display screenshots alone cannot prove
wide gamut preservation.

For an existing SVG, use the underlying Objective-C benchmark directly:

```sh
sh Scripts/benchmark-rendering.sh 15 /path/to/artwork.svg p3
```

The destination argument is `p3` or `srgb` (default). Set
`IJSVG_BENCHMARK_PNG=/tmp/render.png` to save an image outside the measured work.
The arbitrary SVG benchmark reports a pixel probe, but the independent reference
assertion in the Python runner applies only to its generated fixtures.

Do not interpret these synthetic results as a universal speed guarantee.
Numeric colors in the sRGB and P3 controls are alike, but their physical colors
are different. Filter timings depend on destination, intermediate precision,
GPU and cache state. For revision comparisons use the same machine, generated
fixtures, rendering destination and Release configuration, and retain raw data.

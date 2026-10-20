#!/usr/bin/env python3
#
#  generate nesting benchmarks.py
#  IJSVGExample
#
#  Created by Curtis Hard on 20/10/2026.
#  Copyright © 2026 Curtis Hard. All rights reserved.
#

"""Generate equivalent flat/nested CSS SVGs with 20,000 paths and 40 filters."""

import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("output", type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)

rules = [
    f"path.c{i} {{ fill: rgb({i * 17 % 256},{i * 37 % 256},{i * 61 % 256}); }}"
    for i in range(1000)
]
groups = []
for group in range(40):
    paths = []
    for item in range(500):
        index = group * 500 + item
        x = index * 37 % 500
        y = index * 71 % 500
        paths.append(
            f'<path class="c{index % 1000}" '
            f'd="M{x} {y}c12 -8 18 12 4 16s-16 -10 -4 -16z"/>'
        )
    groups.append('<g filter="url(#blur)">' + "".join(paths) + "</g>")

template = (
    '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" '
    'viewBox="0 0 512 512"><style>{css}</style>'
    '<defs><filter id="blur" x="-10%" y="-10%" width="120%" height="120%">'
    '<feGaussianBlur stdDeviation="1.5"/>'
    '<feColorMatrix type="saturate" values=".7"/></filter></defs>'
    '<g class="scene">' + "".join(groups) + "</g></svg>"
)
for variant, css in [
    ("flat", "\n".join(".scene " + rule for rule in rules)),
    ("nested", ".scene {\n" + "\n".join(rules) + "\n}"),
]:
    (args.output / f"heavy-{variant}.svg").write_text(
        template.replace("{css}", css), encoding="utf-8"
    )

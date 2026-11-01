#!/usr/bin/env python3
"""Generate matching P3 and sRGB fixtures with direct, CSS and calculated paints."""
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('output', type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
for profile in ('p3', 'srgb'):
    colors = ['color(display-p3 1 .3 0)', 'color(display-p3 0 1 .2)',
              'color(display-p3 .6 0 1)', 'color(display-p3 1 0 .5)'] if profile == 'p3' else [
              'rgb(100% 30% 0%)', 'rgb(0% 100% 20%)',
              'rgb(60% 0% 100%)', 'rgb(100% 0% 50%)']
    calculated = [c.replace('1 .3 0', 'calc(50% + 50%) calc(10% + 20%) 0')
                  .replace('0 1 .2', '0 calc(50% + 50%) calc(10% + 10%)')
                  .replace('.6 0 1', 'calc(30% + 30%) 0 calc(50% + 50%)')
                  .replace('1 0 .5', 'calc(50% + 50%) 0 calc(25% + 25%)')
                  if profile == 'p3' else c.replace('100%', 'calc(50% + 50%)')
                  for c in colors]
    for mode in ('direct', 'css', 'calc'):
        for filtered in (False, True):
            parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="768" viewBox="0 0 1024 768">']
            if mode != 'direct':
                palette = calculated if mode == 'calc' else colors
                parts.append('<style>svg {' + ''.join(f'--c{i}:{c};' for i,c in enumerate(palette)) + '}')
                for i in range(128):
                    parts.append(f'.tiles > rect.tile.c{i}:not(.disabled) {{fill:var(--c{i%4});stroke:var(--c{(i+1)%4});stroke-width:1}}')
                parts.append('</style>')
            parts.append(f'<defs><linearGradient id="g"><stop stop-color="{colors[0]}"/><stop offset="1" stop-color="{colors[1]}"/></linearGradient><filter id="f" x="0" y="0" width="1" height="1"><feGaussianBlur stdDeviation="1"/><feOffset dx="1" dy="1"/></filter></defs>')
            parts.append(f'<rect width="1024" height="768" fill="{colors[0]}"/>')
            for row in range(24):
                parts.append('<g class="tiles"' + (' filter="url(#f)"' if filtered else '') + '>')
                for col in range(32):
                    i = row * 32 + col
                    paint = f'fill="{colors[i%4]}" stroke="{colors[(i+1)%4]}" stroke-width="1"' if mode == 'direct' else f'class="tile c{i%128}"'
                    parts.append(f'<rect x="{32+col*30}" y="{row*30+24}" width="25" height="25" rx="4" {paint}/>')
                parts.append('</g>')
            parts.append('<rect x="32" y="0" width="960" height="16" fill="url(#g)"/></svg>')
            name=f'{profile}-{mode}' + ('-filters' if filtered else '') + '.svg'
            (args.output/name).write_text('\n'.join(parts)+'\n')

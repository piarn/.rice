#!/usr/bin/env python3
"""Draws the desktop's wallpaper: a quiet star chart in Catppuccin Mocha.

A faint grid of + marks with chart-style axis labels, sparse square stars
(a few brighter, one or two in the accent), two dotted orbits with a small
body on one. Mostly empty space. Square pixels and an 11px-grid pixel font
(Departure Mono) to match the shell.

Drawn at 3840x2160 with everything on even pixels, so it stays exact at
1920x1080 (halved) and at 3840x1080 (sway's `fill` crops it). Same seed, same
image: change SEED for another sky.

    ./make-wallpaper.py [out.png]    (default: ../sway/.config/sway/wallpaper.png)

Needs python3 and rsvg-convert (librsvg); the font must be installed for the
labels (~/.rice/install.sh puts it in ~/.local/share/fonts).
"""
import os
import random
import subprocess
import sys
import tempfile

W, H = 3840, 2160
SEED = 1977          # the year the Voyagers left
GRID = 320           # grid spacing; 12 x 6.75 cells
STARS = 150

BASE = "#1e1e2e"     # base
SURFACE0 = "#313244"
SURFACE1 = "#45475a"
OVERLAY0 = "#6c7086"
OVERLAY1 = "#7f849c"
SUBTEXT0 = "#a6adc8"
MAUVE = "#cba6f7"

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUT = os.path.join(HERE, "..", "sway", ".config", "sway", "wallpaper.png")


def even(v):
    return int(v) // 2 * 2


def svg():
    rnd = random.Random(SEED)
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" shape-rendering="crispEdges">',
           f'<rect width="{W}" height="{H}" fill="{BASE}"/>']

    # grid: a small + at every crossing, nothing in between
    for gx in range(GRID, W, GRID):
        for gy in range(GRID, H, GRID):
            out.append(f'<rect x="{gx - 8}" y="{gy - 1}" width="16" height="2" fill="{SURFACE0}"/>')
            out.append(f'<rect x="{gx - 1}" y="{gy - 8}" width="2" height="16" fill="{SURFACE0}"/>')

    # axis labels, chart-style: hours along the bottom, degrees up the left
    font = 'font-family="Departure Mono" font-size="22"'
    for i, gx in enumerate(range(GRID, W, GRID)):
        out.append(f'<text x="{gx + 10}" y="{H - 30}" {font} fill="{SURFACE1}">{(i + 1) * 2:02d}h</text>')
    for i, gy in enumerate(range(GRID, H, GRID)):
        deg = 75 - i * 25
        label = f"{deg:+d}" if deg else "0"
        out.append(f'<text x="30" y="{gy - 10}" {font} fill="{SURFACE1}">{label}&#176;</text>')

    # orbits: dotted circles around a centre off the bottom-right edge
    cx, cy = 3420, 1980
    for r in (760, 1180):
        out.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{SURFACE1}" '
                   f'stroke-width="2" stroke-dasharray="4 12" shape-rendering="geometricPrecision"/>')
    # a small body on the inner orbit, and its centre
    out.append(f'<rect x="{even(cx - 760 * 0.62)}" y="{even(cy - 760 * 0.785)}" width="10" height="10" fill="{MAUVE}" opacity="0.85"/>')
    out.append(f'<rect x="{cx - 3}" y="{cy - 3}" width="6" height="6" fill="{OVERLAY0}"/>')

    # stars: mostly dim specks, some brighter, two in the accent; kept off
    # the top strip where the bar floats
    for n in range(STARS):
        x, y = even(rnd.uniform(40, W - 40)), even(rnd.uniform(120, H - 80))
        roll = rnd.random()
        if n < 2:
            size, colour = 4, MAUVE
        elif roll < 0.07:
            size, colour = 4, SUBTEXT0
        elif roll < 0.30:
            size, colour = 2, OVERLAY1
        else:
            size, colour = 2, OVERLAY0
        out.append(f'<rect x="{x}" y="{y}" width="{size}" height="{size}" fill="{colour}"/>')

    out.append("</svg>")
    return "\n".join(out)


def main():
    dest = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OUT)
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
        f.write(svg())
        src = f.name
    try:
        subprocess.run(["rsvg-convert", "-o", dest, src], check=True)
    finally:
        os.unlink(src)
    print(dest)


if __name__ == "__main__":
    main()

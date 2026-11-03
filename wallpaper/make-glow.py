#!/usr/bin/env python3
"""Lagoon's second wallpaper, "Glow": a bowl of teal light seen through fluted glass.

A glow rises from an arc low in the picture; vertical glass flutes shift it a little in each
of their columns and catch a thin line of light on their edges. Drawn from scratch, in the
Catppuccin Mocha colors, from crust to teal and Latte's base at the heart of the light.

usage: make-glow.py <output.png> <width> <height>
"""
import sys

import numpy as np
from PIL import Image

# light, dark to bright: Mocha crust and base, Latte teal, Mocha teal, Latte base
RAMP = [(0.00, "#11111b"), (0.16, "#1e1e2e"), (0.45, "#179299"), (0.78, "#94e2d5"), (1.00, "#eff1f5")]
FLUTES = 8


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float64)


def colorize(light):
    """Light (0..1) through the ramp."""
    out = np.zeros(light.shape + (3,))
    for (a, ca), (b, cb) in zip(RAMP, RAMP[1:]):
        t = np.clip((light - a) / (b - a), 0, 1)[..., None]
        inside = ((light >= a) & (light <= b))[..., None]
        out = np.where(inside, rgb(ca) * (1 - t) + rgb(cb) * t, out)
    return np.clip(out, 0, 255)


def glow(u, v):
    """The bowl of light: brightest on its arc, fading slowly above it, quickly below."""
    arc = 0.80 - 2.1 * (u - 0.5) ** 2           # low in the middle, rising to the sides
    above = np.exp(-((arc - v) / 0.22) ** 2)
    # below the arc, the glass stays lit, dimly
    below = 0.62 * np.exp(-((v - arc) / 0.05) ** 2) + 0.38 * np.exp(-((v - arc) / 0.30) ** 2)
    light = np.where(v < arc, above, below)
    return light * (0.45 + 0.55 * np.exp(-((u - 0.5) / 0.22) ** 2))


def main():
    out, width, height = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    y, x = np.mgrid[0:height, 0:width].astype(np.float64)
    u, v = x / width, y / height
    # each flute bends the light a little, from its left edge to its right one
    t = (u * FLUTES) % 1.0
    column = np.floor(u * FLUTES)
    shift = 0.045 * (t - 0.5) + 0.012 * np.sin(column * 1.7)
    light = glow(u + 0.02 * (t - 0.5), v + shift)
    # the flutes' edges catch a thread of light, brighter where the glow is
    edge = np.exp(-(np.minimum(t, 1 - t) * width / FLUTES / 1.6) ** 2)
    light = light + edge * (0.16 + 0.6 * light)
    # the top fades into the night
    light = light * (0.25 + 0.75 * np.clip(v / 0.35, 0, 1) ** 0.8)
    Image.fromarray(colorize(np.clip(light, 0, 1)).astype(np.uint8)).save(out)


if __name__ == "__main__":
    main()

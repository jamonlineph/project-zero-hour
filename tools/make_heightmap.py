#!/usr/bin/env python3
"""Builds a map's height.r16 from the "terrain_gen" block in its map.json.

Usage: python3 tools/make_heightmap.py game/data/maps/<id>

height.r16 is raw 16-bit little-endian, one sample per 2 m cell, row by row
from the map's (0, 0) corner; 65535 means "height_scale_cm" (see
docs/design/maps-and-modes.md). The output is deterministic, so the file can
be rebuilt and compared. terrain_gen keys (all optional, meters):
  "base_m":     ground level
  "hills":      [[x, y, radius, height], ...]   smooth Gaussian bumps (negative = dips)
  "raise_obstacles_m": height added inside every obstacle rectangle (rock outcrops)
  "channels":   [[x, y, w, h, bed], ...]   rectangles carved down to height "bed"
                (rivers); the ground slopes back up over "bank_m" around them
  "bank_m":     width of a channel's sloped bank (default 6)
  "mirror_x":   true copies the west half onto the east half, so the heights
                are exactly mirrored across the middle (1v1 fairness)
"""

import json
import math
import os
import sys

import numpy as np

CELL_M = 2.0


def build(folder):
    with open(os.path.join(folder, "map.json"), encoding="utf-8") as f:
        m = json.load(f)
    gen = m.get("terrain_gen", {})
    w = math.ceil(m["width_m"] / CELL_M)
    h = math.ceil(m["height_m"] / CELL_M)
    xs = (np.arange(w) + 0.5) * CELL_M
    ys = (np.arange(h) + 0.5) * CELL_M
    gx, gy = np.meshgrid(xs, ys)
    height = np.full((h, w), float(gen.get("base_m", 0.0)))
    for x, y, radius, amp in gen.get("hills", []):
        height += amp * np.exp(-((gx - x) ** 2 + (gy - y) ** 2) / (2.0 * radius * radius))
    raise_m = float(gen.get("raise_obstacles_m", 0.0))
    if raise_m:
        for ox, oy, ow, oh in m.get("obstacles_m", []):
            inside = (gx >= ox) & (gx < ox + ow) & (gy >= oy) & (gy < oy + oh)
            height[inside] += raise_m
    bank = float(gen.get("bank_m", 6.0))
    for x, y, cw, ch, bed in gen.get("channels", []):
        dx = np.maximum(np.maximum(x - gx, gx - (x + cw)), 0.0)
        dy = np.maximum(np.maximum(y - gy, gy - (y + ch)), 0.0)
        t = np.clip(np.sqrt(dx * dx + dy * dy) / bank, 0.0, 1.0)
        height = np.minimum(height, bed + (height - bed) * t)
    if gen.get("mirror_x", False):
        for i in range(w // 2):
            height[:, w - 1 - i] = height[:, i]
    scale_m = m["height_scale_cm"] / 100.0
    if height.min() < 0 or height.max() > scale_m:
        sys.exit("heights %.2f..%.2f m fall outside 0..%.2f m (height_scale_cm)" % (height.min(), height.max(), scale_m))
    samples = np.round(height / scale_m * 65535.0).astype("<u2")
    out = os.path.join(folder, m.get("height", "height.r16"))
    samples.tofile(out)
    step = np.max(np.abs(np.diff(height, axis=0))) if h > 1 else 0.0
    step = max(step, np.max(np.abs(np.diff(height, axis=1))) if w > 1 else 0.0)
    print("[make_heightmap] %s: %dx%d cells, %.2f..%.2f m, steepest step %.2f m" % (
        out, w, h, height.min(), height.max(), step))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    build(sys.argv[1])

#!/usr/bin/env python3
"""Make the flat gradient wallpaper (3456x2160) for the desktop and the lock screen. No blur effect: a smooth colour ramp with dither."""
import sys
import numpy as np
from PIL import Image

W, H = 3456, 2160
out = sys.argv[1] if len(sys.argv) > 1 else "m3-flat-blue.png"
# Colour stops along a diagonal from top left (0) to bottom right (1).
stops = [(0.00, (10, 31, 92)), (0.45, (22, 74, 190)), (0.80, (52, 96, 214)), (1.00, (96, 84, 214))]
y, x = np.mgrid[0:H, 0:W].astype(np.float32)
t = (x / W * 0.55 + y / H * 0.45)
img = np.zeros((H, W, 3), np.float32)
ts = [s[0] for s in stops]
for c in range(3):
    img[..., c] = np.interp(t, ts, [s[1][c] for s in stops])
rng = np.random.default_rng(7)
img += rng.uniform(-0.6, 0.6, (H, W, 1)).astype(np.float32)  # dither, avoids banding
Image.fromarray(np.clip(img + 0.5, 0, 255).astype(np.uint8)).save(out, optimize=True)

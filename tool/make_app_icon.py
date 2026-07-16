#!/usr/bin/env python3
"""Generate all Makon 3D brand images from the Makon logo image.

Crops the wordmark under the icon and writes:
  - every size referenced by AppIcon.appiconset/Contents.json (white bg),
  - LaunchImage 1x/2x/3x (transparent),
  - assets/branding/makon3d_logo.png (transparent, used by the splash screen).
"""

import sys
from pathlib import Path

from PIL import Image

SRC = Path(sys.argv[1])
ICONSET = Path(__file__).resolve().parent.parent / (
    "ios/Runner/Assets.xcassets/AppIcon.appiconset"
)

# (filename, pixel size)
SIZES = [
    ("Icon-App-20x20@1x.png", 20),
    ("Icon-App-20x20@2x.png", 40),
    ("Icon-App-20x20@3x.png", 60),
    ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-29x29@2x.png", 58),
    ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-40x40@1x.png", 40),
    ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@3x.png", 120),
    ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-60x60@3x.png", 180),
    ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-76x76@2x.png", 152),
    ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]

img = Image.open(SRC).convert("RGBA")

# Flatten onto white (App Store icons must not have alpha).
flat = Image.new("RGB", img.size, (255, 255, 255))
flat.paste(img, mask=img.split()[3])

# Row-wise content detection. A strict threshold plus a minimum pixel count
# per row lets us ignore the faint drop shadow that bridges icon and text.
px = flat.load()
w, h = flat.size
row_content = []
for y in range(h):
    count = 0
    for x in range(0, w, 2):
        r, g, b = px[x, y]
        if r < 225 or g < 225 or b < 225:
            count += 1
    row_content.append(count)

MIN_ROW = 3
# Find content bands (consecutive rows with content) — the icon is the
# tallest band, the wordmark is the band below the gap.
bands = []
start = None
for y, c in enumerate(row_content):
    if c >= MIN_ROW and start is None:
        start = y
    elif c < MIN_ROW and start is not None:
        bands.append((start, y - 1))
        start = None
if start is not None:
    bands.append((start, h - 1))

if not bands:
    sys.exit("no content found in source image")

icon_band = max(bands, key=lambda b: b[1] - b[0])
print(f"content bands: {bands}, using icon band {icon_band}")

icon_region = flat.crop((0, icon_band[0], w, icon_band[1] + 1))

# Trim horizontal whitespace.
gray = icon_region.convert("L").point(lambda v: 0 if v >= 225 else 255)
bbox = gray.getbbox()
icon = icon_region.crop(bbox)
print(f"icon trimmed to {icon.size}")

# Center on a square canvas with ~8% margin on the larger dimension.
side = round(max(icon.size) * 1.16)
canvas = Image.new("RGB", (side, side), (255, 255, 255))
canvas.paste(icon, ((side - icon.width) // 2, (side - icon.height) // 2))

master = canvas.resize((1024, 1024), Image.LANCZOS)

for name, size in SIZES:
    out = master if size == 1024 else master.resize((size, size), Image.LANCZOS)
    out.save(ICONSET / name, "PNG")
    print(f"wrote {name} ({size}x{size})")

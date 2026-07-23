#!/usr/bin/env python3
"""Generate Makon brand images from the SVG mark.

Requires `rsvg-convert` (librsvg) on PATH.

Writes:
  - every size in AppIcon.appiconset (yellow bg, black mark, no wordmark),
  - LaunchImage 1x/2x/3x (transparent mark only),
  - assets/branding/makon3d_logo.png (transparent mark).
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ICONSET = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
LAUNCHSET = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
BRANDING = ROOT / "assets/branding"
MARK_SVG = BRANDING / "makon3d_mark.svg"
LOGO_SVG = BRANDING / "makon3d_logo.svg"

# Makon yellow — matches MakonColors.yellow / LaunchScreen.storyboard.
YELLOW = (255, 204, 0)

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


def _require_rsvg() -> str:
    path = shutil.which("rsvg-convert")
    if not path:
        sys.exit("rsvg-convert not found — install librsvg (e.g. brew install librsvg)")
    return path


def _rasterize(rsvg: str, svg: Path, out: Path, width: int, height: int | None = None) -> None:
    cmd = [rsvg, "-w", str(width)]
    if height is not None:
        cmd += ["-h", str(height)]
    cmd += [str(svg), "-o", str(out)]
    subprocess.run(cmd, check=True)


def main() -> None:
    rsvg = _require_rsvg()
    if not MARK_SVG.is_file() or not LOGO_SVG.is_file():
        sys.exit(f"missing brand SVGs under {BRANDING}")

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        mark_png = tmp_path / "mark.png"
        logo_png = tmp_path / "logo.png"
        _rasterize(rsvg, MARK_SVG, mark_png, 1024, 1024)
        _rasterize(rsvg, LOGO_SVG, logo_png, 1024, 1024)

        mark = Image.open(mark_png).convert("RGBA")
        # App Store icons must not have alpha — flatten onto Makon yellow.
        icon_master = Image.new("RGB", (1024, 1024), YELLOW)
        icon_master.paste(mark, mask=mark.split()[3])

        for name, size in SIZES:
            out = icon_master if size == 1024 else icon_master.resize((size, size), Image.LANCZOS)
            out.save(ICONSET / name, "PNG")
            print(f"wrote {name} ({size}x{size})")

        logo = Image.open(logo_png).convert("RGBA")
        # Launch image: transparent mark only (storyboard supplies yellow field).
        side3 = 520
        launch3 = logo.resize((side3, side3), Image.LANCZOS)
        for scale, name in ((3, "LaunchImage@3x.png"), (2, "LaunchImage@2x.png"), (1, "LaunchImage.png")):
            side = round(side3 * scale / 3)
            launch3.resize((side, side), Image.LANCZOS).save(LAUNCHSET / name, "PNG")
            print(f"wrote {name} ({side}x{side})")

        brand_side = 1024
        logo.resize((brand_side, brand_side), Image.LANCZOS).save(BRANDING / "makon3d_logo.png", "PNG")
        print(f"wrote assets/branding/makon3d_logo.png ({brand_side}x{brand_side})")


if __name__ == "__main__":
    main()

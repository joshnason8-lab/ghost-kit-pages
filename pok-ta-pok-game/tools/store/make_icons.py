#!/usr/bin/env python3
"""The launcher icons from the game's own render (tools/store/icon_render.tscn writes icon_render.png): the stone
ring of the classic court with the rubber ball in its hole. Writes assets/icon/icon_512.png (Play's hi-res icon and
the project icon), icon_192.png (the legacy launcher icon), and the adaptive icon's 432 px foreground (the render,
centred, so the ball sits in every mask's safe zone) and background (the stone's shade).

Usage: python3 tools/store/make_icons.py [render.png]   (needs Pillow)
"""
import pathlib
import sys

from PIL import Image, ImageEnhance

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "tools/store/icon_render_source.webp"


def main() -> int:
    im = Image.open(SRC).convert("RGB")
    w, h = im.size
    # Crop round the ball (the render's centre), a little in, and warm it toward evening.
    k = int(min(w, h) * 0.86)
    im = im.crop(((w - k) // 2, (h - k) // 2, (w + k) // 2, (h + k) // 2))
    im = ImageEnhance.Contrast(im).enhance(1.12)
    r, g, b = im.split()
    r = r.point(lambda v: min(255, int(v * 1.05)))
    b = b.point(lambda v: int(v * 0.9))
    im = Image.merge("RGB", (r, g, b))
    out = ROOT / "assets/icon"
    out.mkdir(parents=True, exist_ok=True)
    im.resize((512, 512), Image.LANCZOS).save(out / "icon_512.png", optimize=True)
    im.resize((192, 192), Image.LANCZOS).save(out / "icon_192.png", optimize=True)
    im.resize((432, 432), Image.LANCZOS).save(out / "icon_fg_432.png", optimize=True)
    Image.new("RGB", (432, 432), (0xB9, 0xA8, 0x86)).save(out / "icon_bg_432.png", optimize=True)
    print("icons written to", out.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())

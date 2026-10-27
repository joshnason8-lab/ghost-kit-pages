#!/usr/bin/env python3
"""The store's feature graphic (1024 x 500): the owner's artwork (store/graphics/icon-source.jpg, the ball sweeping
through the ring) on the right, the arena's night blue on the left under the game's name and line, in the game's own
display face. And the store icon copy.

Usage: python3 tools/store/make_feature.py
"""
import pathlib
import shutil
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent


def main() -> None:
    art = Image.open(ROOT / "store" / "graphics" / "icon-source.jpg").convert("RGBA").resize((560, 560), Image.LANCZOS)
    img = Image.new("RGBA", (1024, 500), (10, 22, 58, 255))
    img.alpha_composite(art, (1024 - 560, -30))
    # The art fades into the blue toward the words.
    shade = Image.new("RGBA", img.size)
    d = ImageDraw.Draw(shade)
    for x in range(1024):
        a = int(min(1.0, max(0.0, (720 - x) / 256.0)) ** 1.5 * 255)
        d.line([(x, 0), (x, 500)], fill=(10, 22, 58, a))
    img.alpha_composite(shade)
    d = ImageDraw.Draw(img)
    big = ImageFont.truetype(str(ROOT / "fonts" / "BarlowCondensed-ExtraBold.ttf"), 112)
    small = ImageFont.truetype(str(ROOT / "fonts" / "BarlowCondensed-SemiBold.ttf"), 40)
    d.text((48, 108), "NETBALL", font=big, fill=(246, 243, 255))
    d.text((48, 214), "UNLEASHED", font=big, fill=(255, 140, 40))
    d.text((52, 346), "The real rules. Nineteen languages.", font=small, fill=(246, 243, 255))
    out = ROOT / "store" / "graphics"
    out.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(out / "feature-1024x500.png")
    shutil.copy(ROOT / "assets" / "icon" / "icon_512.png", out / "icon-512.png")
    print("feature graphic and icon written")


if __name__ == "__main__":
    main()

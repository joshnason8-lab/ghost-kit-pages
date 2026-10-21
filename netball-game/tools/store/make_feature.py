#!/usr/bin/env python3
"""The store's feature graphic (1024 x 500): a frame of a match from the game, darkened on the left under the game's
name and line, in the game's own display face. And the store icon copy.

Usage: python3 tools/store/make_feature.py SCREENSHOT.png   (a 1920 x 1080 frame from tests/screenshots.tscn)
"""
import pathlib
import shutil
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent


def main() -> None:
    shot = Image.open(sys.argv[1]).convert("RGBA")
    # Crop the court's middle, without the scoreboard and buttons, to 1024 x 500.
    w, h = shot.size
    box = (int(w * 0.18), int(h * 0.27), int(w * 0.18) + int(h * 0.62 * 1024 / 500), int(h * 0.89))
    img = shot.crop(box).resize((1024, 500), Image.LANCZOS)
    shade = Image.new("RGBA", img.size)
    d = ImageDraw.Draw(shade)
    for x in range(1024):
        a = int(max(0.0, 1.0 - x / 640.0) * 225)
        d.line([(x, 0), (x, 500)], fill=(20, 16, 41, a))
    img.alpha_composite(shade)
    d = ImageDraw.Draw(img)
    big = ImageFont.truetype(str(ROOT / "fonts" / "BarlowCondensed-ExtraBold.ttf"), 112)
    small = ImageFont.truetype(str(ROOT / "fonts" / "BarlowCondensed-SemiBold.ttf"), 40)
    d.text((48, 108), "CENTRE PASS", font=big, fill=(246, 243, 255))
    d.text((48, 214), "NETBALL", font=big, fill=(200, 240, 60))
    d.text((52, 346), "The real rules. Nineteen languages.", font=small, fill=(246, 243, 255))
    out = ROOT / "store" / "graphics"
    out.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(out / "feature-1024x500.png")
    shutil.copy(ROOT / "assets" / "icon" / "icon_512.png", out / "icon-512.png")
    print("feature graphic and icon written")


if __name__ == "__main__":
    main()

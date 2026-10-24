#!/usr/bin/env python3
"""Draw the bib letters (GS, GA, WA, C, WD, GD, GK) into one strip, white on clear, for the players' bibs
(game/body.gd samples it). Barlow Condensed ExtraBold, the game's display face.

Usage: python3 tools/art/make_bib_letters.py   (needs Pillow)
"""
import pathlib
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
CELL = 128
POS = ["GS", "GA", "WA", "C", "WD", "GD", "GK"]


def main() -> None:
    font = ImageFont.truetype(str(ROOT / "fonts" / "BarlowCondensed-ExtraBold.ttf"), 112)
    img = Image.new("RGBA", (CELL * len(POS), CELL), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    for i, p in enumerate(POS):
        box = d.textbbox((0, 0), p, font=font)
        w, h = box[2] - box[0], box[3] - box[1]
        d.text((i * CELL + (CELL - w) / 2 - box[0], (CELL - h) / 2 - box[1]), p, font=font, fill=(255, 255, 255, 255))
    out = ROOT / "assets" / "ui" / "bib_letters.png"
    img.save(out)
    print(out, img.size)


if __name__ == "__main__":
    main()

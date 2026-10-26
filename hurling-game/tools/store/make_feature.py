#!/usr/bin/env python3
"""Make the store's feature graphic (store/graphics/feature-1024x500.png) from the owner's cover artwork
(tools/store/src/cover_source.webp: a hurler in green striking at dusk): the hurler on the right, the artwork's cream
sky carried across to the left under the game's name in its uncial letters, a programme's red masthead on top.

Usage: python3 tools/store/make_feature.py   (needs Pillow)
"""
import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
W, H = 1024, 500
INK = (28, 26, 22)
GREEN = (24, 84, 52)
RED = (200, 69, 44)
PAPER = (246, 238, 214)


def main():
    art = Image.open(ROOT / "tools/store/src/cover_source.webp").convert("RGB")
    aw, ah = art.size
    # The hurler, from his helmet to his boots, at the graphic's height.
    box = (int(aw * 0.08), int(ah * 0.22), int(aw * 0.98), int(ah * 0.93))
    hurler = art.crop(box)
    scale = H / hurler.size[1]
    hurler = hurler.resize((round(hurler.size[0] * scale), H), Image.LANCZOS)
    # The cream of the artwork's sky, carried across the whole graphic.
    sky = art.crop((int(aw * 0.55), int(ah * 0.05), int(aw * 0.95), int(ah * 0.2))).resize((1, 1), Image.LANCZOS)
    paper = sky.getpixel((0, 0))
    pic = Image.new("RGB", (W, H), paper)
    x0 = W - hurler.size[0]
    # Blend the artwork's left edge into the paper.
    mask = Image.new("L", hurler.size, 255)
    mp = mask.load()
    fade = 90
    for x in range(fade):
        for y in range(hurler.size[1]):
            mp[x, y] = int(255 * x / fade)
    pic.paste(hurler, (x0, 0), mask)
    d = ImageDraw.Draw(pic)
    d.rectangle([0, 0, W, 46], fill=RED)
    small = ImageFont.truetype(str(ROOT / "fonts/NotoSans.ttf"), 20)
    small.set_variation_by_axes([700])
    d.text((40, 11), "CLÁR AN LAE  ·  HURLING  ·  IOMÁNAÍOCHT", font=small, fill=PAPER)
    title = ImageFont.truetype(str(ROOT / "fonts/Oswald.ttf"), 100)
    title.set_variation_by_axes([700])
    d.text((40, 92), "HURLING", font=title, fill=INK)
    d.text((40, 205), "HEROES", font=title, fill=GREEN)
    line = ImageFont.truetype(str(ROOT / "fonts/Oswald.ttf"), 32)
    line.set_variation_by_axes([500])
    d.text((44, 360), "Fifteen a side. Every rule.", font=line, fill=INK)
    d.text((44, 402), "As Gaeilge too.", font=line, fill=INK)
    out = ROOT / "store/graphics/feature-1024x500.png"
    pic.save(out)
    print("wrote", out.relative_to(ROOT))


if __name__ == "__main__":
    main()

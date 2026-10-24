#!/usr/bin/env python3
"""Make the store's feature graphic (store/graphics/feature-1024x500.png) from the game's own render of the stone
court and its ring (tools/store/feature_source.webp, written by tools/store/icon_render.tscn): the court on the right,
a warm limestone wash carried across to the left under the game's name, a painted masthead on top.

Usage: python3 tools/store/make_feature.py   (needs Pillow)
"""
import pathlib

from PIL import Image, ImageDraw, ImageFont, ImageEnhance

ROOT = pathlib.Path(__file__).resolve().parents[2]
W, H = 1024, 500
INK = (34, 26, 18)
JADE = (34, 110, 96)
SAFF = (0xD9, 0x8B, 0x3A)
RED = (0xB5, 0x37, 0x2E)
PAPER = (0xE9, 0xDC, 0xC3)


def main():
    art = Image.open(ROOT / "tools/store/feature_source.webp").convert("RGB")
    aw, ah = art.size
    art = ImageEnhance.Contrast(art).enhance(1.08)
    # The court picture fills the right two thirds.
    rw = int(W * 0.62)
    court = art.resize((rw, H), Image.LANCZOS)
    pic = Image.new("RGB", (W, H), PAPER)
    x0 = W - rw
    mask = Image.new("L", court.size, 255)
    mp = mask.load()
    fade = 150
    for x in range(fade):
        v = int(255 * x / fade)
        for y in range(court.size[1]):
            mp[x, y] = v
    pic.paste(court, (x0, 0), mask)
    d = ImageDraw.Draw(pic)
    d.rectangle([0, 0, W, 46], fill=RED)
    small = ImageFont.truetype(str(ROOT / "fonts/NotoSans.ttf"), 20)
    small.set_variation_by_axes([700])
    d.text((40, 11), "ULAMA DE CADERA  ·  POK TA POK  ·  PELOTA MAYA", font=small, fill=PAPER)
    title = ImageFont.truetype(str(ROOT / "fonts/Oswald.ttf"), 86)
    title.set_variation_by_axes([700])
    d.text((40, 96), "POK TA POK", font=title, fill=INK)
    d.text((40, 192), "RIVALS", font=title, fill=JADE)
    line = ImageFont.truetype(str(ROOT / "fonts/Oswald.ttf"), 30)
    line.set_variation_by_axes([500])
    d.text((44, 330), "The hip ballgame of Mexico,", font=line, fill=INK)
    d.text((44, 372), "as it is played.", font=line, fill=INK)
    out = ROOT / "store/graphics/feature-1024x500.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    pic.save(out)
    print("wrote", out.relative_to(ROOT))


if __name__ == "__main__":
    main()

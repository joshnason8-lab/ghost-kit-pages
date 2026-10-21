#!/usr/bin/env python3
"""Make the store's feature graphic (store/graphics/feature-1024x500.png): a strike at the parish field at dusk, from
a real match (store/graphics/feature_src.png, written by tools/store/store_shots.tscn without the scoreboard), with
a programme's red masthead, the game's name in its uncial letters and its line, on the dusk green.

Usage: python3 tools/store/make_feature.py   (needs Pillow)
"""
import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
W, H = 1024, 500
GREEN = (16, 32, 26)
PAPER = (239, 229, 204)
RED = (200, 69, 44)
GOLD = (242, 211, 137)


def main():
    src = Image.open(ROOT / "store/graphics/feature_src.png").convert("RGB")
    sw, sh = src.size
    # The action is at the middle of the frame: crop round it, to the graphic's shape.
    crop_w = int(sw * 0.62)
    crop_h = int(crop_w * H / W)
    cx, cy = sw // 2, int(sh * 0.48)
    box = (cx - crop_w // 2 + int(sw * 0.1), cy - crop_h // 2, cx + crop_w // 2 + int(sw * 0.1), cy + crop_h // 2)
    pic = src.crop(box).resize((W, H), Image.LANCZOS).convert("RGBA")
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = shade.load()
    for x in range(W):
        a = int(max(0.0, 1.0 - x / (W * 0.6)) ** 1.3 * 238)
        for y in range(H):
            px[x, y] = GREEN + (a,)
    pic.alpha_composite(shade)
    d = ImageDraw.Draw(pic)
    # The masthead band.
    d.rectangle([0, 0, W, 46], fill=RED)
    small = ImageFont.truetype(str(ROOT / "fonts/NotoSans.ttf"), 20)
    small.set_variation_by_axes([700])
    d.text((40, 11), "CLÁR AN LAE  ·  HURLING  ·  IOMÁNAÍOCHT", font=small, fill=PAPER)
    title = ImageFont.truetype(str(ROOT / "fonts/UncialAntiqua.ttf"), 96)
    for dx, dy in [(-3, 0), (3, 0), (0, -3), (0, 3)]:
        d.text((38 + dx, 120 + dy), "Ash &", font=title, fill=(6, 12, 9))
        d.text((38 + dx, 230 + dy), "Leather", font=title, fill=(6, 12, 9))
    d.text((38, 120), "Ash &", font=title, fill=PAPER)
    d.text((38, 230), "Leather", font=title, fill=GOLD)
    line = ImageFont.truetype(str(ROOT / "fonts/Oswald.ttf"), 34)
    line.set_variation_by_axes([500])
    d.text((42, 372), "Fifteen a side. Every rule. As Gaeilge too.", font=line, fill=PAPER)
    out = ROOT / "store/graphics/feature-1024x500.png"
    pic.convert("RGB").save(out)
    print("wrote", out.relative_to(ROOT))


if __name__ == "__main__":
    main()

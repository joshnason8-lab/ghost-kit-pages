#!/usr/bin/env python3
"""Make the store's feature graphic (store/graphics/feature-1024x500.png): the roll spike from a real match
(store/graphics/feature_src.png, written by tools/store/store_shots.tscn without the scoreboard), the game's name
and its line, on the menus' navy.

Usage: python3 tools/store/make_feature.py   (needs Pillow)
"""
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
W, H = 1024, 500


def main():
    src = Image.open(ROOT / "store/graphics/feature_src.png").convert("RGB")
    # The action: the middle of the frame, around the net.
    sw, sh = src.size
    crop_w = int(sh * W / H * 0.62)
    cx = sw // 2
    box = (cx - crop_w // 2 - int(sw * 0.13), int(sh * 0.12), cx + crop_w // 2 - int(sw * 0.13), int(sh * 0.12) + int(crop_w * H / W))
    pic = src.crop(box).resize((W, H), Image.LANCZOS)
    # Navy shading from the left, under the words.
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = shade.load()
    for x in range(W):
        a = int(max(0.0, 1.0 - x / (W * 0.62)) ** 1.4 * 235)
        for y in range(H):
            px[x, y] = (12, 26, 41, a)
    img = pic.convert("RGBA")
    img.alpha_composite(shade)
    d = ImageDraw.Draw(img)
    teko = str(ROOT / "fonts/Teko.ttf")
    title = ImageFont.truetype(teko, 120)
    title.set_variation_by_axes([700])
    eyebrow = ImageFont.truetype(str(ROOT / "fonts/NotoSans.ttf"), 22)
    eyebrow.set_variation_by_axes([700])
    line = ImageFont.truetype(teko, 44)
    line.set_variation_by_axes([500])
    d.text((54, 84), "SEPAK TAKRAW FOR ANDROID", font=eyebrow, fill=(255, 154, 31))
    for dx, dy in [(-3, 0), (3, 0), (0, -3), (0, 3)]:
        d.text((50 + dx, 116 + dy), "SEPAK TAKRAW", font=title, fill=(4, 10, 18))
        d.text((50 + dx, 216 + dy), "UNLEASHED", font=title, fill=(4, 10, 18))
    d.text((50, 116), "SEPAK TAKRAW", font=title, fill=(243, 239, 230))
    d.text((50, 216), "UNLEASHED", font=title, fill=(255, 154, 31))
    d.text((54, 360), "Five venues. Thirteen languages.", font=line, fill=(255, 210, 122))
    out = ROOT / "store/graphics/feature-1024x500.png"
    img.convert("RGB").save(out)
    print("wrote", out.relative_to(ROOT))


if __name__ == "__main__":
    main()

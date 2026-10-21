#!/usr/bin/env python3
"""The Play feature graphic (1024 x 500): the rink from the broadcast camera (store/graphics/feature_src.png, from
tools/store/store_shots.tscn), a whiteboard panel on the left with the name in marker and a line under it.

Usage: python3 tools/store/make_feature.py   (needs Pillow)
"""
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]


def main() -> None:
    src = Image.open(ROOT / "store" / "graphics" / "feature_src.png").convert("RGB")
    w, h = 1024, 500
    k = max(w / src.width, h / src.height)
    src = src.resize((int(src.width * k), int(src.height * k)), Image.LANCZOS)
    x0 = max(0, (src.width - w) // 2)
    img = src.crop((x0, (src.height - h) // 2, x0 + w, (src.height - h) // 2 + h)).convert("RGBA")
    board = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(board)
    d.rounded_rectangle([28, 70, 500, 430], 10, fill=(233, 236, 234, 245), outline=(170, 179, 188, 255), width=8)
    shadow = board.filter(ImageFilter.GaussianBlur(10))
    img = Image.alpha_composite(img, Image.eval(shadow, lambda v: v // 3))
    img = Image.alpha_composite(img, board)
    d = ImageDraw.Draw(img)
    title = ImageFont.truetype(str(ROOT / "fonts" / "Caveat.ttf"), 100)
    title.set_variation_by_axes([700])
    d.text((60, 120), "Floorstorm", font=title, fill=(29, 78, 216))
    sub = ImageFont.truetype(str(ROOT / "fonts" / "BarlowCondensed-SemiBold.ttf"), 36)
    d.text((64, 268), "FLOORBALL · 5 v 5 · REAL RULES", font=sub, fill=(31, 41, 51))
    d.line([(64, 250), (440, 244)], fill=(214, 40, 57), width=6)
    for i, c in enumerate([(29, 78, 216), (214, 40, 57), (15, 139, 95), (240, 138, 36)]):
        cx, cy = 80 + i * 44, 370
        d.ellipse([cx - 15, cy - 15, cx + 15, cy + 15], fill=c)
    out = ROOT / "store" / "graphics" / "feature-1024x500.png"
    img.convert("RGB").save(out)
    print(out)


if __name__ == "__main__":
    main()

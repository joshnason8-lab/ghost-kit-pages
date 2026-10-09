#!/usr/bin/env python3
"""Turn the rendered poses into flat pictogram silhouettes for the menus.

    python3 tools/ui_art/pack_art.py RENDER_DIR      # writes assets/ui/pose_*.png

Each render's alpha becomes a white silhouette (the menus tint it), cropped to the figure
and lightly smoothed, so the art reads as a clean sports pictogram at any size.
"""
import os
import sys

from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "ui"))


def main(src):
    os.makedirs(OUT, exist_ok=True)
    for f in sorted(os.listdir(src)):
        if not (f.startswith("art_") and f.endswith(".png")):
            continue
        im = Image.open(os.path.join(src, f)).convert("RGBA")
        a = im.split()[3]
        a = a.point(lambda v: 255 if v > 90 else 0).filter(ImageFilter.GaussianBlur(1.2))
        a = a.point(lambda v: min(255, max(0, (v - 60) * 2)))
        box = a.getbbox()
        if box:
            pad = 12
            box = (max(0, box[0] - pad), max(0, box[1] - pad), min(a.width, box[2] + pad), min(a.height, box[3] + pad))
            a = a.crop(box)
        sil = Image.new("LA", a.size, 255)
        sil.putalpha(a)
        name = "pose_" + f[4:]
        sil.save(os.path.join(OUT, name), optimize=True)
        print("wrote", name, sil.size, os.path.getsize(os.path.join(OUT, name)) // 1024, "KB")


if __name__ == "__main__":
    main(sys.argv[1])

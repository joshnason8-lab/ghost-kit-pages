#!/usr/bin/env python3
"""The app icon and the menus' coloured figures, from the art in tools/ui_art/src.

    python3 tools/ui_art/import_art.py

src/icon_source.webp (a painted raider reaching, a defender at his thigh) becomes the launcher icon:
assets/icon/icon_bg_432.png is the adaptive icon's background, the picture full bleed, framed so his face,
his reaching hand and the hand on his thigh are inside the 72 dp a launcher shows of the 108 dp canvas (a
circle on some phones); assets/icon/icon_fg_432.png is an empty foreground; assets/icon/icon_192.png is the
icon for launchers without adaptive icons, and assets/icon/icon_512.png the project's own (the web build's).

src/art_*.png and .webp (flat silhouettes, already in the home screen tiles' colours) are cropped to the
figure and scaled down into assets/ui/art_*.png, keeping their transparency.
"""
import os

from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src")
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))

# The icon's frame on the source picture (1254 px square): the 108 dp canvas is FRAME px across round CENTRE;
# the middle two thirds of it are what a launcher shows.
CENTRE = (590, 560)
FRAME = 1300
ART_MAX = 900   # px, the longest side of a menu figure


def icon():
    src = Image.open(os.path.join(SRC, "icon_source.webp")).convert("RGB")
    w = src.width
    # Past the picture's edges (only in the margin a launcher masks off, seen while an icon is dragged or
    # animated), the picture itself, blurred and stretched.
    pad = FRAME
    base = src.resize((w + 2 * pad, w + 2 * pad), Image.LANCZOS).filter(ImageFilter.GaussianBlur(40))
    base.paste(src, (pad, pad))
    cx, cy = CENTRE[0] + pad, CENTRE[1] + pad
    half = FRAME // 2
    canvas = base.crop((cx - half, cy - half, cx + half, cy + half))
    out = os.path.join(ROOT, "assets", "icon")
    os.makedirs(out, exist_ok=True)
    canvas.resize((432, 432), Image.LANCZOS).save(os.path.join(out, "icon_bg_432.png"), optimize=True)
    Image.new("RGBA", (432, 432), (0, 0, 0, 0)).save(os.path.join(out, "icon_fg_432.png"), optimize=True)
    # The square icons: what the adaptive one shows.
    vis = FRAME * 72 // 108
    shown = base.crop((cx - vis // 2, cy - vis // 2, cx + vis // 2, cy + vis // 2))
    shown.resize((192, 192), Image.LANCZOS).save(os.path.join(out, "icon_192.png"), optimize=True)
    shown.resize((512, 512), Image.LANCZOS).save(os.path.join(out, "icon_512.png"), optimize=True)
    print("icon:", out)


def figures():
    out = os.path.join(ROOT, "assets", "ui")
    for f in sorted(os.listdir(SRC)):
        name, ext = os.path.splitext(f)
        if not name.startswith("art_") or ext not in (".png", ".webp"):
            continue
        im = Image.open(os.path.join(SRC, f)).convert("RGBA")
        box = im.split()[3].point(lambda v: 255 if v > 20 else 0).getbbox()
        if box:
            pad = 16
            box = (max(0, box[0] - pad), max(0, box[1] - pad), min(im.width, box[2] + pad), min(im.height, box[3] + pad))
            im = im.crop(box)
        k = min(1.0, ART_MAX / max(im.size))
        if k < 1.0:
            im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
        im.save(os.path.join(out, name + ".png"), optimize=True)
        print(name, im.size)


if __name__ == "__main__":
    icon()
    figures()

#!/usr/bin/env python3
"""The game's icon, drawn in code: a khamba (the pole) on red earth with the chalk lane, and a chaser in marigold diving
past it, one hand on the pole. Writes assets/icon/ (192, 512, adaptive 432 foreground and background) and
store/graphics/icon-512.png.

Usage: python3 tools/store/make_icons.py   (needs Pillow)
"""
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
SS = 4
CLAY = (181, 86, 47)
DARK = (40, 20, 14)
CHALK = (242, 244, 230)
MARIGOLD = (255, 176, 32)
WOOD = (216, 176, 122)
SKIN = (168, 107, 69)


def background(n: int) -> Image.Image:
    im = Image.new("RGBA", (n, n))
    px = im.load()
    for y in range(n):
        for x in range(n):
            d = math.hypot(x - n * 0.35, y - n * 0.3) / (n * 1.1)
            k = min(1.0, d)
            px[x, y] = tuple(int(CLAY[i] * (1 - k) + DARK[i] * k) for i in range(3)) + (255,)
    dr = ImageDraw.Draw(im)
    # The lane, running away, and two cross lanes.
    dr.polygon([(n * 0.0, n * 0.80), (n * 1.0, n * 0.70), (n * 1.0, n * 0.73), (n * 0.0, n * 0.84)], fill=CHALK + (230,))
    for x0 in (0.18, 0.62):
        dr.polygon([(n * x0, n * 1.0), (n * (x0 + 0.05), n * 1.0), (n * (x0 + 0.16), n * 0.55), (n * (x0 + 0.13), n * 0.55)], fill=CHALK + (110,))
    return im


def figure(n: int, ox: float = 0.0, oy: float = 0.0, k: float = 1.0) -> Image.Image:
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    def P(x, y):
        return (n * (ox + 0.5 + (x - 0.5) * k), n * (oy + 0.5 + (y - 0.5) * k))
    # The pole.
    dr.rectangle([P(0.62, 0.18), P(0.69, 0.80)], fill=WOOD)
    dr.rectangle([P(0.60, 0.78), P(0.71, 0.82)], fill=(138, 90, 43))
    # The chaser: a pole dive, his left hand round the pole, his body swung out flat, right arm stretched.
    w = n * 0.055 * k
    dr.line([P(0.655, 0.33), P(0.55, 0.40)], fill=SKIN, width=int(w * 0.8))           # the arm on the pole
    dr.polygon([P(0.30, 0.40), P(0.56, 0.36), P(0.58, 0.47), P(0.32, 0.52)], fill=MARIGOLD)   # the body
    dr.line([P(0.31, 0.47), P(0.14, 0.40)], fill=(40, 26, 20), width=int(w * 1.2))     # shorts and a leg behind
    dr.line([P(0.15, 0.40), P(0.04, 0.36)], fill=SKIN, width=int(w * 0.9))
    dr.line([P(0.30, 0.50), P(0.16, 0.57)], fill=(40, 26, 20), width=int(w * 1.2))
    dr.line([P(0.17, 0.57), P(0.06, 0.62)], fill=SKIN, width=int(w * 0.9))
    dr.line([P(0.57, 0.44), P(0.88, 0.46)], fill=SKIN, width=int(w * 0.8))             # the reaching arm
    cx, cy = P(0.62, 0.30)
    r = n * 0.065 * k
    dr.ellipse([cx - r, cy - r, cx + r, cy + r], fill=SKIN)
    dr.chord([cx - r, cy - r * 1.05, cx + r, cy + r * 0.6], 180, 360, fill=(26, 18, 13))
    return im


def render(n: int, fg_only=False, bg_only=False, k=1.0) -> Image.Image:
    big = n * SS
    out = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    if not fg_only:
        out = background(big)
    if not bg_only:
        fig = figure(big, 0.0, 0.0, k)
        shadow = fig.copy()
        shadow.putdata([(0, 0, 0, int(a * 0.45)) for (_, _, _, a) in fig.getdata()])
        shadow = shadow.filter(ImageFilter.GaussianBlur(big * 0.01))
        out.alpha_composite(shadow, (int(big * 0.012), int(big * 0.02)))
        out.alpha_composite(fig)
    return out.resize((n, n), Image.LANCZOS)


def main() -> None:
    icons = ROOT / "assets" / "icon"
    icons.mkdir(parents=True, exist_ok=True)
    render(512).save(icons / "icon_512.png")
    render(192).save(icons / "icon_192.png")
    # Adaptive: the figure inside the middle 66% safe zone, the ground behind.
    render(432, fg_only=True, k=0.62).save(icons / "icon_fg_432.png")
    render(432, bg_only=True).save(icons / "icon_bg_432.png")
    g = ROOT / "store" / "graphics"
    g.mkdir(parents=True, exist_ok=True)
    render(512).convert("RGB").save(g / "icon-512.png")
    print("icons written")


if __name__ == "__main__":
    main()

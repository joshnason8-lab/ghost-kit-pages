#!/usr/bin/env python3
"""Make the launcher icons (512, 192, and the adaptive icon's 432 foreground and background) and the store's 512 icon:
a hurley (the ash, its metal band) and a sliotar (white leather, its raised rim), over the evening sky of a parish
field, dusk green into amber. Drawn at four times the size and scaled down, so the edges are smooth.

Usage: python3 tools/store/make_icons.py   (needs Pillow)
"""
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
GREEN = (16, 32, 26)
GREEN2 = (31, 74, 50)
AMBER = (224, 164, 58)
ASH = (216, 178, 122)
ASH_DK = (150, 108, 62)
BAND = (170, 176, 184)
PAPER = (246, 242, 230)
INK = (24, 22, 18)


def background(n):
    img = Image.new("RGBA", (n, n), GREEN + (255,))
    px = img.load()
    for y in range(n):
        for x in range(n):
            k = min(1.0, max(0.0, (y / n) * 0.9 + (x / n) * 0.15))
            col = [GREEN2[i] + (GREEN[i] - GREEN2[i]) * k for i in range(3)]
            px[x, y] = tuple(int(c) for c in col) + (255,)
    glow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([n * 0.2, n * 0.55, n * 1.2, n * 1.4], fill=AMBER + (120,))
    glow = glow.filter(ImageFilter.GaussianBlur(n * 0.14))
    img.alpha_composite(glow)
    return img


def hurley(d, n, s=1.0, cx=0.5, cy=0.5):
    """The hurley lying on a diagonal: the handle top right, the bas (the curved blade) bottom left."""
    def P(x, y):
        return (n * (cx + (x - 0.5) * s), n * (cy + (y - 0.5) * s))
    # The shaft, from the handle down to where the bas begins.
    shaft = [P(0.80, 0.12), P(0.86, 0.17), P(0.40, 0.60), P(0.33, 0.55)]
    d.polygon(shaft, fill=ASH)
    # The bas: wider, curving round.
    bas = [P(0.33, 0.55), P(0.40, 0.60), P(0.38, 0.70), P(0.32, 0.80), P(0.22, 0.89), P(0.12, 0.92), P(0.08, 0.88),
        P(0.12, 0.80), P(0.20, 0.70), P(0.27, 0.61)]
    d.polygon(bas, fill=ASH)
    # The grain, darker along one edge.
    d.line([P(0.81, 0.15), P(0.36, 0.58), P(0.24, 0.72), P(0.13, 0.87)], fill=ASH_DK, width=max(2, int(n * 0.012 * s)))
    # The metal band round the bas, and the grip tape on the handle.
    d.line([P(0.27, 0.63), P(0.36, 0.69)], fill=BAND, width=max(3, int(n * 0.03 * s)))
    d.line([P(0.83, 0.145), P(0.71, 0.26)], fill=INK, width=max(3, int(n * 0.07 * s)))


def sliotar(d, n, r, cx, cy):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=PAPER, outline=INK, width=max(2, int(r * 0.08)))
    # The raised rim: a seam curving across the ball.
    d.arc([cx - r * 1.6, cy - r * 0.55, cx + r * 0.4, cy + r * 1.45], 300, 60, fill=(120, 110, 95), width=max(2, int(r * 0.12)))


def icon(n, with_bg=True, scale=1.0):
    big = n * 4
    img = background(big) if with_bg else Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    hurley(d, big, 0.86 * scale, 0.47, 0.52)
    bx = big * (0.5 + (0.30 - 0.5) * scale)
    by = big * (0.5 + (0.27 - 0.5) * scale)
    r = int(big * 0.1 * scale)
    # Its flight: two short arcs trailing it, back toward the bas.
    for i in range(2):
        o = r * (1.35 + i * 0.5)
        d.arc([bx - o, by - o, bx + o, by + o], 95, 140, fill=PAPER + (170 - i * 60,), width=max(2, int(r * 0.14)))
    sliotar(d, big, r, bx, by)
    return img.resize((n, n), Image.LANCZOS)


def main():
    out = ROOT / "assets" / "icon"
    out.mkdir(parents=True, exist_ok=True)
    icon(512).save(out / "icon_512.png")
    icon(192).save(out / "icon_192.png")
    # Adaptive: the picture within the middle two-thirds (the safe zone), the sky behind.
    icon(432, with_bg=False, scale=0.66).save(out / "icon_fg_432.png")
    background(432).save(out / "icon_bg_432.png")
    store = ROOT / "store" / "graphics"
    store.mkdir(parents=True, exist_ok=True)
    icon(512).convert("RGB").save(store / "icon-512.png")
    print("icons written")


if __name__ == "__main__":
    main()

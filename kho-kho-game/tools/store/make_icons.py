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
    """The pole dive: the left hand round the khamba, the body swung out flat past it, the right arm at full stretch."""
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)

    def P(x, y):
        return (n * (ox + 0.5 + (x - 0.5) * k), n * (oy + 0.5 + (y - 0.5) * k))

    def limb(a, b, w, col):
        w = int(n * w * k)
        dr.line([P(*a), P(*b)], fill=col, width=w)
        for pt in (a, b):
            cx, cy = P(*pt)
            dr.ellipse([cx - w / 2, cy - w / 2, cx + w / 2, cy + w / 2], fill=col)

    # The pole.
    dr.rounded_rectangle([P(0.30, 0.14), P(0.37, 0.84)], radius=int(n * 0.02 * k), fill=WOOD)
    dr.rectangle([P(0.27, 0.81), P(0.40, 0.85)], fill=(138, 90, 43))
    # Legs, trailing behind (to the left), in shorts then skin.
    limb((0.58, 0.47), (0.74, 0.58), 0.075, (40, 26, 20))
    limb((0.74, 0.58), (0.92, 0.66), 0.055, SKIN)
    limb((0.58, 0.44), (0.76, 0.41), 0.075, (40, 26, 20))
    limb((0.76, 0.41), (0.94, 0.44), 0.055, SKIN)
    # The body, flat out, the shirt in marigold.
    limb((0.36, 0.40), (0.58, 0.45), 0.13, MARIGOLD)
    # The arm round the pole, the hand gripping it.
    limb((0.38, 0.38), (0.335, 0.30), 0.045, SKIN)
    # The reaching arm, past the pole toward the defender.
    limb((0.38, 0.44), (0.10, 0.50), 0.045, SKIN)
    cx, cy = P(0.09, 0.50)
    r = n * 0.03 * k
    dr.ellipse([cx - r, cy - r, cx + r, cy + r], fill=SKIN)
    # The head, looking along the reach.
    cx, cy = P(0.31, 0.37)
    r = n * 0.06 * k
    dr.ellipse([cx - r, cy - r, cx + r, cy + r], fill=SKIN)
    dr.chord([cx - r, cy - r * 1.05, cx + r, cy + r * 0.7], 200, 380, fill=(26, 18, 13))
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

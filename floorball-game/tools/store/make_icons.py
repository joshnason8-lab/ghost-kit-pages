#!/usr/bin/env python3
"""Draw the app icon: a white floorball with its holes, a stick's blade under it, on the rink's blue floor with a
white board's curve and a marker stroke, as on the coach's whiteboard. Writes assets/icon/icon_512.png, icon_192.png,
the adaptive icon's layers (icon_fg_432.png, icon_bg_432.png) and store/graphics/icon-512.png.

Usage: python3 tools/store/make_icons.py   (needs Pillow)
"""
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
S = 4  # supersampling

BLUE = (44, 102, 173)
BLUE_DARK = (27, 66, 118)
WHITE = (246, 247, 244)
HOLE = (59, 64, 72)
ORANGE = (240, 138, 36)
INK = (31, 41, 51)


def background(size: int) -> Image.Image:
    img = Image.new("RGB", (size * S, size * S), BLUE)
    d = ImageDraw.Draw(img)
    n = size * S
    # A soft light from the hall's ceiling.
    for i in range(40):
        r = int(n * (0.95 - i * 0.012))
        c = tuple(min(255, int(v + i * 1.1)) for v in BLUE)
        d.ellipse([n * 0.5 - r, n * 0.32 - r, n * 0.5 + r, n * 0.32 + r], fill=c)
    # The board's white curve round the bottom corner, and the crease's line.
    d.arc([-n * 0.5, n * 0.62, n * 0.62, n * 1.7], 270, 360, fill=WHITE, width=int(n * 0.03))
    return img


def foreground(size: int, scale: float = 1.0) -> Image.Image:
    n = size * S
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy, r = n * 0.5, n * 0.44, n * 0.24 * scale
    # The stick's blade, curving under the ball, and the shaft going up to the right.
    blade = []
    for i in range(21):
        t = i / 20.0
        x = cx - r * 1.15 + t * r * 2.3
        y = cy + r * 1.22 + math.sin(t * math.pi) * r * 0.16 - t * r * 0.12
        blade.append((x, y))
    heel = blade[-1]
    d.line([heel, (heel[0] + r * 0.9, heel[1] - r * 2.6)], fill=INK, width=int(n * 0.05 * scale))
    d.line(blade, fill=ORANGE, width=int(n * 0.07 * scale), joint="curve")
    d.ellipse([heel[0] - n * 0.035 * scale, heel[1] - n * 0.035 * scale, heel[0] + n * 0.035 * scale, heel[1] + n * 0.035 * scale], fill=ORANGE)
    # The ball's shadow, the ball, its holes.
    sh = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([cx - r * 0.95, cy + r * 0.75, cx + r * 0.95, cy + r * 1.1], fill=(0, 0, 0, 90))
    img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(n * 0.01)))
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=WHITE)
    for ring, count, k in [(0.0, 1, 0.16), (0.52, 6, 0.13), (0.86, 9, 0.09)]:
        for j in range(count):
            a = j / count * math.tau + ring
            px = cx + math.cos(a) * r * ring
            py = cy + math.sin(a) * r * ring * 0.92
            hr = r * k * (1.0 - ring * 0.35)
            d.ellipse([px - hr, py - hr * (1.0 - ring * 0.3), px + hr, py + hr * (1.0 - ring * 0.3)], fill=HOLE)
    return img


def down(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    out = ROOT / "assets" / "icon"
    out.mkdir(parents=True, exist_ok=True)
    full = background(512).convert("RGBA")
    full = Image.alpha_composite(full, foreground(512))
    # Rounded like a launcher's mask would show it, for the store's icon the square is kept (Play rounds it).
    down(full, 512).convert("RGB").save(out / "icon_512.png")
    down(full, 192).convert("RGB").save(out / "icon_192.png")
    store = ROOT / "store" / "graphics"
    store.mkdir(parents=True, exist_ok=True)
    down(full, 512).convert("RGB").save(store / "icon-512.png")
    # Adaptive icon: the foreground inside the middle 66% (the safe zone), the background whole.
    down(background(432), 432).save(out / "icon_bg_432.png")
    down(foreground(432, 0.78), 432).save(out / "icon_fg_432.png")
    print("icons written")


if __name__ == "__main__":
    main()

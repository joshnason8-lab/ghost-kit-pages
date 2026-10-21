#!/usr/bin/env python3
"""Make the launcher icons (512, 192 and the adaptive icon's 432 foreground and background) and the store's 512
icon, from the menu art (assets/ui/art_spike.png, rendered by tools/ui_art/render_art.tscn): the roll spike, over
a woven ball, on the game's navy and saffron.

Usage: python3 tools/store/make_icons.py   (needs Pillow)
"""
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
NAVY = (12, 26, 41)
NAVY2 = (27, 58, 92)
SAFFRON = (255, 154, 31)
GOLD = (255, 210, 122)


def background(n):
    img = Image.new("RGBA", (n, n), NAVY + (255,))
    px = img.load()
    for y in range(n):
        for x in range(n):
            d = math.hypot(x - n * 0.35, y - n * 0.3) / n
            k = max(0.0, 1.0 - d * 1.4)
            px[x, y] = tuple(int(NAVY[i] + (NAVY2[i] - NAVY[i]) * k) for i in range(3)) + (255,)
    # A saffron glow low on the right, and the court's lines.
    glow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([n * 0.35, n * 0.45, n * 1.3, n * 1.3], fill=SAFFRON + (90,))
    glow = glow.filter(ImageFilter.GaussianBlur(n * 0.12))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    w = max(2, n // 128)
    d.line([(0, n * 0.82), (n, n * 0.7)], fill=(255, 255, 255, 40), width=w)
    d.line([(n * 0.5, n * 0.76), (n * 0.62, n)], fill=(255, 255, 255, 30), width=w)
    return img


def ball(n, r):
    """The woven synthetic ball: yellow strips crossing, dark holes between."""
    b = Image.new("RGBA", (r * 2, r * 2), (0, 0, 0, 0))
    px = b.load()
    for y in range(r * 2):
        for x in range(r * 2):
            dx, dy = (x - r) / r, (y - r) / r
            if dx * dx + dy * dy > 1:
                continue
            z = math.sqrt(1 - dx * dx - dy * dy)
            u, v = math.atan2(dx, z) * 3, math.asin(dy) * 3
            a, c = math.sin(u + v), math.sin(u - v)
            shade = 0.55 + 0.45 * (z * 0.7 + (-dx * 0.3 - dy * 0.4) + 0.3)
            if max(abs(a), abs(c)) < 0.32:
                col = (107, 61, 16)
            elif abs(a) > abs(c):
                col = (250, 205, 95)
            else:
                col = (222, 170, 62)
            px[x, y] = tuple(min(255, int(ch * shade)) for ch in col) + (255,)
    d = ImageDraw.Draw(b)
    d.ellipse([1, 1, r * 2 - 2, r * 2 - 2], outline=(12, 26, 41, 255), width=max(2, r // 14))
    return b


def figure(n, scale):
    art = Image.open(ROOT / "assets/ui/art_spike.png").convert("RGBA")
    h = int(n * scale)
    w = int(art.width * h / art.height)
    return art.resize((w, h), Image.LANCZOS)


def compose(n, safe=1.0):
    """The icon's picture at n pixels; safe shrinks it into the adaptive icon's safe circle."""
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    f = figure(n, 0.78 * safe)
    img.alpha_composite(f, (int(n * 0.5 - f.width * 0.52), int(n * 0.5 - f.height * 0.5 + n * 0.03 * safe)))
    r = int(n * 0.13 * safe)
    bl = ball(n, r)
    img.alpha_composite(bl, (int(n * 0.5 + n * 0.16 * safe), int(n * 0.5 - n * 0.36 * safe)))
    return img


def main():
    out = ROOT / "assets/icon"
    out.mkdir(parents=True, exist_ok=True)
    for n in (512, 192):
        img = background(n)
        img.alpha_composite(compose(n))
        mask = Image.new("L", (n, n), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, n - 1, n - 1], radius=int(n * 0.22), fill=255)
        rounded = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        rounded.paste(img, (0, 0), mask)
        rounded.save(out / f"icon_{n}.png")
    background(432).save(out / "icon_bg_432.png")
    compose(432, safe=0.62).save(out / "icon_fg_432.png")
    store = ROOT / "store/graphics"
    store.mkdir(parents=True, exist_ok=True)
    full = background(512)
    full.alpha_composite(compose(512))
    full.convert("RGB").save(store / "icon-512.png")
    print("icons written")


if __name__ == "__main__":
    main()

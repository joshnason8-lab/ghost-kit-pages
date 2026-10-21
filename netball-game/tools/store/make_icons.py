#!/usr/bin/env python3
"""Draw the game's icon: a netball going through the ring, on the deep indigo of an arena, with the court's blue
and a bib-lime ring. Writes assets/icon/icon_512.png (Play's store icon and the launcher), icon_192.png, and the
adaptive icon's two layers (icon_fg_432.png, icon_bg_432.png).

Usage: python3 tools/store/make_icons.py   (needs Pillow)
"""
import math
import pathlib
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
S = 4  # supersampling


def background(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            dx, dy = x / size - 0.62, y / size - 0.32
            d = min(1.0, math.hypot(dx, dy) * 1.25)
            top = (58, 42, 120)
            bot = (16, 12, 34)
            px[x, y] = tuple(int(top[i] + (bot[i] - top[i]) * d) for i in range(3)) + (255,)
    d = ImageDraw.Draw(img)
    # The court: a blue floor across the lower part with a white goal circle arc.
    floor_y = int(size * 0.72)
    d.rectangle([0, floor_y, size, size], fill=(47, 111, 196, 255))
    w = max(2, size // 60)
    d.arc([int(-size * 0.25), int(floor_y - size * 0.05), int(size * 1.25), int(floor_y + size * 0.65)], 180, 360, fill=(244, 244, 244, 255), width=w)
    return img


def foreground(size: int) -> Image.Image:
    big = size * S
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = big * 0.5
    # The post, from below, and the ring seen a little from below (an ellipse), the net hanging from it.
    post_x = big * 0.68
    d.rectangle([post_x - big * 0.022, big * 0.36, post_x + big * 0.022, big * 0.98], fill=(222, 222, 228, 255))
    ring_c = (big * 0.5, big * 0.36)
    rw, rh = big * 0.2, big * 0.055
    d.line([(ring_c[0] + rw, ring_c[1]), (post_x, ring_c[1])], fill=(222, 222, 228, 255), width=int(big * 0.022))
    # Net strands.
    for i in range(9):
        a = math.pi * i / 8
        x0 = ring_c[0] - rw * math.cos(a)
        x1 = ring_c[0] - rw * 0.62 * math.cos(a + 0.4)
        d.line([(x0, ring_c[1] + rh * math.sin(a) * 0.6), (x1, ring_c[1] + big * 0.17)], fill=(245, 245, 245, 230), width=int(big * 0.008))
    d.line([(ring_c[0] - rw * 0.62, ring_c[1] + big * 0.17), (ring_c[0] + rw * 0.62, ring_c[1] + big * 0.17)], fill=(245, 245, 245, 230), width=int(big * 0.008))
    # The ball, dropping through.
    br = big * 0.16
    bc = (big * 0.5, big * 0.27)
    d.ellipse([bc[0] - br, bc[1] - br, bc[0] + br, bc[1] + br], fill=(246, 244, 234, 255), outline=(20, 16, 41, 255), width=int(big * 0.012))
    # The ball's band: lime with violet edges.
    band = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    bd = ImageDraw.Draw(band)
    bd.rectangle([0, bc[1] - br * 0.2, big, bc[1] + br * 0.2], fill=(58, 47, 110, 255))
    bd.rectangle([0, bc[1] - br * 0.13, big, bc[1] + br * 0.13], fill=(200, 240, 60, 255))
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).ellipse([bc[0] - br + big * 0.012, bc[1] - br + big * 0.012, bc[0] + br - big * 0.012, bc[1] + br - big * 0.012], fill=255)
    img.paste(band, (0, 0), Image.composite(band, Image.new("RGBA", (big, big), (0, 0, 0, 0)), mask).split()[3])
    # Seams.
    d.arc([bc[0] - br * 0.5, bc[1] - br, bc[0] + br * 0.5, bc[1] + br], 100, 260, fill=(20, 16, 41, 200), width=int(big * 0.007))
    d.arc([bc[0] - br * 0.5, bc[1] - br, bc[0] + br * 0.5, bc[1] + br], -80, 80, fill=(20, 16, 41, 200), width=int(big * 0.007))
    # The front of the ring, over the ball: orange steel.
    d.arc([ring_c[0] - rw, ring_c[1] - rh, ring_c[0] + rw, ring_c[1] + rh], 0, 180, fill=(255, 106, 26, 255), width=int(big * 0.02))
    d.arc([ring_c[0] - rw, ring_c[1] - rh, ring_c[0] + rw, ring_c[1] + rh], 180, 360, fill=(200, 80, 20, 255), width=int(big * 0.014))
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    out = ROOT / "assets" / "icon"
    out.mkdir(parents=True, exist_ok=True)
    full = background(512)
    full.alpha_composite(foreground(512))
    # Rounded corners for the store icon are added by Play; keep it square.
    full.save(out / "icon_512.png")
    full.resize((192, 192), Image.LANCZOS).save(out / "icon_192.png")
    # Adaptive: the foreground within the safe 66% middle.
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    inner = foreground(300)
    fg.alpha_composite(inner, (66, 66))
    fg.save(out / "icon_fg_432.png")
    background(432).save(out / "icon_bg_432.png")
    print("icons written")


if __name__ == "__main__":
    main()

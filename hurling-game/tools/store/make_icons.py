#!/usr/bin/env python3
"""Make the launcher icons (512, 192, and the adaptive icon's 432 foreground and background), the store's 512 icon and
the home screen's cover picture, from the owner's artwork in tools/store/src/:
  icon_source.webp   the hurley and the sliotar on green, with its burst of light (the app icon)
  cover_source.webp  the hurler in green, striking at dusk (the home screen's programme cover)

The adaptive icon: Android crops the foreground to a circle or a rounded square about two-thirds of its size, so the
artwork goes in at 78% (the ball and the hurley's bas inside the cut) over a background of its own green.

Usage: python3 tools/store/make_icons.py   (needs Pillow)
"""
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "tools/store/src"


def source_icon():
    return Image.open(SRC / "icon_source.webp").convert("RGBA")


def edge_green(img):
    """The artwork's own background green: the mean of a band round its edge."""
    small = img.resize((64, 64), Image.LANCZOS).convert("RGB")
    px = small.load()
    cols = [px[x, y] for x in range(64) for y in range(64) if x < 4 or y < 4 or x > 59 or y > 59]
    return tuple(sum(c[i] for c in cols) // len(cols) for i in range(3))


def rounded(img, radius_k=0.18):
    n = img.size[0]
    mask = Image.new("L", (n * 4, n * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, n * 4 - 1, n * 4 - 1], radius=int(n * 4 * radius_k), fill=255)
    out = img.copy()
    out.putalpha(mask.resize((n, n), Image.LANCZOS))
    return out


def main():
    out = ROOT / "assets/icon"
    out.mkdir(parents=True, exist_ok=True)
    art = source_icon()
    green = edge_green(art)
    icon512 = art.resize((512, 512), Image.LANCZOS)
    icon512.save(out / "icon_512.png")
    art.resize((192, 192), Image.LANCZOS).save(out / "icon_192.png")
    # Adaptive: the artwork at 78% on its green, so the launcher's cut keeps the ball and the bas.
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    inner = rounded(art.resize((338, 338), Image.LANCZOS), 0.22)
    soft = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    soft.paste(inner, (47, 47), inner)
    # Feather the square's edge into the background green so no seam shows at any crop.
    alpha = soft.getchannel("A").filter(ImageFilter.GaussianBlur(6))
    soft.putalpha(alpha)
    fg.alpha_composite(soft)
    fg.save(out / "icon_fg_432.png")
    Image.new("RGBA", (432, 432), green + (255,)).save(out / "icon_bg_432.png")
    # The store icon: the full artwork, square (Play rounds it itself).
    store = ROOT / "store/graphics"
    store.mkdir(parents=True, exist_ok=True)
    # Play asks for a 32-bit PNG (with alpha) for the store icon.
    icon512.convert("RGBA").save(store / "icon-512.png")
    # The home screen's cover: the hurler, cut down for a phone (a 470-wide card at most, twice for sharpness).
    cover = Image.open(SRC / "cover_source.webp").convert("RGB")
    w = 720
    cover = cover.resize((w, round(cover.size[1] * w / cover.size[0])), Image.LANCZOS)
    (ROOT / "assets/art").mkdir(parents=True, exist_ok=True)
    cover.save(ROOT / "assets/art/cover.jpg", quality=86, optimize=True, progressive=True)
    for p in ["assets/icon/icon_512.png", "assets/icon/icon_192.png", "assets/icon/icon_fg_432.png",
              "assets/icon/icon_bg_432.png", "store/graphics/icon-512.png", "assets/art/cover.jpg"]:
        print("wrote", p, (ROOT / p).stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()

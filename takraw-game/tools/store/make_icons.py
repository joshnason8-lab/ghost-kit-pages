#!/usr/bin/env python3
"""Make the launcher icons (512, 192 and the adaptive icon's 432 foreground and background) and the store's 512
icon from the game's icon picture, store/graphics/icon_source.jpg (the ball, kicked by the net).

Usage: python3 tools/store/make_icons.py   (needs Pillow)
"""
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[2]
# The part of the picture that must show (the ball and the shoe), as fractions of its width and height.
KEEP = (0.1, 0.03, 0.9, 0.79)


def source():
    return Image.open(ROOT / "store/graphics/icon_source.jpg").convert("RGBA")


def rounded(img, n):
    img = img.resize((n, n), Image.LANCZOS)
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, n - 1, n - 1], radius=int(n * 0.22), fill=255)
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def adaptive_background(n):
    """The whole picture for the adaptive icon: a launcher shows only its middle two thirds (in a circle, a
    squircle...), so the picture is shrunk until the ball and the shoe fit there, over a blurred copy of itself."""
    src = source()
    img = src.resize((n, n), Image.LANCZOS).filter(ImageFilter.GaussianBlur(n * 0.04))
    window = n * 0.64
    w = KEEP[2] - KEEP[0]
    h = KEEP[3] - KEEP[1]
    s = int(window / max(w, h))
    pic = src.resize((s, s), Image.LANCZOS)
    # Its edges fade into the blurred copy.
    fade = Image.new("L", (s, s), 0)
    edge = int(s * 0.06)
    ImageDraw.Draw(fade).rectangle([edge, edge, s - edge, s - edge], fill=255)
    fade = fade.filter(ImageFilter.GaussianBlur(edge * 0.6))
    cx = (KEEP[0] + KEEP[2]) * 0.5 * s
    cy = (KEEP[1] + KEEP[3]) * 0.5 * s
    img.paste(pic, (int(n * 0.5 - cx), int(n * 0.5 - cy)), fade)
    return img


def main():
    out = ROOT / "assets/icon"
    out.mkdir(parents=True, exist_ok=True)
    for n in (512, 192):
        rounded(source(), n).save(out / f"icon_{n}.png")
    adaptive_background(432).save(out / "icon_bg_432.png")
    Image.new("RGBA", (432, 432), (0, 0, 0, 0)).save(out / "icon_fg_432.png")
    store = ROOT / "store/graphics"
    source().convert("RGB").resize((512, 512), Image.LANCZOS).save(store / "icon-512.png")
    print("icons written")


if __name__ == "__main__":
    main()

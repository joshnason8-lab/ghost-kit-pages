#!/usr/bin/env python3
"""The trailer's title and end cards and its captions, in the game's own look (the feature graphic's limestone,
ink, jade and the painted masthead; the game's fonts, Oswald and Noto Sans), at 1920 x 1080 and, for the vertical
cut, 1080 x 1920. Captions are transparent, to lay over the game's pictures.

Usage: python3 tools/media/cards.py OUT_DIR   (needs Pillow)
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
INK = (34, 26, 18)
JADE = (34, 110, 96)
RED = (0xB5, 0x37, 0x2E)
PAPER = (0xE9, 0xDC, 0xC3)
GOLD = (0xEC, 0xC7, 0x79)

CAPTIONS = {
    "ulama": "Ulama de cadera: the hip game of Sinaloa",
    "maya": "Pelota maya, as games begin in Yucatán today",
    "courts": "Four courts  ·  sixteen towns  ·  a town tournament",
    "team": "Play the whole team, or one player",
    "offline": "Plays offline  ·  no ads  ·  no data collected",
}


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(ROOT / "fonts" / name), size)


def centred(d: ImageDraw.ImageDraw, w: int, y: int, text: str, f, fill, bold: int = 0) -> None:
    box = d.textbbox((0, 0), text, font=f, stroke_width=bold)
    d.text(((w - (box[2] - box[0])) // 2 - box[0], y), text, font=f, fill=fill, stroke_width=bold, stroke_fill=fill)


def line_height(f) -> int:
    ascent, descent = f.getmetrics()
    return ascent + descent


def card(w: int, h: int, lines: list, masthead: str) -> Image.Image:
    im = Image.new("RGB", (w, h), PAPER)
    d = ImageDraw.Draw(im)
    band = int(h * 0.075) if w > h else int(h * 0.05)
    d.rectangle([0, 0, w, band], fill=RED)
    size = int(band * 0.42)
    small = font("NotoSans.ttf", size)
    while d.textlength(masthead, font=small) > w * 0.9:
        size -= 1
        small = font("NotoSans.ttf", size)
    centred(d, w, (band - line_height(small)) // 2, masthead, small, PAPER)
    d.rectangle([0, h - band // 3, w, h], fill=RED)
    scale = min(w, h) / 1080
    gap = int(10 * scale)
    fonts = []
    for text, kind in lines:
        f = font("Oswald.ttf", int((170 if kind.startswith("title") else 56) * scale))
        while d.textlength(text, font=f) > w * 0.88:
            f = font("Oswald.ttf", f.size - 2)
        fonts.append(f)
    total = sum(line_height(f) for f in fonts) + gap * (len(lines) - 1) + int(30 * scale)
    y = (h - total) // 2
    for (text, kind), f in zip(lines, fonts):
        if kind == "line":
            y += int(30 * scale)
        colour = JADE if kind == "title2" else INK
        centred(d, w, y, text, f, colour, bold=int(3 * scale) if kind.startswith("title") else 0)
        y += line_height(f) + gap
    return im


def caption(w: int, h: int, text: str, vertical: bool) -> Image.Image:
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    f = font("Oswald.ttf", 58 if not vertical else 54)
    box = d.textbbox((0, 0), text, font=f)
    tw, th = box[2] - box[0], box[3] - box[1]
    pad = 26
    y = int(h * (0.80 if not vertical else 0.70))
    x = (w - tw) // 2
    d.rounded_rectangle([x - pad * 2, y - pad, x + tw + pad * 2, y + th + pad * 1.6], radius=18, fill=(22, 16, 11, 200))
    d.text((x - box[0], y - box[1] + 4), text, font=f, fill=GOLD)
    return im


def main() -> int:
    out = pathlib.Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    mast = "ULAMA DE CADERA  ·  POK TA POK  ·  PELOTA MAYA"
    for tag, (w, h) in {"": (1920, 1080), "_v": (1080, 1920)}.items():
        card(w, h, [("POK TA POK", "title"), ("RIVALS", "title2"), ("The hip ballgame of Mexico, as it is played.", "line")],
             mast).save(out / f"title{tag}.png")
        card(w, h, [("POK TA POK", "title"), ("RIVALS", "title2"), ("Coming soon to Google Play", "line")],
             mast).save(out / f"end{tag}.png")
        for key, text in CAPTIONS.items():
            caption(w, h, text, tag == "_v").save(out / f"cap_{key}{tag}.png")
    print("cards in", out)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""The Google Play store's pictures, and the game page's, from the game's own renders.

  1. Render the store tour at 1920x1080 (it needs a display; xvfb works):
       xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1920x1080 \\
         res://tests/screenshots.tscn -- SHOTS store
  2. python3 tools/store_art.py SHOTS

Writes, in store/graphics/: icon-512.png (32-bit PNG), feature-1024x500.png (24-bit, no alpha, as Play asks) and
screenshots/01_raid.jpg to 08_languages.jpg (1920x1080; JPEG, which Play takes, at a fifth of the PNGs' size); and in
../kabaddi-raid/img/ (the game's web page): icon.png, feature.jpg and shot-1..4.jpg.
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "store" / "graphics"
WEB = ROOT.parent / "kabaddi-raid" / "img"
ORDER = ["store_1_raid", "store_2_stadium", "store_3_final", "store_4_menu", "store_5_season", "store_6_auction",
         "store_7_cup", "store_8_languages"]
WEB_SHOTS = ["store_1_raid", "store_6_auction", "store_5_season", "store_7_cup"]
INK = (243, 239, 230)
GOLD = (255, 210, 122)


def cover(im: Image.Image, w: int, h: int, focus_x: float = 0.5) -> Image.Image:
    """The picture scaled to fill w x h, cropped around focus_x across."""
    k = max(w / im.width, h / im.height)
    im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    x = round((im.width - w) * focus_x)
    y = (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))


def font(path: str, size: int, weight: int = 0) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(ROOT / "fonts" / path), size)
    if weight:
        try:
            f.set_variation_by_axes([weight])
        except Exception:
            pass
    return f


def rounded(im: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width - 1, im.height - 1), radius, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def feature(shots: pathlib.Path) -> Image.Image:
    src = shots / "store_feature_bg.png"
    bg = cover(Image.open(src if src.exists() else shots / "store_2_stadium.png").convert("RGB"), 1024, 500, 0.62)
    # Darker to the left, where the words go.
    shade = Image.new("L", (1024, 500))
    for x in range(1024):
        a = int(max(0.0, 1.0 - x / 640.0) ** 1.4 * 235)
        ImageDraw.Draw(shade).line([(x, 0), (x, 499)], fill=a)
    dark = Image.new("RGB", (1024, 500), (8, 18, 30))
    img = Image.composite(dark, bg, shade)
    icon = rounded(Image.open(ROOT / "assets" / "icon" / "icon_512.png").convert("RGB").resize((150, 150), Image.LANCZOS), 34)
    glow = Image.new("RGBA", (190, 190), (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle((12, 16, 178, 182), 40, fill=(0, 0, 0, 150))
    img.paste(glow.filter(ImageFilter.GaussianBlur(10)), (40, 52), glow.filter(ImageFilter.GaussianBlur(10)))
    img.paste(icon, (60, 60), icon)
    d = ImageDraw.Draw(img)
    d.text((58, 230), "KABADDI RAID", font=font("Teko.ttf", 118, 600), fill=INK)
    d.text((62, 352), "Raid. Touch. Return.", font=font("NotoSans.ttf", 34, 700), fill=GOLD)
    d.text((62, 404), "3D kabaddi  ·  League Season  ·  Nations Cup", font=font("NotoSans.ttf", 24, 500), fill=(205, 216, 230))
    return img


def main() -> int:
    shots = pathlib.Path(sys.argv[1])
    (OUT / "screenshots").mkdir(parents=True, exist_ok=True)
    WEB.mkdir(parents=True, exist_ok=True)
    icon = Image.open(ROOT / "assets" / "icon" / "icon_512.png").convert("RGBA")
    icon.save(OUT / "icon-512.png")
    icon.convert("RGB").resize((192, 192), Image.LANCZOS).save(WEB / "icon.png", optimize=True)
    f = feature(shots)
    f.save(OUT / "feature-1024x500.png", optimize=True)
    f.save(WEB / "feature.jpg", quality=86, optimize=True, progressive=True)
    n = 0
    for name in ORDER:
        p = shots / f"{name}.png"
        if not p.exists():
            print("missing", p)
            continue
        n += 1
        im = Image.open(p).convert("RGB")
        if im.size != (1920, 1080):
            im = cover(im, 1920, 1080)
        # Full colour detail (no chroma subsampling), so the menus' small words stay sharp.
        im.save(OUT / "screenshots" / f"{n:02d}_{name.split('_', 2)[2]}.jpg", quality=93, subsampling=0, optimize=True)
        if name in WEB_SHOTS:
            im.resize((1280, 720), Image.LANCZOS).save(WEB / f"shot-{WEB_SHOTS.index(name) + 1}.jpg", quality=82,
                                                        optimize=True, progressive=True)
    print(f"icon, feature graphic and {n} screenshots in {OUT}; web pictures in {WEB}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

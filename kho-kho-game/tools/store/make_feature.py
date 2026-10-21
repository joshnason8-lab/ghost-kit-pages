#!/usr/bin/env python3
"""The store's feature graphic (1024 x 500) and screenshots, from the game's own frames (tests/screenshots.tscn at
1920 x 1080): the village ground at dusk behind the title in the game's display face.

Usage: python3 tools/store/make_feature.py SHOTS_DIR [CLEAN_SHOTS_DIR]   (needs Pillow)
CLEAN_SHOTS_DIR: the same tour with "clean" (no HUD), for the feature graphic.
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
PICKS = [("01_home", "01_home"), ("05_match_maidan", "02_village_ground"), ("05_match_arena", "03_fast_rules_arena"),
         ("05_match_floodlit", "04_floodlit_stadium"), ("03_setup", "05_match_setup"), ("08_cup", "06_championship"),
         ("06_howto", "07_how_to_play")]


def main() -> int:
    shots = pathlib.Path(sys.argv[1])
    out = ROOT / "store" / "graphics" / "screenshots"
    out.mkdir(parents=True, exist_ok=True)
    for src, name in PICKS:
        Image.open(shots / f"{src}.png").convert("RGB").save(out / f"{name}.jpg", quality=88)
    clean = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else shots
    bg = Image.open(clean / "05_match_maidan.png").convert("RGB")
    w, h = bg.size
    crop = bg.crop((0, int(h * 0.16), w, int(h * 0.16) + int(w * 500 / 1024)))
    feat = crop.resize((1024, 500), Image.LANCZOS).convert("RGBA")
    shade = Image.new("RGBA", feat.size)
    d = ImageDraw.Draw(shade)
    for x in range(1024):
        a = int(220 * max(0.0, 1.0 - x / 640.0))
        d.line([(x, 0), (x, 500)], fill=(26, 18, 16, a))
    feat.alpha_composite(shade)
    d = ImageDraw.Draw(feat)
    title = ImageFont.truetype(str(ROOT / "fonts" / "Baloo2.ttf"), 112)
    sub = ImageFont.truetype(str(ROOT / "fonts" / "Baloo2.ttf"), 64)
    tag = ImageFont.truetype(str(ROOT / "fonts" / "NotoSans.ttf"), 30)
    d.text((48, 120), "Khamba Dash", font=title, fill=(247, 239, 226), stroke_width=4, stroke_fill=(20, 12, 10))
    d.text((52, 250), "खो-खो", font=sub, fill=(255, 176, 32), stroke_width=3, stroke_fill=(20, 12, 10))
    d.text((54, 345), "Sit. Kho. Chase.", font=tag, fill=(255, 217, 122))
    feat.convert("RGB").save(ROOT / "store" / "graphics" / "feature-1024x500.png")
    print("feature graphic and screenshots written")
    return 0


if __name__ == "__main__":
    sys.exit(main())

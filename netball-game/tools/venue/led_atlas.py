#!/usr/bin/env python3
"""Draws assets/venue/led_atlas.png: the courtside LED boards' messages (invented, no brands), one to a row of 64 px
across 1024, white on black in the game's display face, each centred in its row (the blank either side is the gap
between repeats as it scrolls). Row 0 is also the floor's wordmark. Prints each row's text span (u0 u1) for
Arena.LED_SPAN. Usage (from netball-game/): python3 tools/venue/led_atlas.py, then import (and
tools/venue/import_settings.py on a first import)."""
import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
ROWS = ["NETBALL UNLEASHED", "MAKE SOME NOISE", "GO TEAM GO", "EVERY PASS COUNTS", "DEFENCE! DEFENCE!",
        "WHAT A GAME", "GOAL!", "FEEL THE ENERGY"]
W, H = 1024, 64

img = Image.new("L", (W, H * len(ROWS)), 0)
d = ImageDraw.Draw(img)
font = ImageFont.truetype(str(ROOT / "fonts" / "BarlowCondensed-ExtraBold.ttf"), 70)
for i, text in enumerate(ROWS):
    x0, y0, x1, y1 = d.textbbox((0, 0), text, font=font)
    x = (W - (x1 - x0)) // 2 - x0
    y = i * H + (H - (y1 - y0)) // 2 - y0
    d.text((x, y), text, fill=255, font=font)
    print("%d %.4f %.4f %s" % (i, (x + x0) / W, (x + x1) / W, text))
img.save(ROOT / "assets" / "venue" / "led_atlas.png", optimize=True)

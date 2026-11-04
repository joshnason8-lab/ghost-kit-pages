#!/usr/bin/env python3
"""The jersey numbers' digits, 0-9 in a row (64 x 96 px each, white on clear), from the game's own Oswald (OFL,
fonts/Oswald.ttf) for the kit shader (game/hero_body.gd: each player's number on his back).
Usage: python3 tools/player/make_digits.py"""
from PIL import Image, ImageDraw, ImageFont

W, H = 64, 96
img = Image.new("LA", (W * 10, H), (255, 0))
font = ImageFont.truetype("fonts/Oswald.ttf", 92)
try:
    font.set_variation_by_name("Bold")
except Exception:
    pass
d = ImageDraw.Draw(img)
for i in range(10):
    s = str(i)
    l, t, r, b = d.textbbox((0, 0), s, font=font)
    d.text((i * W + (W - (r - l)) / 2 - l, (H - (b - t)) / 2 - t), s, font=font, fill=(255, 255))
img.save("assets/player/digits.png", optimize=True)
print("wrote assets/player/digits.png", img.size)

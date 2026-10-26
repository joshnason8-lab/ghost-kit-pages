#!/usr/bin/env python3
"""The city arena's floor decals (assets/crowd/floor_decals.png), as the Swedish league's arenas print sponsors on the
floor: a dark disc in the centre circle with the game's name, and dark panels with the game's own invented slogans
(the same as on its boards; no real sponsor). White on a dark grey that lets the floor through a little (alpha), drawn
in the game's own font. One sheet, 1024 x 512: the disc on the left half, two panels stacked on the right.

    python3 -I tools/venue/make_decals.py
"""
from PIL import Image, ImageDraw, ImageFont

W, H = 1024, 512
BG = (58, 62, 68, 215)
WHITE = (246, 247, 249, 255)
img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
bold = "fonts/BarlowCondensed-Bold.ttf"
semi = "fonts/BarlowCondensed-SemiBold.ttf"


def centred(box, text, font, fill=WHITE):
	"""The text in the middle of box, made smaller until it fits its width with a margin."""
	x0, y0, x1, y1 = box
	while d.textbbox((0, 0), text, font=font)[2] > (x1 - x0) * 0.88:
		font = ImageFont.truetype(font.path, font.size - 2)
	b = d.textbbox((0, 0), text, font=font)
	d.text(((x0 + x1 - (b[2] - b[0])) / 2 - b[0], (y0 + y1 - (b[3] - b[1])) / 2 - b[1]), text, font=font, fill=fill)


# The centre disc.
d.ellipse((8, 8, 504, 504), fill=BG)
d.ellipse((24, 24, 488, 488), outline=(246, 247, 249, 120), width=4)
centred((60, 150, 452, 270), "FLOORBALL", ImageFont.truetype(bold, 118))
centred((40, 262, 472, 360), "UNLEASHED", ImageFont.truetype(semi, 92))
# Two panels.
for i, (top, sub) in enumerate([("GO FLOORBALL", "PLAY FAIR · PLAY FAST"), ("#UNLEASHED", "THE HALL IS LOUD")]):
	y0 = 16 + i * 248
	d.rounded_rectangle((528, y0, 1016, y0 + 232), radius=10, fill=BG)
	centred((540, y0 + 18, 1004, y0 + 160), top, ImageFont.truetype(bold, 104))
	centred((540, y0 + 156, 1004, y0 + 216), sub, ImageFont.truetype(semi, 40), (246, 247, 249, 200))
img.save("assets/crowd/floor_decals.png")
print("wrote assets/crowd/floor_decals.png")

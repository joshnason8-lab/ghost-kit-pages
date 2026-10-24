"""Splits a player model's colour texture into what a team's colours repaint.

    python3 tools/models/kit_mask.py COLOUR.png OUT_COLOUR.jpg OUT_MASK.png [SIZE MASK_SIZE]

(The game's: SIZE 1024 and MASK_SIZE 512 for Low, man.jpg and man_kit.png; 2048 and 1024 for Medium and High,
man_2k.jpg and man_kit_1k.png, from the model's own 4096 px texture.)

The models come in a light blue shirt with navy panels and navy shorts. The mask says, for each texel, how much of it
is the shirt's light blue (red), the navy (green) and skin (blue); the game's player shader paints those in the team's
and the player's own colours, keeping the cloth's folds and the skin's shading (game/real_body.gd).
"""
import sys

import numpy as np
from PIL import Image, ImageFilter

SIZE = 1024
MASK = 512


def smooth(x, lo, hi):
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def main(src, out_colour, out_mask, size=None, mask_size=None):
    global SIZE, MASK
    SIZE = int(size) if size else SIZE
    MASK = int(mask_size) if mask_size else MASK
    im = Image.open(src).convert("RGB")
    if im.size != (SIZE, SIZE):
        im = im.resize((SIZE, SIZE), Image.LANCZOS)
    im.save(out_colour, quality=90)
    hsv = np.asarray(im.convert("HSV")).astype(np.float32) / 255.0
    h, s, v = hsv[..., 0] * 360.0, hsv[..., 1], hsv[..., 2]
    # Hue distance to a target, round the circle.
    def near(target, width):
        d = np.abs((h - target + 180.0) % 360.0 - 180.0)
        return 1.0 - smooth(d, width * 0.6, width)
    blue = near(205, 40) * smooth(s, 0.18, 0.3)
    light = blue * smooth(v, 0.55, 0.68)
    navy = near(222, 40) * smooth(s, 0.4, 0.55) * (1.0 - smooth(v, 0.6, 0.7))
    skin = near(25, 22) * smooth(s, 0.15, 0.25) * smooth(v, 0.35, 0.5) * (1.0 - smooth(s, 0.65, 0.8))
    m = np.stack([light, navy, skin], axis=-1)
    mask = Image.fromarray((np.clip(m, 0, 1) * 255).astype(np.uint8), "RGB")
    mask = mask.resize((MASK, MASK), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
    mask.save(out_mask, optimize=True)


if __name__ == "__main__":
    main(*sys.argv[1:6])

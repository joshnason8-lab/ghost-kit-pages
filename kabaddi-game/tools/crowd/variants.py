#!/usr/bin/env python3
"""Make the crowd's sheet for Medium and High (assets/crowd/crowd_atlas_hi*): the eight people of render_crowd.gd's
sheet and eight more, the same people in other colours: the Sikh man's turban saffron and maroon, the salwar kameez
magenta and mustard, the saree green and royal blue, the girl's frock yellow and sky blue. Low keeps the eight-person
sheet; these are only loaded on Medium and High (game/arena.gd).

Each garment is found by its colour: the texels near its own hue and saturated enough, never the skin's hue. Its hue is
turned to the new one, keeping its shading. The top masks (the fans' tops the game recolours) are copied; none of the
recoloured people wear one.

    python3 tools/crowd/variants.py            # reads and writes assets/crowd
"""
import colorsys
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CROWD = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "crowd"))

# person's file -> its garment's hue (degrees) and how far round it to take, and the variants: [name, new hue,
# saturation and value multipliers]
VARIANTS = {
    "crowd_03_sikh_man_rigged.glb": (220, 25, 0.25, [["saffron", 30, 1.35, 1.6], ["maroon", 350, 1.0, 0.85]]),
    "crowd_05_woman_salwar_rigged.glb": (185, 25, 0.25, [["magenta", 320, 1.0, 1.0], ["mustard", 45, 1.05, 1.15]]),
    "crowd_06_woman_saree_rigged.glb": (345, 18, 0.35, [["green", 140, 0.9, 0.95], ["royal_blue", 225, 1.0, 1.0]]),
    "crowd_10_girl_rigged.glb": (338, 18, 0.18, [["yellow", 52, 1.3, 1.05], ["sky_blue", 205, 1.1, 1.0]]),
}


def rgb_to_hsv(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(-1), a.min(-1)
    d = mx - mn + 1e-9
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60.0
    s = np.where(mx > 0, (mx - mn) / (mx + 1e-9), 0)
    return h, s, mx


def hsv_to_rgb(h, s, v):
    h = (h % 360) / 60.0
    c = v * s
    x = c * (1 - np.abs(h % 2 - 1))
    z = np.zeros_like(h)
    i = np.floor(h).astype(int) % 6
    rgb = np.select([i[..., None] == k for k in range(6)],
                    [np.stack(t, -1) for t in [(c, x, z), (x, c, z), (z, c, x), (z, x, c), (x, z, c), (c, z, x)]])
    return rgb + (v - c)[..., None]


def recolour(cell, hue, width, min_sat, new_hue, sat_k, val_k):
    rgb = cell[..., :3] / 255.0
    h, s, v = rgb_to_hsv(rgb)
    near = np.abs((h - hue + 180) % 360 - 180)
    skin = (h > 0) & (h < 45) & (s > 0.15) & (s < 0.75)
    w = np.clip((width - near) / (width * 0.3), 0, 1) * np.clip((s - min_sat) / 0.1, 0, 1) * (cell[..., 3] > 0)
    w = w * ~(skin & (np.abs((hue - 22 + 180) % 360 - 180) > 30))
    out = hsv_to_rgb(np.full_like(h, new_hue), np.clip(s * sat_k, 0, 1), np.clip(v * val_k, 0, 1))
    res = cell.astype(np.float64).copy()
    res[..., :3] = (rgb * (1 - w[..., None]) + out * w[..., None]) * 255.0
    return np.clip(res, 0, 255).astype(np.uint8), float(w[cell[..., 3] > 0].mean())


def main():
    info = json.load(open(os.path.join(CROWD, "crowd_atlas.json")))
    cw, ch = info["cell"]
    people = info["people"]
    hi = dict(info)
    hi["people"] = [dict(p, base=i) for i, p in enumerate(people)]
    sheets = {}
    for side in ["", "_back"]:
        sheets[side] = (np.asarray(Image.open(os.path.join(CROWD, "crowd_atlas%s.webp" % side)).convert("RGBA")),
                        np.asarray(Image.open(os.path.join(CROWD, "crowd_mask%s.png" % side)).convert("L")))
    cols = {s: [sheets[s][0]] for s in sheets}
    masks = {s: [sheets[s][1]] for s in sheets}
    for i, p in enumerate(people):
        if p["file"] not in VARIANTS:
            continue
        hue, width, min_sat, vs = VARIANTS[p["file"]]
        for name, nh, sk, vk in vs:
            for side in sheets:
                col = sheets[side][0][:, i * cw:(i + 1) * cw]
                new, share = recolour(col, hue, width, min_sat, nh, sk, vk)
                cols[side].append(new)
                masks[side].append(sheets[side][1][:, i * cw:(i + 1) * cw])
                if side == "":
                    print("%s %s: %.0f%% of the figure recoloured" % (p["file"][:-11], name, share * 100))
            hi["people"].append(dict(p, file=p["file"].replace("_rigged.glb", "_" + name), base=i))
    assert len(hi["people"]) <= 16, "the game's crowd shader takes 16 people"
    for side in sheets:
        Image.fromarray(np.concatenate(cols[side], axis=1)).save(
            os.path.join(CROWD, "crowd_atlas_hi%s.webp" % side), lossless=True, method=6)
        Image.fromarray(np.concatenate(masks[side], axis=1)).save(
            os.path.join(CROWD, "crowd_mask_hi%s.png" % side), optimize=True)
    json.dump(hi, open(os.path.join(CROWD, "crowd_atlas_hi.json"), "w"), indent=1)
    print("wrote crowd_atlas_hi: %d people" % len(hi["people"]))


if __name__ == "__main__":
    sys.exit(main())

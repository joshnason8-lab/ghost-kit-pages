#!/usr/bin/env python3
"""The crowd's sheet for Medium and High (assets/venue/crowd_hd.png): 32 different people, head and shoulders and a
shirt, drawn antialiased at 64 x 128 each. Low keeps the 8-figure sheet game/crowd.gd paints in code.

The people vary in skin tone (eight), hair (colour, and short, cropped, long, a bun, a ponytail, braids, an afro,
none), build (shoulders, head, how tall they sit), and what they wear: beanies, caps and sun hats, team scarves,
glasses, the odd arm up waving. Rows of the sheet (2048 x 512):
  0-127    the 32 from the front          256-383  their mask from the front
  128-255  the same from behind           384-511  their mask from behind
The mask says what the shader tints: red, the shirt (each spectator's own colour); green, the scarf, hat or flag in
their team's colour (Crowd.build gives each a second colour). Under the mask the colour rows hold a grey whose
light and dark shades the tint. Run from netball-game/:  python3 -I tools/art/make_crowd.py   (needs Pillow, numpy)
"""
import pathlib

import numpy as np
from PIL import Image

OUT = pathlib.Path(__file__).resolve().parents[2] / "assets" / "venue" / "crowd_hd.png"
FIGS = 32
W, H = 64, 128
S = 4                      # drawn at 4x, then averaged down: soft edges
rng = np.random.default_rng(2026)

SKINS = ["f1c9a5", "e0ac85", "c98a5a", "b07448", "9a6440", "7d4f30", "5e3a22", "45291a"]
HAIRS = ["15100c", "2b1d14", "3d2a1c", "6a4a2c", "a07a48", "d2b07a", "8a8a88", "c9c9c4", "7a3a1c"]
STYLES = ["short", "crop", "long", "bun", "ponytail", "braids", "afro", "bald"]


def hexc(h):
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


class Fig:
    """One person, drawn into supersampled layers: colour (RGB), coverage, shirt and accent weights."""

    def __init__(self):
        self.rgb = np.zeros((H * S, W * S, 3))
        self.a = np.zeros((H * S, W * S))
        self.shirt = np.zeros((H * S, W * S))
        self.acc = np.zeros((H * S, W * S))
        ys, xs = np.mgrid[0:H * S, 0:W * S]
        self.u = (xs + 0.5) / (W * S) - 0.5
        self.v = (ys + 0.5) / (H * S)

    def put(self, m, col, kind="paint"):
        """Paint mask m: col an RGB (paint) or a grey shade array/float (shirt, accent: tinted in the game)."""
        if np.isscalar(col) or (isinstance(col, np.ndarray) and col.ndim == 2):
            g = np.broadcast_to(col, m.shape)
            c = np.stack([g, g, g], axis=-1)
        else:
            c = np.broadcast_to(col, self.rgb.shape)
        self.rgb[m] = c[m]
        self.a[m] = 1.0
        self.shirt[m] = 1.0 if kind == "shirt" else 0.0
        self.acc[m] = 1.0 if kind == "accent" else 0.0

    def ell(self, cx, cy, rx, ry):
        return ((self.u - cx) / rx) ** 2 + ((self.v - cy) / ry) ** 2 < 1.0

    def box(self, x0, x1, y0, y1):
        return (self.u >= x0) & (self.u <= x1) & (self.v >= y0) & (self.v <= y1)

    def down(self):
        def avg(x):
            return x.reshape(H, S, W, S, *x.shape[2:]).mean(axis=(1, 3))
        a = avg(self.a)
        rgb = avg(self.rgb * self.a[..., None]) / np.maximum(a, 1e-6)[..., None]
        return rgb, a, avg(self.shirt * self.a) / np.maximum(a, 1e-6), avg(self.acc * self.a) / np.maximum(a, 1e-6)


def person(i, back):
    r = np.random.default_rng(1000 + i)      # the same person from the front and from behind
    f = Fig()
    u, v = f.u, f.v
    skin = hexc(SKINS[i % len(SKINS)])
    style = STYLES[(i * 3 + i // 8) % len(STYLES)]
    hair = hexc(HAIRS[r.integers(0, len(HAIRS))]) if style != "bald" else skin
    if style == "afro":
        hair = hexc(["15100c", "2b1d14", "3d2a1c"][i % 3])
    build = r.uniform(-1, 1)                  # narrow .. broad
    lift = r.uniform(-0.035, 0.035)           # sits a little lower or higher
    sh = 0.47 + lift + r.uniform(-0.01, 0.02)  # shoulder line
    bw = 0.37 + 0.07 * build                  # half the shoulders' width
    hy = 0.3 + lift
    rx = 0.17 + 0.025 * r.uniform(-1, 1)
    ry = 0.135 + 0.015 * r.uniform(-1, 1)
    hat = ["none", "none", "none", "beanie", "cap", "sunhat", "none", "beanie"][r.integers(0, 8)]
    if style in ("afro", "bun") and hat != "none":
        hat = "none"
    scarf = r.random() < 0.4
    glasses = r.random() < 0.2 and not back
    wave = i % 9 == 4                         # an arm up
    neckline = r.integers(0, 3)               # round, v, collar
    # Lit from above and the left: the shirt's grey.
    # (Kept near white, as Low's sheet is: the tint is multiplied by it, and the game squares it into light.)
    light = 1.0 - 0.06 * np.clip((v - sh) / 0.5, 0, 1) - 0.03 * (u + 0.5)
    # Long hair, braids and a ponytail fall behind the shoulders (drawn first, the body over them from the front).
    if style in ("long", "braids") and not back:
        f.put(f.box(-rx * 1.12, rx * 1.12, hy, hy + 0.27) & (np.abs(u) > rx * 0.55), hair * 0.85)
    # The body: shoulders rounded into the arms, a little narrower to the seat.
    taper = bw - 0.04 * np.clip((v - sh - 0.1) / 0.4, 0, 1)
    shoulder_round = np.clip(sh + 0.085 - v, 0, None) * 2.4
    body = (v > sh) & (np.abs(u) < taper - shoulder_round)
    f.put(body, light, "shirt")
    arms = body & (np.abs(u) > bw - 0.11)
    f.put(arms, light * 0.9, "shirt")
    # The arm creases.
    f.put(body & (np.abs(np.abs(u) - (bw - 0.11)) < 0.008) & (v > sh + 0.06), light * 0.78, "shirt")
    # The neck, and the neckline.
    neck = f.box(-0.065, 0.065, hy + ry * 0.6, sh + 0.04)
    f.put(neck, skin * (0.86 if not back else 0.8))
    if not back:
        if neckline == 1:
            f.put((v > sh - 0.005) & (v < sh + 0.07) & (np.abs(u) < 0.07 - (v - sh)), skin * 0.9)
        elif neckline == 2:
            f.put((np.abs(v - sh - 0.01) < 0.012) & (np.abs(u) < 0.11), light * 1.03, "shirt")
            f.put((np.abs(v - sh - 0.01) < 0.012) & (np.abs(u) < 0.11) & (np.abs(u) > 0.095), light * 0.75, "shirt")
    # An arm up, waving (a sleeve and a hand above the head on one side).
    if wave:
        side = 1 if i % 2 else -1
        ax = side * (bw - 0.05)
        f.put(f.box(ax - 0.045, ax + 0.045, 0.17, sh + 0.08), light * 0.92, "shirt")
        f.put(f.ell(ax, 0.15, 0.06, 0.04), skin)
    # The head.
    head = f.ell(0, hy, rx, ry)
    f.put(head, skin)
    # Ears.
    f.put(f.ell(-rx * 0.98, hy + 0.01, 0.03, 0.03) | f.ell(rx * 0.98, hy + 0.01, 0.03, 0.03), skin * 0.9)
    f.put(head, skin)
    if not back:
        # A face, just: brows, eyes, the shade under the nose, a mouth.
        for s in (-1, 1):
            f.put(f.ell(s * rx * 0.38, hy + 0.0, 0.022, 0.012), np.array([0.12, 0.09, 0.08]))
            f.put(f.ell(s * rx * 0.38, hy - 0.03, 0.04, 0.007), hair * 0.9 if style != "bald" else skin * 0.75)
        f.put(f.ell(0, hy + 0.05, 0.02, 0.012), skin * 0.82)
        f.put(f.ell(0, hy + 0.083, 0.05, 0.008), skin * 0.7)
        if glasses:
            for s in (-1, 1):
                ring = f.ell(s * rx * 0.38, hy, 0.055, 0.03) & ~f.ell(s * rx * 0.38, hy, 0.04, 0.02)
                f.put(ring, np.array([0.08, 0.08, 0.1]))
            f.put(f.box(-0.02, 0.02, hy - 0.004, hy + 0.004), np.array([0.08, 0.08, 0.1]))
    # Hair.
    top = hy - ry
    if style == "afro":
        puff = f.ell(0, hy - ry * 0.35, rx * 1.45, ry * 1.2)
        if back:
            f.put(puff, hair)
        else:
            f.put(puff & ~(head & (v > hy - ry * 0.25)), hair)
    elif style == "bald":
        if back:
            f.put(head & (v > hy + ry * 0.1), skin * 0.85)
    else:
        cap = head & (v < hy - ry * (0.15 if style != "crop" else 0.4))
        sides = head & (np.abs(u) > rx * 0.72) & (v < hy + ry * 0.2)
        if back:
            # From behind: hair to the nape (cropped and short show skin below).
            f.put(head & (v < hy + ry * (0.95 if style in ("long", "braids", "bun", "ponytail") else 0.5)), hair)
            if style in ("long", "braids"):
                f.put(f.box(-rx * 1.05, rx * 1.05, hy, hy + 0.27), hair * 0.92)
                if style == "braids":
                    for k in range(-3, 4):
                        f.put(f.box(k * rx * 0.28 - 0.01, k * rx * 0.28 + 0.01, hy - ry, hy + 0.27), hair * 0.7)
            if style == "ponytail":
                f.put(f.ell(0, hy + ry * 1.25, 0.05, 0.11), hair * 0.9)
        else:
            f.put(cap, hair)
            if style not in ("crop",):
                f.put(sides, hair)
            if style in ("long", "braids"):
                f.put(head & (np.abs(u) > rx * 0.62) & (v < hy + ry * 0.9), hair)
        if style == "bun":
            f.put(f.ell(0, top - 0.02, 0.07, 0.045), hair * 0.95)
        if style == "ponytail" and not back:
            f.put(f.ell(rx * 0.9, hy + ry * 0.6, 0.035, 0.08), hair * 0.85)
    # Hats, in the team's colour (beanie, cap) or straw (sun hat).
    if hat == "beanie":
        dome = f.ell(0, hy - ry * 0.25, rx * 1.06, ry * 0.95) & (v < hy - ry * 0.15)
        f.put(dome, 1.0, "accent")
        f.put(dome & (v > hy - ry * 0.42), 1.0, "paint")    # the turned-up band: white
        f.put(dome & (v > hy - ry * 0.42), np.array([0.92, 0.92, 0.9]))
        f.put(f.ell(0, hy - ry * 1.2, 0.04, 0.025), np.array([0.95, 0.95, 0.93]))   # the bobble
    elif hat == "cap":
        crown = f.ell(0, hy - ry * 0.35, rx * 1.03, ry * 0.85) & (v < hy - ry * 0.2)
        f.put(crown, 1.0, "accent")
        if not back:
            f.put(f.ell(0, hy - ry * 0.22, rx * 1.15, 0.022) & (v > hy - ry * 0.3), 0.75, "accent")
        else:
            f.put(f.box(-0.03, 0.03, hy - ry * 0.3, hy - ry * 0.18), np.array([0.85, 0.85, 0.85]))
    elif hat == "sunhat":
        straw = hexc("d8c08a")
        f.put(f.ell(0, hy - ry * 0.45, rx * 0.95, ry * 0.7) & (v < hy - ry * 0.3), straw)
        f.put(f.ell(0, hy - ry * 0.3, rx * 1.7, 0.03), straw * 0.92)
        f.put(f.ell(0, hy - ry * 0.42, rx * 0.96, 0.016), np.array([0.25, 0.22, 0.2]))
    # A team scarf: round the neck, one end hanging, striped with white.
    if scarf:
        band = f.box(-0.15, 0.15, sh - 0.025, sh + 0.045) & (np.abs(u) < 0.15 - np.clip(sh - v, 0, 1))
        side = -1 if i % 2 else 1
        tail = f.box(side * 0.03, side * 0.03 + side * 0.09, sh, sh + 0.3) if not back else f.box(-0.0, 0.0, 0, 0)
        if side < 0:
            tail = f.box(-0.12, -0.03, sh, sh + 0.3) if not back else tail
        sc = band | tail
        stripe = (np.floor((v - sh) / 0.035) % 3 == 1) & tail
        f.put(sc & ~stripe, 1.0 - 0.06 * np.clip((v - sh) / 0.3, 0, 1), "accent")
        f.put(stripe, np.array([0.95, 0.95, 0.93]))
        f.put(tail & (v > sh + 0.28), np.array([0.95, 0.95, 0.93]))   # the fringe
    return f.down()


def main():
    sheet = np.zeros((H * 4, W * FIGS, 4))
    for i in range(FIGS):
        for back in (0, 1):
            rgb, a, sm, am = person(i, back)
            x0 = i * W
            y0 = back * H
            sheet[y0:y0 + H, x0:x0 + W, :3] = rgb
            sheet[y0:y0 + H, x0:x0 + W, 3] = a
            sheet[2 * H + y0:2 * H + y0 + H, x0:x0 + W, 0] = sm * (a > 0)
            sheet[2 * H + y0:2 * H + y0 + H, x0:x0 + W, 1] = am * (a > 0)
            sheet[2 * H + y0:2 * H + y0 + H, x0:x0 + W, 3] = 1.0
    img = Image.fromarray(np.clip(sheet * 255 + 0.5, 0, 255).astype(np.uint8), "RGBA")
    img.save(OUT, optimize=True)
    print("wrote", OUT, img.size, OUT.stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()

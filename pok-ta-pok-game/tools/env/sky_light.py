#!/usr/bin/env python3
"""The light of each sky the game uses, read once from its HDR (the shared assets' `*_light_1k.hdr`), so the game
ships only the 2K panorama: where the sun is in the panorama (u, v and its elevation), the colour and strength of the
light from the sky's upper half (the ambient light), and the colour at the horizon (the fog).
Writes assets/env/sky/skies.json.

Usage: python3 tools/env/sky_light.py <shared-assets/skies>   (needs numpy)
"""
import json
import math
import pathlib
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
SKIES = ["qwantani_dusk_2_puresky", "qwantani_noon_puresky", "kloofendal_48d_partly_cloudy_puresky", "kloppenheim_02_puresky"]


def read_hdr(path):
    """A Radiance .hdr (RGBE, run-length encoded scanlines) as a float32 array (h, w, 3)."""
    data = path.read_bytes()
    pos = 0
    while True:
        end = data.index(b"\n", pos)
        line = data[pos:end]
        pos = end + 1
        if line.startswith(b"-Y") or line.startswith(b"+Y"):
            parts = line.split()
            h, w = int(parts[1]), int(parts[3])
            break
    img = np.zeros((h, w, 4), np.uint8)
    for y in range(h):
        if data[pos] == 2 and data[pos + 1] == 2:
            pos += 4
            for c in range(4):
                x = 0
                while x < w:
                    n = data[pos]
                    pos += 1
                    if n > 128:
                        n -= 128
                        img[y, x:x + n, c] = data[pos]
                        pos += 1
                    else:
                        img[y, x:x + n, c] = np.frombuffer(data[pos:pos + n], np.uint8)
                        pos += n
                    x += n
        else:
            img[y] = np.frombuffer(data[pos:pos + w * 4], np.uint8).reshape(w, 4)
            pos += w * 4
    e = img[..., 3].astype(np.int32)
    scale = np.where(e > 0, np.ldexp(1.0, e - 136), 0.0)
    return img[..., :3].astype(np.float32) * scale[..., None]


def main():
    src = pathlib.Path(sys.argv[1])
    out = {}
    for name in SKIES:
        hdr = read_hdr(src / f"{name}_light_1k.hdr")
        h, w, _ = hdr.shape
        lum = hdr @ np.array([0.2126, 0.7152, 0.0722], np.float32)
        # The sun: the brightest spot above the horizon (blurred a little, so one hot pixel does not count).
        upper = lum[: h // 2]
        k = 9
        pad = np.pad(upper, k // 2, mode="edge")
        blur = sum(pad[i:i + upper.shape[0], j:j + upper.shape[1]] for i in range(k) for j in range(k)) / (k * k)
        sy, sx = np.unravel_index(int(np.argmax(blur)), blur.shape)
        u, v = (sx + 0.5) / w, (sy + 0.5) / h
        elev = 90.0 - v * 180.0
        # The sky's light: the upper half, weighted by the solid angle of each row (cos of the latitude).
        lat = (0.5 - (np.arange(h // 2) + 0.5) / h) * math.pi
        wts = np.cos(lat)[:, None]
        amb = (hdr[: h // 2] * wts[..., None]).sum((0, 1)) / (wts.sum() * w)
        strength = float(amb.max())
        hor = hdr[int(h * 0.47):int(h * 0.5)].mean((0, 1))
        sun_col = hdr[max(0, sy - 2):sy + 3, max(0, sx - 2):sx + 3].mean((0, 1))
        out[name] = {
            "sun_u": round(float(u), 4), "sun_v": round(float(v), 4), "sun_elevation": round(float(elev), 1),
            "sun_colour": [round(float(c), 3) for c in sun_col / max(sun_col.max(), 1e-6)],
            "ambient": [round(float(c), 3) for c in amb / max(strength, 1e-6)], "ambient_strength": round(strength, 3),
            "horizon": [round(float(c), 3) for c in hor / max(hor.max(), 1e-6)],
        }
        print(name, out[name])
    dst = ROOT / "assets/env/sky/skies.json"
    dst.write_text(json.dumps(out, indent=1))
    print("wrote", dst.relative_to(ROOT))


if __name__ == "__main__":
    main()

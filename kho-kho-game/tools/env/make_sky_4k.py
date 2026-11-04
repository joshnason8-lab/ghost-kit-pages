#!/usr/bin/env python3
"""The skies at 4k for High graphics: each Poly Haven sky's tonemapped photograph (CC0, 8192 x 4096), brought down to
4096 x 2048 and its colours matched, channel by channel (a histogram match), to the 2k sky the game already has, so
High shows the same sky only sharper.

    python3 tools/env/make_sky_4k.py PHOTO_DIR assets/env/skies

PHOTO_DIR holds <name>.jpg from https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Tonemapped%20JPG/<name>.jpg
(not kept in the repository).
"""
import os
import sys

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None
SKIES = ["qwantani_dusk_2_puresky", "qwantani_noon_puresky", "kloppenheim_02_puresky"]


def main(src, out):
    for n in SKIES:
        t = Image.open(os.path.join(src, n + ".jpg")).convert("RGB").resize((4096, 2048), Image.LANCZOS)
        e = np.asarray(Image.open(os.path.join(out, n + "_sky_2k.jpg")).convert("RGB")).astype(float)
        T = np.asarray(t).astype(float)
        small = np.asarray(t.resize((2048, 1024), Image.LANCZOS)).astype(float)
        q = np.linspace(0, 1, 256)
        res = np.empty_like(T)
        for c in range(3):
            lut = np.interp(np.arange(256), np.quantile(small[..., c].ravel(), q), np.quantile(e[..., c].ravel(), q))
            res[..., c] = lut[T[..., c].astype(int)]
        o = Image.fromarray(res.clip(0, 255).astype(np.uint8))
        o.save(os.path.join(out, n + "_sky_4k.jpg"), quality=90)
        chk = np.asarray(o.resize((2048, 1024), Image.LANCZOS)).astype(float)
        print("%s: 4096 x 2048, %.1f from the 2k on average" % (n, np.abs(chk - e).mean()))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

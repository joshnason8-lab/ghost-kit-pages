#!/usr/bin/env python3
"""The officials' textures for phones: each Meshy model's 2048 atlas down to 512 (the officials are small on the
screen), or to the size given (1024 for Medium and High: <who>_hd.jpg). On the referee's black kit, the generator painted a sportswear maker's marks: any pale speck inside a dark
patch is filled with the dark around it, so the kit is plain (the game shows no brands).

Usage: python3 people_textures.py <texture.jpg> <out.jpg> [clean|plain] [size]   (needs Pillow and numpy)
"""
import sys

import numpy as np
from PIL import Image, ImageFilter


def main():
    src, out = sys.argv[1], sys.argv[2]
    img = Image.open(src).convert("RGB")
    if len(sys.argv) > 3 and sys.argv[3] == "clean":
        a = np.asarray(img).astype(np.float32) / 255.0
        lum = a @ np.array([0.2126, 0.7152, 0.0722], np.float32)
        # The dark around each pixel: a wide blur of the picture with its pale pixels left out.
        dark = (lum < 0.25).astype(np.float32)
        blur = lambda x: np.asarray(Image.fromarray((x * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14))).astype(np.float32) / 255.0
        share = blur(dark)
        fill = np.stack([blur(a[..., i] * dark) for i in range(3)], -1) / np.maximum(share[..., None], 1e-3)
        # Only white marks (the grey socks and boots meet the black kit too): skin is a pale colour as well, and the atlas puts small pieces of skin right
        # against the black kit, so a looser test (chroma under 0.25) blacked out the edge of every piece of skin,
        # which showed as dark cracks across the referee's face, arms and legs.
        speck = (lum > 0.6) & (share > 0.35) & ((a.max(-1) - a.min(-1)) < 0.09)
        speck = np.asarray(Image.fromarray(speck.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(5))) > 0
        # Never near skin: where a piece of skin meets the kit its edge blends to grey, which passes the test above.
        skin = (lum > 0.3) & ((a[..., 0] - a[..., 2]) > 0.12)
        near_skin = np.asarray(Image.fromarray(skin.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(9))) > 0
        speck &= ~near_skin
        a[speck] = fill[speck]
        print("cleaned", int(speck.sum()), "pixels")
        img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    size = int(sys.argv[4]) if len(sys.argv) > 4 else 512
    img.resize((size, size), Image.LANCZOS).save(out, quality=88, optimize=True)
    print("wrote", out)


if __name__ == "__main__":
    main()

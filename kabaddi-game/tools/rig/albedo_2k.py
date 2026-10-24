#!/usr/bin/env python3
"""Make each textured body's 2K albedo (assets/characters/bodies/<body>_albedo_2k.webp), which Medium and High load in
place of the 1K one (game/rigged_body.gd); Low never loads it.

The 1K albedo is kit_texture.py's work on the model's own 2K or 4K texture: the logos and numbers painted out and the
islands padded. The 2K one is that texture again at 2048 px, its detail (faces, skin, the kit's folds) kept, with the
1K albedo's work brought over where it differs from the texture: wherever the 1K albedo is not just the texture made
smaller (painted out, padded), the 1K albedo is used, enlarged. The kit map stays at 1K: it marks colours, not detail.

    python3 tools/rig/albedo_2k.py            # every body in bodies.json with a texture
"""
import io
import json
import os
import struct
import sys

import cv2
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
BODIES = os.path.join(ROOT, "assets", "characters", "bodies")
MESHY = os.path.join(ROOT, "assets", "meshy")
SIZE = 2048


def base_color_image(path):
    """The base colour texture of the first material in a GLB (as kit_texture.py reads it)."""
    b = open(path, "rb").read()
    jlen = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jlen])
    blen = struct.unpack("<I", b[20 + jlen:24 + jlen])[0]
    data = b[28 + jlen:28 + jlen + blen]
    tex = j["textures"][j["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    src = tex.get("source", tex.get("extensions", {}).get("EXT_texture_webp", {}).get("source"))
    bv = j["bufferViews"][j["images"][src]["bufferView"]]
    raw = data[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
    return np.asarray(Image.open(io.BytesIO(raw)).convert("RGB")).astype(np.float32)


def main():
    for e in json.load(open(os.path.join(BODIES, "bodies.json"))):
        name = e["file"][:-4]
        small = os.path.join(BODIES, name + "_albedo.webp")
        src = os.path.join(MESHY, e.get("source", ""))
        if not os.path.exists(small) or not os.path.exists(src):
            print("skip", name)
            continue
        tex = base_color_image(src)
        if tex.shape[0] < SIZE:
            print("skip", name, "(its texture is %d px)" % tex.shape[0])
            continue
        big = cv2.resize(tex, (SIZE, SIZE), interpolation=cv2.INTER_AREA) if tex.shape[0] > SIZE else tex
        clean = np.asarray(Image.open(small).convert("RGB")).astype(np.float32)
        n = clean.shape[0]
        down = cv2.resize(big, (n, n), interpolation=cv2.INTER_AREA)
        # Where the 1K albedo is the texture made smaller, and where it was worked on.
        diff = cv2.GaussianBlur(np.abs(down - clean).max(axis=2), (3, 3), 0)
        worked = cv2.dilate((diff > 14).astype(np.uint8), np.ones((3, 3), np.uint8)).astype(np.float32)
        m = cv2.resize(cv2.GaussianBlur(worked, (3, 3), 0), (SIZE, SIZE), interpolation=cv2.INTER_LINEAR)[..., None]
        up = cv2.resize(clean, (SIZE, SIZE), interpolation=cv2.INTER_CUBIC)
        out = big * (1.0 - m) + up * m
        path = os.path.join(BODIES, name + "_albedo_2k.webp")
        Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(path, quality=90, method=6)
        print("wrote %s: %d KB, %.0f%% from the model's own %d px texture" % (
            os.path.basename(path), os.path.getsize(path) // 1024, 100.0 * (1.0 - m.mean()), tex.shape[0]))


if __name__ == "__main__":
    sys.exit(main())

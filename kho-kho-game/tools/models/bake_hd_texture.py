#!/usr/bin/env python3
"""A sharper texture for the player model on Medium and High graphics: the owner's high-detail GLB's 4096 px texture
baked again, at 2048 px, onto the UVs of the light model already in assets/models/player.glb (`player_lod0`, the mesh
Medium and High draw). The model itself is not rebuilt, so its meshes, and everything Low draws, stay as they are.

    python3 tools/models/bake_hd_texture.py SOURCE.glb assets/models/player.glb assets/models/player_lod0_2k.png

Same baker as tools/models/build_player.py (each texel takes the colour of the nearest point on the original surface,
the kit's classes in its alpha). The source GLB is the owner's and is not kept in the repository.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_player import accessor, bake, read_glb   # noqa: E402

SIZE = 2048


def main(src, model, dst):
    j, b = read_glb(src)
    prim = j["meshes"][0]["primitives"][0]
    P0 = accessor(j, b, prim["attributes"]["POSITION"]).astype(np.float64)
    UV0 = accessor(j, b, prim["attributes"]["TEXCOORD_0"]).astype(np.float64)
    F0 = accessor(j, b, prim["indices"]).reshape(-1, 3).astype(np.int64)
    img = j["images"][0]
    bv = j["bufferViews"][img["bufferView"]]
    import io
    tex = np.asarray(Image.open(io.BytesIO(b[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]])).convert("RGB")).astype(np.float32)
    mj, mb = read_glb(model)
    mesh = next(m for m in mj["meshes"] if m.get("name") == "player_lod0" or any(
        mj["materials"][p.get("material", 0)].get("name") == "player_lod0" for p in m["primitives"]))
    p = mesh["primitives"][0]
    Pn = accessor(mj, mb, p["attributes"]["POSITION"]).astype(np.float64)
    UVn = accessor(mj, mb, p["attributes"]["TEXCOORD_0"]).astype(np.float64)
    Fn = accessor(mj, mb, p["indices"]).reshape(-1, 3).astype(np.int64)
    print("source %d triangles, %dx%d; player_lod0 %d triangles" % (len(F0), tex.shape[1], tex.shape[0], len(Fn)))
    im = bake(Pn, Fn, UVn, SIZE, P0, F0, UV0, tex)
    im.save(dst, "PNG", optimize=True)
    print("wrote %s (%d KB)" % (dst, os.path.getsize(dst) // 1024))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])

#!/usr/bin/env python3
"""The player model for the game, from the owner's high-detail GLB (a Mixamo-rigged athlete, ~195k triangles and a
4096 px auto-atlas): too heavy for a phone drawing 24 of them. This builds a light copy with the same skeleton:

1. weld the vertices by position (the atlas's thousands of UV islands otherwise stop any simplifier at their seams);
2. simplify to each level of detail's triangle budget (meshoptimizer);
3. unwrap the result afresh (xatlas) and bake the original texture onto the new UVs: each texel's point on the
   light mesh takes the colour of the nearest point on the original surface;
4. write a GLB with the original skeleton, skin and node tree, one mesh per level of detail, each with its baked
   texture, and the original's own animations.

Usage: python3 tools/models/build_player.py SOURCE.glb assets/models/player.glb
Needs numpy, scipy, Pillow, meshoptimizer and xatlas (pip install). The source GLB is the owner's and is not kept in
the repository.
"""
import io
import json
import struct
import sys

import meshoptimizer
import numpy as np
import xatlas
from PIL import Image
from scipy.spatial import cKDTree

LODS = [("player_lod0", 3600, 1024), ("player_lod1", 1400, 512)]   # name, triangles, texture size

CTYPE = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_glb(path):
    d = open(path, "rb").read()
    jlen = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + jlen])
    off = 20 + jlen
    blen = struct.unpack("<I", d[off:off + 4])[0]
    return j, d[off + 8:off + 8 + blen]


def accessor(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    dt = CTYPE[a["componentType"]]
    n = NCOMP[a["type"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 0)
    item = np.dtype(dt).itemsize * n
    if stride and stride != item:
        raw = np.frombuffer(b, dtype=np.uint8, count=stride * a["count"], offset=start).reshape(a["count"], stride)
        arr = raw[:, :item].copy().view(dt).reshape(a["count"], n)
    else:
        arr = np.frombuffer(b, dtype=dt, count=a["count"] * n, offset=start).reshape(a["count"], n)
    if a.get("normalized") and dt in (np.uint8, np.uint16):
        arr = arr.astype(np.float32) / np.iinfo(dt).max
    return arr


def weld(P):
    key = np.round(P * 2000.0).astype(np.int64)   # half a millimetre
    _, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    return first, inv.reshape(-1)


def simplify(P, idx, tris):
    dest = np.zeros(idx.size, dtype=np.uint32)
    n = meshoptimizer.simplify(dest, idx.astype(np.uint32), P.astype(np.float32), target_index_count=tris * 3,
                               target_error=0.08)
    if n > tris * 3 * 1.15:
        n = meshoptimizer.simplify_sloppy(dest, idx.astype(np.uint32), P.astype(np.float32), target_index_count=tris * 3,
                                          target_error=0.08)
    return dest[:n].reshape(-1, 3)


def normals(P, F):
    N = np.zeros_like(P)
    fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    for k in range(3):
        np.add.at(N, F[:, k], fn)
    return (N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)).astype(np.float32)


def closest_on_triangles(p, a, b, c):
    """Closest points on triangles (a, b, c) to points p (all (n, 3)); returns barycentrics (n, 3)."""
    ab, ac, ap = b - a, c - a, p - a
    d1, d2 = (ab * ap).sum(1), (ac * ap).sum(1)
    bp = p - b
    d3, d4 = (ab * bp).sum(1), (ac * bp).sum(1)
    cp = p - c
    d5, d6 = (ab * cp).sum(1), (ac * cp).sum(1)
    va = d3 * d6 - d5 * d4
    vb = d5 * d2 - d1 * d6
    vc = d1 * d4 - d3 * d2
    denom = np.where(np.abs(va + vb + vc) < 1e-20, 1e-20, va + vb + vc)
    v = vb / denom
    w = vc / denom
    bary = np.stack([1 - v - w, v, w], 1)
    # Outside the face: clamp to the nearest edge (good enough at a texel's scale).
    out = (bary < 0).any(1)
    if out.any():
        bary[out] = np.clip(bary[out], 0, None)
        bary[out] /= bary[out].sum(1, keepdims=True)
    return bary


def bake(Pn, Fn, UVn, size, P0, F0, UV0, tex):
    """The original texture onto the new UVs."""
    W, H = tex.shape[1], tex.shape[0]
    cent = P0[F0].mean(1)
    tree = cKDTree(cent)
    out = np.zeros((size, size, 3), np.float32)
    cls = np.full((size, size), CLASS_OTHER, np.float32)
    filled = np.zeros((size, size), bool)
    pts, pix = [], []
    for f in Fn:
        uv = UVn[f] * size
        lo = np.floor(uv.min(0) - 1).astype(int).clip(0, size - 1)
        hi = np.ceil(uv.max(0) + 1).astype(int).clip(0, size - 1)
        xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
        q = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], 1)
        v0, v1, v2 = uv
        den = (v1[1] - v2[1]) * (v0[0] - v2[0]) + (v2[0] - v1[0]) * (v0[1] - v2[1])
        if abs(den) < 1e-12:
            continue
        l0 = ((v1[1] - v2[1]) * (q[:, 0] - v2[0]) + (v2[0] - v1[0]) * (q[:, 1] - v2[1])) / den
        l1 = ((v2[1] - v0[1]) * (q[:, 0] - v2[0]) + (v0[0] - v2[0]) * (q[:, 1] - v2[1])) / den
        l2 = 1 - l0 - l1
        inside = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        if not inside.any():
            continue
        L = np.stack([l0, l1, l2], 1)[inside]
        pts.append(L @ Pn[f])
        pix.append(np.stack([xs.ravel()[inside], ys.ravel()[inside]], 1))
    pts = np.concatenate(pts)
    pix = np.concatenate(pix)
    _, cand = tree.query(pts, k=8)
    best = np.full(len(pts), np.inf)
    best_uv = np.zeros((len(pts), 2))
    for k in range(cand.shape[1]):
        tri = F0[cand[:, k]]
        a, b_, c = P0[tri[:, 0]], P0[tri[:, 1]], P0[tri[:, 2]]
        bary = closest_on_triangles(pts, a, b_, c)
        q = bary[:, :1] * a + bary[:, 1:2] * b_ + bary[:, 2:] * c
        dist = np.linalg.norm(q - pts, axis=1)
        better = dist < best
        best[better] = dist[better]
        uv = bary[:, :1] * UV0[tri[:, 0]] + bary[:, 1:2] * UV0[tri[:, 1]] + bary[:, 2:] * UV0[tri[:, 2]]
        best_uv[better] = uv[better]
    tx = np.clip((best_uv[:, 0] % 1.0) * W, 0, W - 1).astype(int)
    ty = np.clip((best_uv[:, 1] % 1.0) * H, 0, H - 1).astype(int)
    rgb = tex[ty, tx, :3]
    out[pix[:, 1], pix[:, 0]] = rgb
    cls[pix[:, 1], pix[:, 0]] = classify(rgb / 255.0, pts[:, 1])
    filled[pix[:, 1], pix[:, 0]] = True
    # Pad the islands outward so filtering and mipmaps never reach the empty atlas.
    for _ in range(12):
        acc = np.zeros_like(out)
        cnt = np.zeros(filled.shape, np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sf = np.roll(filled, (dy, dx), (0, 1))
            acc += np.roll(out, (dy, dx), (0, 1)) * sf[..., None]
            cnt += sf
        grow = (~filled) & (cnt > 0)
        out[grow] = acc[grow] / cnt[grow][:, None]
        # The class spreads as the nearest one does (any filled neighbour's), never averaged.
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sf = np.roll(filled, (dy, dx), (0, 1)) & grow
            cls[sf] = np.roll(cls, (dy, dx), (0, 1))[sf]
        filled |= grow
    rgba = np.concatenate([np.clip(out, 0, 255), cls[..., None]], axis=2)
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


# The texture's alpha says what each texel is, for the shader's kit colours (game/model_body.gd).
CLASS_SHIRT, CLASS_SHORTS, CLASS_SKIN, CLASS_OTHER = 64.0, 128.0, 192.0, 255.0


def classify(rgb, height):
    """The source paints a light blue shirt, navy shorts and trim, and the skin orange; shoes (below 13 cm) are
    blue too but stay as painted."""
    mx = rgb.max(1)
    mn = rgb.min(1)
    d = mx - mn
    sat = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
    hue = np.zeros(len(rgb))
    nz = d > 1e-6
    rm = nz & (mx == r)
    gm = nz & (mx == g) & ~rm
    bm = nz & ~rm & ~gm
    hue[rm] = ((g - b)[rm] / d[rm]) % 6
    hue[gm] = (b - r)[gm] / d[gm] + 2
    hue[bm] = (r - g)[bm] / d[bm] + 4
    hue /= 6.0
    blue = (hue > 0.48) & (hue < 0.72) & (sat > 0.2) & (height > 0.13)
    navy = blue & ((sat > 0.62) | (mx < 0.5))
    skin = (hue < 0.12) & (sat > 0.25) & (mx > 0.25)
    out = np.full(len(rgb), CLASS_OTHER)
    out[skin] = CLASS_SKIN
    out[blue & ~navy] = CLASS_SHIRT
    out[navy] = CLASS_SHORTS
    return out


class Writer:
    def __init__(self):
        self.bin = bytearray()
        self.views = []
        self.accessors = []

    def view(self, data: bytes, target=None) -> int:
        while len(self.bin) % 4:
            self.bin.append(0)
        v = {"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(data)}
        if target:
            v["target"] = target
        self.bin += data
        self.views.append(v)
        return len(self.views) - 1

    def acc(self, arr: np.ndarray, ctype: int, typ: str, target=None, minmax=False, normalized=False) -> int:
        bv = self.view(np.ascontiguousarray(arr).tobytes(), target)
        a = {"bufferView": bv, "componentType": ctype, "count": int(arr.shape[0]), "type": typ}
        if normalized:
            a["normalized"] = True
        if minmax:
            a["min"] = arr.min(0).tolist()
            a["max"] = arr.max(0).tolist()
        self.accessors.append(a)
        return len(self.accessors) - 1

    def copy_acc(self, j, b, i) -> int:
        a = dict(j["accessors"][i])
        bv = j["bufferViews"][a["bufferView"]]
        start = bv.get("byteOffset", 0)
        a["bufferView"] = self.view(b[start:start + bv["byteLength"]])
        self.accessors.append(a)
        return len(self.accessors) - 1


def main(src, dst):
    j, b = read_glb(src)
    prim = j["meshes"][0]["primitives"][0]
    at = prim["attributes"]
    P0 = accessor(j, b, at["POSITION"]).astype(np.float64)
    UV0 = accessor(j, b, at["TEXCOORD_0"]).astype(np.float64)
    J0 = accessor(j, b, at["JOINTS_0"]).astype(np.uint16)
    W0 = accessor(j, b, at["WEIGHTS_0"]).astype(np.float32)
    F0 = accessor(j, b, prim["indices"]).reshape(-1, 3).astype(np.int64)
    img = j["images"][0]
    bv = j["bufferViews"][img["bufferView"]]
    tex = np.asarray(Image.open(io.BytesIO(b[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]])).convert("RGB")).astype(np.float32)
    print("source: %d vertices, %d triangles, texture %dx%d" % (len(P0), len(F0), tex.shape[1], tex.shape[0]))

    first, inv = weld(P0)
    Pw, Jw, Ww = P0[first], J0[first], W0[first]
    Fw = inv[F0]
    Fw = Fw[(Fw[:, 0] != Fw[:, 1]) & (Fw[:, 1] != Fw[:, 2]) & (Fw[:, 0] != Fw[:, 2])]
    print("welded: %d vertices" % len(Pw))

    w = Writer()
    out_j = {"asset": {"version": "2.0", "generator": "kho-kho-game tools/models/build_player.py"}, "scene": 0}
    # The node tree, the skin and the animations as they were; the meshes are replaced.
    nodes = json.loads(json.dumps(j["nodes"]))
    skin = dict(j["skins"][0])
    skin["inverseBindMatrices"] = w.copy_acc(j, b, skin["inverseBindMatrices"])
    anims = []
    for an in j.get("animations", []):
        a2 = {"name": an.get("name"), "channels": an["channels"], "samplers": []}
        for s in an["samplers"]:
            a2["samplers"].append({"input": w.copy_acc(j, b, s["input"]), "output": w.copy_acc(j, b, s["output"]),
                                   "interpolation": s.get("interpolation", "LINEAR")})
        anims.append(a2)
    meshes, materials, textures, images = [], [], [], []
    mesh_node = next(i for i, n in enumerate(nodes) if "mesh" in n)
    parent = next(i for i, n in enumerate(nodes) if mesh_node in n.get("children", []))
    for li, (name, tris, size) in enumerate(LODS):
        F = simplify(Pw, Fw.reshape(-1), tris)
        used = np.unique(F)
        remap = np.full(len(Pw), -1, np.int64)
        remap[used] = np.arange(len(used))
        P = Pw[used].astype(np.float32)
        F = remap[F]
        vmap, Fx, UV = xatlas.parametrize(P, F.astype(np.uint32))
        Pn, Jn, Wn = P[vmap], Jw[used][vmap], Ww[used][vmap]
        Wn = Wn / np.maximum(Wn.sum(1, keepdims=True), 1e-6)
        Nn = normals(Pn.astype(np.float64), Fx.astype(np.int64))
        im = bake(Pn.astype(np.float64), Fx.astype(np.int64), UV.astype(np.float64), size, P0, F0, UV0, tex)
        buf = io.BytesIO()
        im.save(buf, "PNG", optimize=True)
        print("%s: %d triangles, %d vertices, texture %d px (%d KB)" % (name, len(Fx), len(Pn), size, len(buf.getvalue()) // 1024))
        images.append({"name": name, "mimeType": "image/png", "bufferView": w.view(buf.getvalue())})
        textures.append({"source": li, "sampler": 0})
        materials.append({"name": name, "doubleSided": False,
                          "pbrMetallicRoughness": {"baseColorTexture": {"index": li}, "metallicFactor": 0.0, "roughnessFactor": 0.85}})
        attrs = {"POSITION": w.acc(Pn.astype(np.float32), 5126, "VEC3", 34962, minmax=True),
                 "NORMAL": w.acc(Nn, 5126, "VEC3", 34962),
                 "TEXCOORD_0": w.acc(UV.astype(np.float32), 5126, "VEC2", 34962),
                 "JOINTS_0": w.acc(Jn.astype(np.uint8 if Jn.max() < 256 else np.uint16), 5121 if Jn.max() < 256 else 5123, "VEC4", 34962),
                 "WEIGHTS_0": w.acc(Wn.astype(np.float32), 5126, "VEC4", 34962)}
        idx = w.acc(Fx.astype(np.uint16 if len(Pn) < 65536 else np.uint32).reshape(-1), 5123 if len(Pn) < 65536 else 5125, "SCALAR", 34963)
        meshes.append({"name": name, "primitives": [{"attributes": attrs, "indices": idx, "material": li}]})
        if li == 0:
            nodes[mesh_node] = {"name": name, "mesh": 0, "skin": 0}
        else:
            nodes.append({"name": name, "mesh": li, "skin": 0})
            nodes[parent]["children"].append(len(nodes) - 1)
    out_j.update({"scenes": j["scenes"], "nodes": nodes, "skins": [skin], "animations": anims, "meshes": meshes,
                  "materials": materials, "textures": textures, "images": images,
                  "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}],
                  "accessors": w.accessors, "bufferViews": w.views, "buffers": [{"byteLength": len(w.bin)}]})
    if not anims:
        del out_j["animations"]
    js = json.dumps(out_j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    bn = bytes(w.bin) + b"\0" * ((4 - len(w.bin) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(bn)
    with open(dst, "wb") as fo:
        fo.write(struct.pack("<III", 0x46546C67, 2, total))
        fo.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        fo.write(struct.pack("<II", len(bn), 0x004E4942) + bn)
    print("wrote %s (%d KB)" % (dst, total // 1024))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

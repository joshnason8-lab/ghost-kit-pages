#!/usr/bin/env python3
"""Give a textured body's bare legs back to its skin, and the bottom of its shorts to the shorts.

kit_texture.py finds the kit by its colour, and on the legs that goes wrong in ways a team's colours show up:

1. Saturated skin, in the shadows of a knee or shin, is close enough in hue to a red trim to be taken for it, so
   in a team's colours the knees and shins come out speckled with its trim (and here and there its kit). Below the
   shorts nothing is worn in the team's colours (knee pads, ankle guards and shoes keep their own), so every kit and
   trim mark there that is not part of the shorts is cleared, and the skin among them gets the player's skin tone
   back (alpha 0). On the shorts, trim the colour of skin is cleared too: a real trim is red or pink.
2. autorig.py marks the shorts by where they are on the thigh (its top 60%), and most shorts reach lower than that,
   so their bottom edge was painted in the jersey's colour: a light band round the bottom of darker shorts. The
   vertices of the shorts found here (the kit joined to the shorts region, above the knees) join the shorts region.
3. A few small pieces of the feet and shins have their texture inside the jersey's, which keeps its kit: they are
   pointed at the skin of a neighbour instead.

The shorts are told from the marks on the legs by the mesh: kit-coloured triangles joined to the shorts region are
the shorts; anything else on the legs is not.

Usage: python3 leg_skin.py BODY.krb KIT.webp ALBEDO.webp [--check OUT.png]   (rewrites BODY.krb and KIT.webp)
Use the --main-hue and --trim-hue the body's kit_texture.py run used (the defaults are the same).
"""

import argparse
import json
import struct
from collections import deque

import cv2
import numpy as np
from PIL import Image

LEG = ("thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r")
SKIN, SHORTS = 0, 2   # autorig.py's regions


def pad4(n):
    return n + (-n % 4)


def hue_near(h, centre, width):
    return np.abs((h - centre + 180.0) % 360.0 - 180.0) < width


def read_krb(path):
    """The parts of a .krb (see pack_body.py) this needs, and where its UVs and regions are in the file."""
    b = bytearray(open(path, "rb").read())
    assert b[:4] == b"KRB1", path
    hl = struct.unpack("<I", b[4:8])[0]
    h = json.loads(bytes(b[8:8 + hl]))
    n = h["vertices"]
    o = 8 + hl
    pos = np.frombuffer(b, "<u2", n * 3, o).reshape(-1, 3).astype(np.float64)
    o += pad4(n * 6) + pad4(n * 3)   # positions, normals
    assert h["has_uv"], "an untextured body has no kit map"
    at = {"uv": o}
    uv = np.frombuffer(b, "<u2", n * 2, o).reshape(-1, 2) / 65535.0
    o += pad4(n * 4)
    bones = np.frombuffer(b, "u1", n * 4, o).reshape(-1, 4).astype(np.int64)
    o += pad4(n * 4)
    w = np.frombuffer(b, "u1", n * 4, o).reshape(-1, 4)
    o += pad4(n * 4)
    at["region"] = o
    region = np.frombuffer(b, "u1", n, o).astype(np.int64)
    o += pad4(n)
    tri = np.frombuffer(b, "<u4" if h["index_u32"] else "<u2", h["indices"], o).astype(np.int64).reshape(-1, 3)
    V = np.array(h["pos_min"]) + pos / 65535.0 * np.array(h["pos_span"])
    top = bones[np.arange(n), w.argmax(axis=1)]
    return b, h, V, pos, uv, top, region, at, tri


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("krb")
    ap.add_argument("kit")
    ap.add_argument("albedo")
    ap.add_argument("--main-hue", type=float, default=230.0)
    ap.add_argument("--trim-hue", type=float, default=355.0)
    ap.add_argument("--check", help="only write a picture of the kit map: cleared marks magenta, the shorts cyan")
    a = ap.parse_args()

    blob, h, V, pos, uv, top, region, at, tri = read_krb(a.krb)
    names = [b["name"] for b in h["bones"]]
    kit = np.array(Image.open(a.kit).convert("RGBA"))
    albedo = np.asarray(Image.open(a.albedo).convert("RGB"))
    H, W = kit.shape[:2]
    px = np.round(uv * np.array([W, H]) * 16).astype(np.int32)   # 4 bits of sub-pixel precision, as kit_texture.py

    def raster(sel):
        m = np.zeros((H, W), np.uint8)
        for t in tri[sel]:
            cv2.fillPoly(m, [px[t].reshape(-1, 1, 2)], 1, lineType=cv2.LINE_8, shift=4)
        return m.astype(bool)

    bary = np.array([[1, 1, 1], [4, 1, 1], [1, 4, 1], [1, 1, 4], [2, 2, 1], [2, 1, 2], [1, 2, 2]], np.float64)
    bary /= bary.sum(axis=1, keepdims=True)

    def points(tris, corners=True):
        """The texels at a few points across each triangle, and its corners."""
        pts = np.einsum("kj,tjc->tkc", bary, uv[tri[tris]])
        if corners:
            pts = np.concatenate([pts, uv[tri[tris]]], axis=1)
        return np.clip((pts * np.array([W, H])).astype(int), 0, [W - 1, H - 1])

    def samples(mask, tris):
        """Each triangle's share of the texels across it in the mask."""
        p = points(tris, False)
        return mask[p[..., 1], p[..., 0]].mean(axis=1)

    def area(sel):
        """The texels the triangles use, slivers too (thinner than a texel, they cover no texel's middle, but are
        drawn from the texels round them)."""
        m = raster(sel)
        p = points(np.where(sel)[0]).reshape(-1, 2)
        m[p[:, 1], p[:, 0]] = True
        return cv2.dilate(m.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)

    hsv = cv2.cvtColor(albedo, cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
    hue, sat, val = hsv[..., 0] * 360.0 / 256.0, hsv[..., 1] / 255.0, hsv[..., 2] / 255.0
    main = kit[..., 0] > 127
    trim = kit[..., 1] > 127
    if hue_near(a.trim_hue, 25, 20):
        real_trim = trim   # an orange trim is skin's hue: no telling them apart by it
    else:
        # A red trim, pink to crimson in its shadows (as kit_texture.py takes it), but not the brown of skin.
        real_trim = trim & hue_near(hue, a.trim_hue - 20, 32) & (sat > 0.6)
    kitlike = (main & hue_near(hue, a.main_hue, 40)) | real_trim
    # Skin by its colour (looser than kit_texture.py's test, which these failed, being taken for kit): red to orange
    # browns, neither grey nor glaring. Pads, guards and shoes are left out of the skin tone, as before.
    skin_like = hue_near(hue, 10, 40) & (sat > 0.1) & (sat < 0.85) & (val > 0.06) & (val < 0.95)

    # Triangles across UV seams share a position, not a vertex.
    _, weld = np.unique(pos.astype(np.int64), axis=0, return_inverse=True)
    weld = weld.reshape(-1)
    edges = {}
    for fi, t in enumerate(weld[tri]):
        for e in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
            edges.setdefault((min(e), max(e)), []).append(fi)
    nbrs = [[] for _ in range(len(tri))]
    for fs in edges.values():
        for f1 in fs:
            nbrs[f1].extend(f2 for f2 in fs if f2 != f1)

    every = np.arange(len(tri))
    cover = samples(kitlike, every)
    leg = np.isin(top[tri], [names.index(n) for n in LEG if n in names]).all(axis=1)
    knee = min(h["bones"][names.index(s)]["head"][1] for s in ("shin_l", "shin_r"))
    above_knee = (V[tri, 1] > knee - 0.02).all(axis=1)
    in_shorts = (region[tri] == SHORTS).any(axis=1)
    # The shorts: kit joined to the shorts region, not past the knees.
    shorts = np.zeros(len(tri), bool)
    todo = deque(np.where(leg & in_shorts & (cover >= 0.5))[0])
    shorts[list(todo)] = True
    while todo:
        f = todo.popleft()
        for g in nbrs[f]:
            if not shorts[g] and leg[g] and above_knee[g] and cover[g] >= 0.5:
                shorts[g] = True
                todo.append(g)
    # And the triangles along their edge, which are kit in part.
    edge = np.zeros(len(tri), bool)
    for f in np.where(shorts)[0]:
        for g in nbrs[f]:
            if leg[g] and above_knee[g] and cover[g] > 0.0:
                edge[g] = True
    shorts |= edge
    bare = leg & (region[tri] == SKIN).all(axis=1) & ~shorts

    keep = area(~bare)   # everything else on the body, the shorts included, as kit_texture.py made it
    marked = main | trim
    hit = area(bare) & ~keep & (kit[..., :2].max(axis=2) > 0)
    # Skin-coloured trim on the shorts and their edge, or in the shorts region where the shorts are shorter.
    hit |= area(leg & ~bare) & trim & ~real_trim & skin_like
    was_kit = hit & marked
    kit[hit, 0] = 0
    kit[hit, 1] = 0
    kit[was_kit & skin_like, 3] = 0

    # Small pieces of a bare leg whose texture lies in another part's (which keeps its kit) take a bare neighbour's
    # instead: a piece is the triangles joined by their vertices (a seam in the texture splits them).
    left = (kit[..., 0].astype(np.int32) + kit[..., 1]) > 127
    tri_of = {}
    for fi, t in enumerate(tri):
        for v in t:
            tri_of.setdefault(int(v), []).append(fi)
    piece = np.full(len(tri), -1)
    pieces = []
    for f0 in range(len(tri)):
        if piece[f0] >= 0:
            continue
        piece[f0] = len(pieces)
        todo, members = [f0], []
        while todo:
            f = todo.pop()
            members.append(f)
            for v in tri[f]:
                for g in tri_of[int(v)]:
                    if piece[g] < 0:
                        piece[g] = len(pieces)
                        todo.append(g)
        pieces.append(np.array(members))
    moved = 0
    for members in pieces:
        if len(members) > 8 or not bare[members].all() or samples(left, members).max() < 0.3:
            continue
        for g in (g for f in members for g in nbrs[f]):
            if bare[g] and piece[g] != piece[members[0]] and samples(left, np.array([g]))[0] == 0:
                uv[np.unique(tri[members])] = uv[tri[g]].mean(axis=0)
                moved += len(members)
                break

    # Pad the islands out again where they changed, so filtering doesn't bring the old marks back from the gaps.
    used = cv2.dilate(raster(every >= 0).astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    near = cv2.dilate(hit.astype(np.uint8), np.ones((29, 29), np.uint8)).astype(bool) & ~used
    im = kit.astype(np.float32)
    m = used.astype(np.float32)
    for _ in range(12):   # as kit_texture.py's pad()
        num = cv2.blur(im * m[..., None], (3, 3))
        den = cv2.blur(m, (3, 3))
        grow = (m == 0) & (den > 0)
        im[grow] = num[grow] / den[grow][:, None]
        m[grow] = 1.0
    kit[near] = np.clip(np.round(im[near]), 0, 255).astype(np.uint8)

    # The shorts' own vertices join the shorts region (only their colour reads it: jersey or shorts).
    joined = np.unique(tri[shorts].ravel())
    joined = joined[region[joined] == SKIN]
    new_region = region.copy()
    new_region[joined] = SHORTS
    blob[at["region"]:at["region"] + len(region)] = new_region.astype(np.uint8).tobytes()
    blob[at["uv"]:at["uv"] + uv.size * 2] = np.round(np.clip(uv, 0.0, 1.0) * 65535).astype("<u2").tobytes()

    print(f"{a.krb.split('/')[-1]}: cleared {int(hit.sum())} texels of kit on the legs "
          f"({int((was_kit & skin_like).sum())} back to skin), {int(shorts.sum())} triangles of shorts, "
          f"{len(joined)} vertices joined the shorts region, {moved} triangles moved off another part's texture")
    if a.check:
        show = albedo.copy()
        show[hit] = (255, 0, 255)
        show[raster(shorts) & marked] = (0, 255, 255)
        Image.fromarray(show).save(a.check)
        return
    open(a.krb, "wb").write(blob)
    Image.fromarray(kit).save(a.kit, lossless=True, quality=100, method=6, exact=True)


if __name__ == "__main__":
    main()

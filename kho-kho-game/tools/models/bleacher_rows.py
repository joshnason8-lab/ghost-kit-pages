#!/usr/bin/env python3
"""Where people sit on a bleacher model: its treads (upward faces), grouped by height into rows, each row's front edge
fitted across the model's width (z = a + b*x + c*x^2, for the curved ones). Writes NAME_rows.json beside the model,
which game/arena.gd reads to seat the crowd on it.

Usage: python3 tools/models/bleacher_rows.py assets/env/stands/bleacher_concrete.glb [min_rows]
"""
import json
import struct
import sys

import numpy as np

CT = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def acc(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(b, CT[a["componentType"]], a["count"] * NC[a["type"]], off).reshape(a["count"], NC[a["type"]])


def main(path):
    d = open(path, "rb").read()
    L = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + L])
    b = d[20 + L + 8:]
    p = j["meshes"][0]["primitives"][0]
    P = acc(j, b, p["attributes"]["POSITION"]).astype(float)
    F = acc(j, b, p["indices"]).reshape(-1, 3)
    n = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    area = np.linalg.norm(n, axis=1) * 0.5
    nn = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
    c = P[F].mean(1)
    up = (np.abs(nn[:, 1]) > 0.85) & (area > 1e-4) & (c[:, 1] > 0.15)
    c, w = c[up], area[up]
    # Rows: the heights carrying the most upward area, at least 0.2 m apart.
    hs = np.round(c[:, 1] / 0.05) * 0.05
    levels = {}
    for h, a in zip(hs, w):
        levels[h] = levels.get(h, 0.0) + a
    cand = sorted(levels.items(), key=lambda kv: -kv[1])
    rows = []
    total = sum(levels.values())
    for h, a in cand:
        if a < total * 0.02:
            break
        if all(abs(h - r) >= 0.2 for r in rows):
            rows.append(h)
    rows.sort()
    out = []
    for h in rows:
        sel = np.abs(c[:, 1] - h) < 0.06
        xs, zs = c[sel, 0], c[sel, 2]
        # The front of the tread: the largest z (the model faces +z) in each slice of x; a quadratic through them.
        bins = np.linspace(xs.min(), xs.max(), 12)
        fx, fz = [], []
        for lo, hi in zip(bins[:-1], bins[1:]):
            m = (xs >= lo) & (xs < hi)
            if m.sum() > 2:
                fx.append((lo + hi) / 2)
                fz.append(zs[m].max())
        if len(fx) < 3:
            continue
        coef = np.polyfit(fx, fz, 2)
        out.append({"y": round(float(h), 3), "x0": round(float(xs.min()), 2), "x1": round(float(xs.max()), 2),
                    "z": [round(float(v), 4) for v in coef[::-1]]})
    dst = path.replace(".glb", "_rows.json")
    json.dump({"rows": out}, open(dst, "w"), indent=1)
    print("%s: %d rows %s" % (dst, len(out), [r["y"] for r in out]))


if __name__ == "__main__":
    main(sys.argv[1])

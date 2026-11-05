#!/usr/bin/env python3
"""Pack a rigged body (the JSON from autorig.py and kit_texture.py) into the game's compact binary form, .krb.

A body's JSON is about 2.5 MB of text, slow to read on a phone; packed it is about 0.4 MB, with positions,
UVs and weights quantised (positions to 1/65535 of the body's size, well under a millimetre).

Layout, little-endian: b"KRB1", u32 header length, the header (JSON: counts, position range, bones, texture
entry, height) padded to 4 bytes, then positions u16x3, normals s8x3, UVs u16x2 (if any), bone indices
u8x4, weights u8x4, regions u8, each padded to 4 bytes, then triangle indices (u16, or u32 past 65,535
vertices). game/rigged_body.gd reads it.

Usage: python3 pack_body.py RIGGED.json OUT.krb
"""

import json
import struct
import sys

import numpy as np


def pad4(b):
    return b + b"\0" * (-len(b) % 4)


def main():
    src, out = sys.argv[1], sys.argv[2]
    d = json.load(open(src))
    V = np.array(d["vertices"], dtype=np.float64).reshape(-1, 3)
    N = np.array(d["normals"], dtype=np.float64).reshape(-1, 3)
    n = len(V)
    lo, hi = V.min(axis=0), V.max(axis=0)
    span = np.maximum(hi - lo, 1e-6)
    pos = np.round((V - lo) / span * 65535).astype("<u2")
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    nrm = np.round(N * 127).astype("i1")
    bones = np.array(d["bones4"], dtype=np.int64).reshape(-1, 4)
    w = np.array(d["weights4"], dtype=np.float64).reshape(-1, 4)
    w /= np.maximum(w.sum(axis=1, keepdims=True), 1e-9)
    wq = np.round(w * 255).astype(np.int64)
    top = wq.argmax(axis=1)
    wq[np.arange(n), top] += 255 - wq.sum(axis=1)   # sums stay exactly 255
    idx = np.array(d["indices"], dtype=np.int64)
    big = n > 65535
    has_uv = "uvs" in d
    header = {
        "vertices": n, "indices": int(len(idx)), "index_u32": big, "has_uv": has_uv,
        "pos_min": lo.round(6).tolist(), "pos_span": span.round(6).tolist(),
        "bones": d["bones"], "height": d["height"], "source": d.get("source", ""),
    }
    if "texture" in d:
        header["texture"] = d["texture"]
    hb = json.dumps(header, separators=(",", ":")).encode()
    hb += b" " * (-len(hb) % 4)   # JSON allows trailing spaces
    parts = [b"KRB1", struct.pack("<I", len(hb)), hb,
             pad4(pos.tobytes()), pad4(nrm.tobytes())]
    if has_uv:
        uv = np.clip(np.array(d["uvs"], dtype=np.float64).reshape(-1, 2), 0.0, 1.0)
        parts.append(pad4(np.round(uv * 65535).astype("<u2").tobytes()))
    parts += [pad4(bones.astype("u1").tobytes()), pad4(wq.astype("u1").tobytes()),
              pad4(np.array(d["region"], dtype="u1").tobytes()),
              idx.astype("<u4" if big else "<u2").tobytes()]
    blob = b"".join(parts)
    open(out, "wb").write(blob)
    print(f"wrote {out}: {len(blob) // 1024} KB ({n} vertices, {len(idx) // 3} triangles)")


if __name__ == "__main__":
    main()

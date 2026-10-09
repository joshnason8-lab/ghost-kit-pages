"""Get a generated GLB model ready for rigging: bake its node transform, face it the way the rig
tools expect, and keep its own normals and UVs.

1. Applies the scene's node transforms and, with --turn, turns the model 180 degrees about Y
   (the rig tools expect it to face -Z; glTF models usually face +Z).
2. Keeps the file's normals. trimesh recomputes its own on load, which loses any smoothing
   the model came with, so they are read from the file.
3. Flips any triangle whose winding disagrees with those normals (some exports hide wrongly
   wound triangles by drawing both sides).

The texture is not copied; kit_texture.py makes the game's textures from the original file.

Usage:
  python prepare.py IN.glb OUT.glb [--turn]
"""

import argparse
import json
import struct

import numpy as np
import trimesh


def file_normals(path):
    """The NORMAL attribute of the first mesh in a GLB, as stored. Only node rotation matters
    for normals; the models this is for have a single node."""
    b = open(path, "rb").read()
    jlen = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jlen])
    blen = struct.unpack("<I", b[20 + jlen:24 + jlen])[0]
    data = b[28 + jlen:28 + jlen + blen]
    acc = j["accessors"][j["meshes"][0]["primitives"][0]["attributes"]["NORMAL"]]
    if acc["componentType"] != 5126:
        raise SystemExit("quantised normals are not supported")
    bv = j["bufferViews"][acc["bufferView"]]
    stride = bv.get("byteStride", 12)   # vertex attributes are often interleaved
    start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    rows = np.frombuffer(data, dtype=np.uint8, count=stride * (acc["count"] - 1) + 12, offset=start)
    n = np.lib.stride_tricks.as_strided(rows, shape=(acc["count"], 12), strides=(stride, 1)).copy()
    n = n.view(np.float32).reshape(-1, 3).astype(np.float64)
    rot = j["nodes"][0].get("rotation")
    if rot:
        n = n @ trimesh.transformations.quaternion_matrix([rot[3], rot[0], rot[1], rot[2]])[:3, :3].T
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--turn", action="store_true", help="turn 180 degrees about Y to face -Z")
    a = ap.parse_args()

    m = trimesh.load(a.src, force="mesh", process=False)
    V = np.asarray(m.vertices, dtype=np.float64)
    F = np.asarray(m.faces, dtype=np.int64).copy()
    N = file_normals(a.src)
    if len(N) != len(V):
        raise SystemExit("normals do not match the vertices")
    if a.turn:
        V = V * np.array([-1.0, 1.0, -1.0])
        N = N * np.array([-1.0, 1.0, -1.0])

    fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    flip = (fn * N[F].mean(axis=1)).sum(axis=1) < 0.0
    F[flip] = F[flip][:, [0, 2, 1]]
    print(f"flipped {int(flip.sum())} of {len(F)} triangles")

    res = trimesh.Trimesh(vertices=V, faces=F, vertex_normals=N, visual=m.visual, process=False)
    res.export(a.out)
    print("wrote", a.out, len(V), "vertices,", len(F), "triangles, bounds", res.bounds.round(3).tolist())


if __name__ == "__main__":
    main()

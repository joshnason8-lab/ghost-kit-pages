"""Get a heavy or already rigged model ready for make_body.py: one mesh, a phone's number of triangles, its texture.

A model rigged in Meshy's web app (or Mixamo) comes with a few hundred thousand triangles, a skeleton and walk and
run clips, and the game uses none of those: it rigs every body to its own skeleton (autorig.py) and moves it itself.
This keeps the first mesh as stored, which for a skinned mesh is its bind pose in metres (the skin does not use the
node's own transform, so it is not applied), welds the duplicate vertices its texture seams keep, collapses edges
down to TRIANGLES keeping the texture coordinates (MeshLab's quadric collapse with texture), and writes a one-node
GLB with smooth normals and the base colour texture, as Meshy's unrigged downloads come.

Usage:
  python slim.py IN.glb OUT.glb [--triangles 15000] [--texture-size 2048]
"""

import argparse
import io
import json
import struct

import numpy as np
import pymeshlab
import trimesh
from PIL import Image

TYPES = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path):
    b = open(path, "rb").read()
    jlen = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jlen])
    blen = struct.unpack("<I", b[20 + jlen:24 + jlen])[0]
    return j, b[28 + jlen:28 + jlen + blen]


def accessor(j, data, i):
    acc = j["accessors"][i]
    bv = j["bufferViews"][acc["bufferView"]]
    dt = np.dtype(TYPES[acc["componentType"]])
    n = WIDTH[acc["type"]]
    stride = bv.get("byteStride", dt.itemsize * n)   # vertex attributes may be interleaved
    start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    rows = np.frombuffer(data, dtype=np.uint8, count=stride * (acc["count"] - 1) + dt.itemsize * n, offset=start)
    a = np.lib.stride_tricks.as_strided(rows, shape=(acc["count"], dt.itemsize * n), strides=(stride, 1)).copy()
    return a.view(dt).reshape(acc["count"], n) if n > 1 else a.view(dt).reshape(-1)


def base_color(j, data):
    tex = j["textures"][j["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    bv = j["bufferViews"][j["images"][tex["source"]]["bufferView"]]
    raw = data[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
    return Image.open(io.BytesIO(raw)).convert("RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--triangles", type=int, default=15000)
    ap.add_argument("--texture-size", type=int, default=2048)
    a = ap.parse_args()

    j, data = read_glb(a.src)
    prim = j["meshes"][0]["primitives"][0]
    V = accessor(j, data, prim["attributes"]["POSITION"]).astype(np.float64)
    UV = accessor(j, data, prim["attributes"]["TEXCOORD_0"]).astype(np.float64)
    F = accessor(j, data, prim["indices"]).astype(np.int32).reshape(-1, 3)
    print("in", len(V), "vertices,", len(F), "triangles, height", round(V[:, 1].max() - V[:, 1].min(), 3))

    ms = pymeshlab.MeshSet()
    ms.add_mesh(pymeshlab.Mesh(vertex_matrix=V, face_matrix=F, v_tex_coords_matrix=UV))
    ms.compute_texcoord_transfer_vertex_to_wedge()   # a corner's UV stays its own once the seams are welded
    ms.meshing_merge_close_vertices(threshold=pymeshlab.PureValue(1e-6))
    ms.meshing_decimation_quadric_edge_collapse_with_texture(targetfacenum=a.triangles, qualitythr=0.5,
                                                             extratcoordw=1.0, preserveboundary=True,
                                                             optimalplacement=True, preservenormal=True)
    ms.compute_normal_per_vertex()
    m = ms.current_mesh()
    v, f = m.vertex_matrix(), m.face_matrix()
    wuv = m.wedge_tex_coord_matrix().reshape(-1, 3, 2)
    n = m.vertex_normal_matrix()
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)

    # A vertex for each of a welded vertex's UVs: split again along the seams, the normals kept smooth across them.
    key = np.concatenate([f.reshape(-1, 1).astype(np.float64), np.round(wuv.reshape(-1, 2), 6)], axis=1)
    uniq, inv = np.unique(key, axis=0, return_inverse=True)
    src = uniq[:, 0].astype(np.int64)
    out = trimesh.Trimesh(v[src], inv.reshape(-1, 3), vertex_normals=n[src], process=False)
    tex = base_color(j, data)
    if a.texture_size and tex.width > a.texture_size:
        tex = tex.resize((a.texture_size, a.texture_size), Image.LANCZOS)
    uv = uniq[:, 1:].copy()
    uv[:, 1] = 1.0 - uv[:, 1]   # glTF's v runs down the image, trimesh's up (it turns it back on export)
    out.visual = trimesh.visual.TextureVisuals(uv=uv, material=trimesh.visual.material.PBRMaterial(
        baseColorTexture=tex, baseColorFactor=[255, 255, 255, 255], metallicFactor=0.0, roughnessFactor=0.8))
    out.export(a.out, include_normals=True)
    print("out", len(src), "vertices,", len(f), "triangles, texture", tex.size)


if __name__ == "__main__":
    main()

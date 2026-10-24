"""Shrink a heavy generated model (an OBJ or GLB from Meshy, say) to a phone-friendly mesh.

Welds the duplicate vertices the file keeps at texture seams (or the result tears there),
simplifies to TARGET triangles, turns it to face -Z, stands it on the floor and scales it
to HEIGHT metres. Texture coordinates are dropped: the game colours kit regions itself.

Usage: python decimate.py IN.obj OUT.glb [TARGET_TRIANGLES=14000] [HEIGHT=1.5]
"""

import sys

import fast_simplification as fs
import numpy as np
import trimesh

src, out = sys.argv[1], sys.argv[2]
target = int(sys.argv[3]) if len(sys.argv) > 3 else 14000
height = float(sys.argv[4]) if len(sys.argv) > 4 else 1.5

m = trimesh.load(src, process=False, force="mesh")
print("loaded", m.vertices.shape, m.faces.shape)
m.visual = trimesh.visual.ColorVisuals()
m.merge_vertices(merge_tex=True, merge_norm=True)
print("welded", m.vertices.shape)
pts = np.asarray(m.vertices, dtype=np.float32)
tri = np.asarray(m.faces, dtype=np.int64)
p, f = fs.simplify(pts, tri, target_reduction=1.0 - target / len(tri), agg=7)

# Meshy models face +Z; the game's face -Z.
p = p.astype(np.float64)
p[:, 0] *= -1
p[:, 2] *= -1
p *= height / (p[:, 1].max() - p[:, 1].min())
p[:, 1] -= p[:, 1].min()
p[:, 0] -= (p[:, 0].max() + p[:, 0].min()) / 2
p[:, 2] -= (p[:, 2].max() + p[:, 2].min()) / 2
o = trimesh.Trimesh(p, f, process=False)
_ = o.vertex_normals
o.export(out, include_normals=True)
print("out", p.shape, f.shape)

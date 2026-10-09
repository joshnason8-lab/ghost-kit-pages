"""Rig a static humanoid mesh (for example an AI-generated player model) for the game.

The game drives every player with code (game/human_model.gd); this script gives a static
mesh a skeleton that code can drive:

1. Find the joints. tools/rig/render_views.tscn renders orthographic front, right and left
   views; a pose model (YOLO11 pose, as in tools/mocap) marks 17 keypoints in each; front
   gives x and y, the side views give z for each side's joints.
2. Build a skeleton (hips, spine, chest, neck, head, arms, legs, feet) from those joints.
3. Skin it: every vertex follows its nearest bone, with soft blends across each joint, and
   stray islands (a hand touching a thigh, say) are handed to the bone around them.
4. Mark regions (skin, jersey, shorts, hair) so each team's kit colours can be applied.

Output: assets/characters/rigged_athlete.json, which game/rigged_body.gd turns into a
skinned mesh at load time. A textured model keeps its UVs ("uvs", origin at the top left as
Godot and glTF use); kit_texture.py makes the textures that go with them.

Usage:
  python autorig.py MESH.glb JOINTS2D.json OUT.json [--px 1024 --extent 2.0 --center-y 0.75]
"""

import argparse
import json

import numpy as np
import trimesh

from prepare import file_normals

KP = ["nose", "l_eye", "r_eye", "l_ear", "r_ear", "l_sh", "r_sh", "l_el", "r_el", "l_wr", "r_wr",
      "l_hip", "r_hip", "l_kn", "r_kn", "l_an", "r_an"]

# name, parent, head joint, tail joint. Joint names refer to the dictionary built below.
BONES = [
    ("hips", None, "pelvis", "spine1"),
    ("spine", "hips", "spine1", "chest"),
    ("chest", "spine", "chest", "neck"),
    ("neck", "chest", "neck", "head"),
    ("head", "neck", "head", "head_top"),
    ("upperarm_l", "chest", "l_sh", "l_el"),
    ("forearm_l", "upperarm_l", "l_el", "l_wr"),
    ("hand_l", "forearm_l", "l_wr", "l_hand"),
    ("upperarm_r", "chest", "r_sh", "r_el"),
    ("forearm_r", "upperarm_r", "r_el", "r_wr"),
    ("hand_r", "forearm_r", "r_wr", "r_hand"),
    ("thigh_l", "hips", "l_hip", "l_kn"),
    ("shin_l", "thigh_l", "l_kn", "l_an"),
    ("foot_l", "shin_l", "l_an", "l_toe"),
    ("thigh_r", "hips", "r_hip", "r_kn"),
    ("shin_r", "thigh_r", "r_kn", "r_an"),
    ("foot_r", "shin_r", "r_an", "r_toe"),
]
REGION = {"skin": 0, "jersey": 1, "shorts": 2, "hair": 3}


def joints_3d(j2d, px, extent, cy):
    s = extent / px
    c = px / 2.0
    f = {n: np.array(p) for n, p in zip(KP, j2d["front"]["xy"])}
    r = {n: np.array(p) for n, p in zip(KP, j2d["side"]["xy"])}   # camera on +X: sees the right side
    lft = {n: np.array(p) for n, p in zip(KP, j2d["left"]["xy"])}  # camera on -X: sees the left side
    out = {}
    for n in KP:
        x = -(f[n][0] - c) * s
        y = cy - (f[n][1] - c) * s
        if n.startswith("r_"):
            z = -(r[n][0] - c) * s
            y2 = cy - (r[n][1] - c) * s
        elif n.startswith("l_"):
            z = (lft[n][0] - c) * s
            y2 = cy - (lft[n][1] - c) * s
        else:
            z = 0.5 * (-(r[n][0] - c) * s + (lft[n][0] - c) * s)
            y2 = y
        out[n] = np.array([x, 0.5 * (y + y2), z])
    return out


def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / max(ab @ ab, 1e-9), 0.0, 1.0)
    return np.linalg.norm(p - (a + np.outer(t, ab)), axis=1), t


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mesh")
    ap.add_argument("joints2d")
    ap.add_argument("out")
    ap.add_argument("--px", type=float, default=1024)
    ap.add_argument("--extent", type=float, default=2.0)
    ap.add_argument("--center-y", type=float, default=0.75)
    ap.add_argument("--hem", type=float, default=None,
                    help="height of the shirt's hem in metres (default: a little above the hips)")
    a = ap.parse_args()

    m = trimesh.load(a.mesh, force="mesh", process=False)
    V = np.asarray(m.vertices, dtype=np.float64)
    F = np.asarray(m.faces, dtype=np.int64)
    try:
        N = file_normals(a.mesh)   # the model's own normals; trimesh recomputes them on load
    except (KeyError, SystemExit):
        N = np.asarray(m.vertex_normals, dtype=np.float64)
    uv = getattr(m.visual, "uv", None)
    # Textured models split vertices along UV seams. Rig the welded mesh, so the copies of a
    # vertex get the same bones and weights and the seams never open, then copy back.
    V_all, F_all = V, F
    key = np.round(V / 1e-5).astype(np.int64)
    _, first, weld = np.unique(key, axis=0, return_index=True, return_inverse=True)
    weld = weld.reshape(-1)
    V = V_all[first]
    F = weld[F_all]
    J = joints_3d(json.load(open(a.joints2d)), a.px, a.extent, a.center_y)

    # Pull limb joints onto the middle of the limb: average the vertices in a thin slice
    # around each joint, so a keypoint on the silhouette edge does not leave the bone outside.
    for n in ["l_sh", "r_sh", "l_el", "r_el", "l_wr", "r_wr", "l_kn", "r_kn", "l_an", "r_an", "l_hip", "r_hip"]:
        d = np.linalg.norm(V - J[n], axis=1)
        near = V[d < 0.07]
        if len(near) > 10:
            J[n] = 0.5 * J[n] + 0.5 * near.mean(axis=0)

    # Derived joints.
    J["pelvis"] = 0.5 * (J["l_hip"] + J["r_hip"])
    sh_mid = 0.5 * (J["l_sh"] + J["r_sh"])
    J["neck"] = sh_mid + np.array([0, 0.03, 0])
    J["spine1"] = J["pelvis"] + (J["neck"] - J["pelvis"]) * 0.3
    J["chest"] = J["pelvis"] + (J["neck"] - J["pelvis"]) * 0.62
    ear_mid = 0.5 * (J["l_ear"] + J["r_ear"])
    J["head"] = ear_mid + np.array([0, -0.06, 0])
    top = V[np.argmax(V[:, 1])]
    J["head_top"] = np.array([J["head"][0], top[1], J["head"][2]])
    for side in "lr":
        # Hands and toes: the far end of the mesh beyond the wrist and ankle.
        wr, el = J[f"{side}_wr"], J[f"{side}_el"]
        dirv = (wr - el) / np.linalg.norm(wr - el)
        near = V[np.linalg.norm(V - wr, axis=1) < 0.22]
        proj = (near - wr) @ dirv
        J[f"{side}_hand"] = wr + dirv * max(0.08, np.percentile(proj, 95))
        an = J[f"{side}_an"]
        near = V[(np.linalg.norm(V - an, axis=1) < 0.3) & (V[:, 1] < an[1] + 0.02)]
        fwd = near[np.argmin(near[:, 2])]   # model faces -Z
        J[f"{side}_toe"] = np.array([fwd[0], max(0.03, fwd[1]), fwd[2]])

    names = [b[0] for b in BONES]
    heads = np.array([J[b[2]] for b in BONES])
    tails = np.array([J[b[3]] for b in BONES])
    parent = [names.index(b[1]) if b[1] else -1 for b in BONES]

    # Nearest bone per vertex.
    D = np.zeros((len(V), len(BONES)))
    T = np.zeros((len(V), len(BONES)))
    for i in range(len(BONES)):
        D[:, i], T[:, i] = seg_dist(V, heads[i], tails[i])
    # The torso is wider than the limbs: give it a head start.
    for i, n in enumerate(names):
        if n in ("hips", "spine", "chest"):
            D[:, i] -= 0.06
        if n == "head":
            D[:, i] -= 0.03
    label = np.argmin(D, axis=1)

    # Stray islands: a small connected piece of one bone's vertices surrounded by another's.
    edges = trimesh.Trimesh(vertices=V, faces=F, process=False).edges_unique
    adj = [[] for _ in range(len(V))]
    for u, v in edges:
        adj[u].append(v)
        adj[v].append(u)
    for _ in range(3):
        seen = np.zeros(len(V), dtype=bool)
        for start in range(len(V)):
            if seen[start]:
                continue
            lab = label[start]
            comp, stack = [], [start]
            seen[start] = True
            while stack:
                u = stack.pop()
                comp.append(u)
                for w in adj[u]:
                    if not seen[w] and label[w] == lab:
                        seen[w] = True
                        stack.append(w)
            if len(comp) < 120:
                border = [label[w] for u in comp for w in adj[u] if label[w] != lab]
                if border:
                    label[comp] = max(set(border), key=border.count)

    # Weights: own bone, blended with the parent near the joint and the child near the tip.
    children = {i: [k for k, p in enumerate(parent) if p == i] for i in range(len(BONES))}
    bones4 = np.zeros((len(V), 4), dtype=np.int32)
    weights4 = np.zeros((len(V), 4), dtype=np.float32)
    for vi in range(len(V)):
        b = label[vi]
        t = T[vi, b]
        ws = {b: 1.0}
        if t < 0.22 and parent[b] >= 0 and names[b] not in ("upperarm_l", "upperarm_r", "thigh_l", "thigh_r") or \
                (t < 0.12 and parent[b] >= 0):
            k = 0.5 * (1.0 - t / (0.22 if t < 0.22 else 0.12))
            ws[parent[b]] = k
            ws[b] = 1.0 - k
        if t > 0.85 and len(children[b]) == 1:
            c = children[b][0]
            k = 0.5 * (t - 0.85) / 0.15
            ws[c] = ws.get(c, 0.0) + k
            ws[b] -= k
        items = sorted(ws.items(), key=lambda x: -x[1])[:4]
        tot = sum(w for _, w in items)
        for j, (bi, w) in enumerate(items):
            bones4[vi, j] = bi
            weights4[vi, j] = w / tot

    # Regions for kit colours.
    hem = a.hem if a.hem is not None else J["spine1"][1] + 0.02
    region = np.full(len(V), REGION["skin"], dtype=np.int32)
    for vi in range(len(V)):
        n = names[label[vi]]
        t = T[vi, label[vi]]
        if n in ("spine", "chest"):
            # The neck rises out of the collar.
            nd = J["head"] - J["neck"]
            along = (V[vi] - J["neck"]) @ nd / (nd @ nd)
            near_neck = np.linalg.norm(V[vi] - (J["neck"] + nd * np.clip(along, 0, 1))) < 0.075
            region[vi] = REGION["skin"] if (along > -0.15 and near_neck) else REGION["jersey"]
        elif n.startswith("upperarm") and t < 0.42:
            region[vi] = REGION["jersey"]
        elif n == "hips":
            region[vi] = REGION["shorts"] if V[vi, 1] < hem else REGION["jersey"]
        elif n.startswith("thigh") and t < 0.6:
            region[vi] = REGION["shorts"]
        elif n == "head":
            ear_y = 0.5 * (J["l_ear"][1] + J["r_ear"][1])
            front = J["nose"][2]
            if V[vi, 1] > ear_y + 0.07 or (V[vi, 1] > ear_y - 0.02 and V[vi, 2] > front + 0.17):
                region[vi] = REGION["hair"]

    out = {
        "source": a.mesh.split("/")[-1],
        "bones": [{"name": n, "parent": parent[i], "head": heads[i].round(4).tolist(), "tail": tails[i].round(4).tolist()}
                  for i, n in enumerate(names)],
        "vertices": V_all.astype(np.float32).round(4).flatten().tolist(),
        "normals": N.astype(np.float32).round(3).flatten().tolist(),
        "indices": F_all.flatten().tolist(),
        "bones4": bones4[weld].flatten().tolist(),
        "weights4": weights4[weld].round(3).flatten().tolist(),
        "region": region[weld].tolist(),
        "height": float(V[:, 1].max()),
    }
    if uv is not None and len(uv) == len(V_all):
        out["uvs"] = np.column_stack([uv[:, 0], 1.0 - uv[:, 1]]).astype(np.float32).round(5).flatten().tolist()
    json.dump(out, open(a.out, "w"), separators=(",", ":"))
    counts = np.bincount(label, minlength=len(BONES))
    print("bones:", {n: int(c) for n, c in zip(names, counts)})
    print("regions:", {k: int((region == v).sum()) for k, v in REGION.items()})
    for n in ("pelvis", "neck", "head", "l_sh", "r_sh", "l_kn", "r_kn", "l_an", "r_an", "l_toe", "r_toe"):
        print(n, J[n].round(3))


if __name__ == "__main__":
    main()

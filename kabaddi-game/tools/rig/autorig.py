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
    # The pose model sometimes takes the front view of a faceless render for a back view and swaps left
    # and right, or swaps them for the lower legs or arms alone. The model faces the camera, so its left
    # is on the right of the picture: put the shoulders and hips there, then keep each knee and ankle on
    # its hip's side of the body, and each elbow and wrist on its shoulder's.
    for anchor, parts in (("hip", ("kn", "an")), ("sh", ("el", "wr"))):
        if f["l_" + anchor][0] < f["r_" + anchor][0]:
            f["l_" + anchor], f["r_" + anchor] = f["r_" + anchor], f["l_" + anchor]
            print("swapped left and right", anchor, "in the front view")
        side = 1.0
        for part in parts:
            if np.sign(f["l_" + part][0] - f["r_" + part][0]) == -side:
                f["l_" + part], f["r_" + part] = f["r_" + part], f["l_" + part]
                print("swapped left and right", part, "in the front view")
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


def arms_from_mesh(J, V):
    """With the arms held out, the pose model sometimes loses them (both wrists on one side, or elbows by
    the chest). Each arm then comes from the mesh: the hand is the far end of the body on that side, the
    shoulder sits a tenth of the height out from the middle, and elbow and wrist go where an average arm
    has them (upper arm 0.186, forearm 0.146 and hand 0.108 of the height), on the middle of the arm."""
    H = V[:, 1].max() - V[:, 1].min()
    mid = 0.5 * (J["l_sh"] + J["r_sh"])
    hip_y = 0.5 * (J["l_hip"][1] + J["r_hip"][1])
    for side in "lr":
        sgn = np.sign(J[f"{side}_sh"][0] - mid[0]) or (1.0 if side == "l" else -1.0)
        lat = (V[:, 0] - mid[0]) * sgn
        reach = lat.max()
        if reach < 0.3 * H:
            continue   # arms down by the sides: the pose model finds those well
        sh, el, wr = (J[f"{side}_{k}"] for k in ("sh", "el", "wr"))
        sh_lat, el_lat, wr_lat = ((p[0] - mid[0]) * sgn for p in (sh, el, wr))
        if wr_lat > reach - 0.2 * H and sh_lat < el_lat < wr_lat:
            continue
        sh_lat = max(sh_lat, 0.1 * H)
        arm = V[(lat > sh_lat + 0.04) & (V[:, 1] > hip_y + 0.1)]
        arm_lat = (arm[:, 0] - mid[0]) * sgn

        def centre(t):
            near = arm[np.abs(arm_lat - t) < 0.012]
            return near.mean(axis=0) if len(near) else None

        span = reach - sh_lat
        J[f"{side}_sh"] = np.array([mid[0] + sgn * sh_lat, sh[1], sh[2]])
        for k, frac in (("el", 0.186 / 0.44), ("wr", 0.332 / 0.44)):
            c = centre(sh_lat + span * frac)
            if c is not None:
                J[f"{side}_{k}"] = c
        print(f"{side} arm from the mesh: elbow {J[f'{side}_el'].round(3)}, wrist {J[f'{side}_wr'].round(3)}")


def palm_normal(P, wr, tip, side):
    """Which way a hand's palm faces, from where its thumb is: across the hand the thumb sticks out near the
    base on one side, and the palm faces follow from that side and which hand it is (the model faces -Z)."""
    length = np.linalg.norm(tip - wr)
    d = (tip - wr) / length
    Q = P - wr
    along = Q @ d
    perp = Q - np.outer(along, d)
    lateral = np.linalg.svd(perp - perp.mean(axis=0), full_matrices=False)[2][0]
    lateral = lateral - d * (lateral @ d)
    lateral /= np.linalg.norm(lateral)
    base = (along > 0.12 * length) & (along < 0.55 * length)
    reach = perp[base] @ lateral if base.any() else perp @ lateral
    thumb = lateral if reach.max() > -reach.min() else -lateral
    n = np.cross(thumb, d) if side == "r" else np.cross(d, thumb)
    return n / np.linalg.norm(n)


def rotate(points, origin, axis, angles):
    """Rotate each point about the line through origin along axis by its own angle (Rodrigues)."""
    v = points - origin
    c, s_ = np.cos(angles)[:, None], np.sin(angles)[:, None]
    k = axis[None, :]
    return origin + v * c + np.cross(k, v) * s_ + k * (v @ axis)[:, None] * (1 - c)


def smoothstep(x, a, b):
    w = float(np.clip((x - a) / (b - a), 0.0, 1.0))
    return w * w * (3 - 2 * w)


def move_weight(bones4, weights4, vi, src, dst, frac):
    """Move frac of vertex vi's weight on bone src to bone dst (into a free slot of the four)."""
    if frac <= 0.0:
        return
    for j in range(4):
        if bones4[vi, j] == src and weights4[vi, j] > 0:
            moved = weights4[vi, j] * frac
            free = [k for k in range(4) if weights4[vi, k] == 0 and k != j]
            if free:
                weights4[vi, j] -= moved
                bones4[vi, free[0]] = dst
                weights4[vi, free[0]] = moved
            return


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
    arms_from_mesh(J, V)

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

    # Palms down. Generated models usually hold their palms up or forward, which would leave the palms facing
    # forward when the game lowers the arms. Turn each forearm the way a real one turns (nothing at the
    # elbow, the full turn at the wrist) and the hand with it, until the palm faces down: lowered, the arms
    # then hang palms-in.
    for side in "lr":
        el, wr, tip = J[f"{side}_el"], J[f"{side}_wr"], J[f"{side}_hand"]
        axis = (wr - el) / np.linalg.norm(wr - el)
        fore_len = np.linalg.norm(wr - el)
        d_fore, _ = seg_dist(V, el, wr)
        d_hand, t_hand = seg_dist(V, wr, tip)
        others = np.full(len(V), np.inf)
        for b in BONES:
            if b[0] not in (f"forearm_{side}", f"hand_{side}"):
                others = np.minimum(others, seg_dist(V, J[b[2]], J[b[3]])[0])
        hand = (d_hand < others) & (d_hand <= d_fore)
        fore = (d_fore < others) & ~hand
        if hand.sum() < 30:
            continue
        n = palm_normal(V[hand], wr, tip, side)
        n_p = n - axis * (n @ axis)
        want = np.array([0.0, -1.0, 0.0])
        want = want - axis * (want @ axis)
        if np.linalg.norm(n_p) < 1e-3 or np.linalg.norm(want) < 1e-3:
            continue
        n_p /= np.linalg.norm(n_p)
        want /= np.linalg.norm(want)
        phi = float(np.arctan2(axis @ np.cross(n_p, want), n_p @ want))
        if abs(phi) < np.radians(20):
            continue
        s_along = np.clip(((V - el) @ axis) / fore_len, 0.0, 1.0)
        ramp = np.clip((s_along - 0.1) / 0.9, 0.0, 1.0)
        ramp = ramp * ramp * (3 - 2 * ramp)
        ang = np.where(hand, phi, np.where(fore, phi * ramp, 0.0))
        moved = ang != 0.0
        V[moved] = rotate(V[moved], el, axis, ang[moved])
        ang_all = ang[weld]
        moved_all = ang_all != 0.0
        V_all[moved_all] = rotate(V_all[moved_all], el, axis, ang_all[moved_all])
        N[moved_all] = rotate(N[moved_all], np.zeros(3), axis, ang_all[moved_all])
        J[f"{side}_hand"] = rotate(tip[None, :], el, axis, np.array([phi]))[0]
        print(f"turned the {side} forearm {np.degrees(phi):.0f} degrees to bring the palm down")

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
    # The face, jaw and any beard turn with the head, all of them: whatever is well in front of the neck
    # and above the shoulders is the head's, so a beard does not stay behind and stretch when the head turns.
    head_i, nk = names.index("head"), J["neck"]
    face = ((V[:, 1] > nk[1] + 0.01) & (V[:, 2] < nk[2] - 0.07) & (np.abs(V[:, 0] - nk[0]) < 0.09)
            & np.isin(label, [names.index("neck"), names.index("chest")]))
    label[face] = head_i
    print(f"face: {int(face.sum())} vertices in front of the neck go with the head")

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
        if face[vi] or (names[b] == "head" and (V[vi, 1] > J["head"][1] or V[vi, 2] < nk[2] - 0.03)):
            t = 0.5   # wholly the head's: the face never lags behind a turning head; only the neck blends
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

    # Fingers: a bone from the knuckles to the fingertips of each hand, so the game can curl them. The
    # hand's vertices past the knuckles move with it, blending in across the knuckles. Its "palm" is the
    # way the fingers curl. It comes from the thumb: across the hand, the thumb sticks out near the base on
    # one side, and which way the palm faces follows from that side and which hand it is (the model faces -Z).
    palms = {}
    for side in "lr":
        hi = names.index(f"hand_{side}")
        wr, tip = heads[hi], tails[hi]
        sel = label == hi
        n = palm_normal(V[sel], wr, tip, side)
        print(f"hand_{side}: palm faces {'down' if n[1] < -0.5 else 'up' if n[1] > 0.5 else 'sideways'} {n.round(2).tolist()}")
        # Two finger bones, knuckles to mid-finger and mid-finger to the tips, so a curl rounds the
        # fingers rather than bending them stiffly at the knuckles.
        fi = len(names)
        names += [f"fingers_{side}", f"fingertips_{side}"]
        parent += [hi, fi]
        mid = wr + (tip - wr) * 0.72
        heads = np.vstack([heads, wr + (tip - wr) * 0.45, mid])
        tails = np.vstack([tails, mid, tip])
        palms[fi] = n
        palms[fi + 1] = n
        for vi in np.where(sel)[0]:
            t = T[vi, hi]
            move_weight(bones4, weights4, vi, hi, fi, smoothstep(t, 0.38, 0.55))
            move_weight(bones4, weights4, vi, fi, fi + 1, smoothstep(t, 0.66, 0.80))
    print("palms:", {names[k]: v.round(2).tolist() for k, v in palms.items()})

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
        "bones": [dict({"name": n, "parent": parent[i], "head": heads[i].round(4).tolist(), "tail": tails[i].round(4).tolist()},
                       **({"palm": palms[i].round(4).tolist()} if i in palms else {}))
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

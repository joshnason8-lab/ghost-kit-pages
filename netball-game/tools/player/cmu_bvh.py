#!/usr/bin/env python3
"""CMU motion capture (BVH) to the game's poses: tools/player/README.md, "Motion capture".

    python3 -I tools/player/cmu_bvh.py BVH_DIR [OUT_JSON]

Reads the CMU clips listed in CLIPS (from BVH_DIR, as fetched by fetch_cmu.sh), retargets each onto the game's
seventeen bones (ToonBody.BONES, the owner's model's offsets from assets/player/hero.json), trims, resamples to
30 fps, pins the planted feet, and writes assets/player/mocap.json (or OUT_JSON). Needs python3 and numpy.
"""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", ".."))

# ---------------------------------------------------------------- quaternions (w, x, y, z), numpy arrays

def qmul(a, b):
    aw, ax, ay, az = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    bw, bx, by, bz = b[..., 0], b[..., 1], b[..., 2], b[..., 3]
    return np.stack([aw * bw - ax * bx - ay * by - az * bz,
                     aw * bx + ax * bw + ay * bz - az * by,
                     aw * by - ax * bz + ay * bw + az * bx,
                     aw * bz + ax * by - ay * bx + az * bw], -1)


def qinv(q):
    return q * np.array([1.0, -1.0, -1.0, -1.0])


def qrot(q, v):
    """Rotates vectors v (..., 3) by q (..., 4)."""
    qv = np.concatenate([np.zeros(v.shape[:-1] + (1,)), v], -1)
    return qmul(qmul(q, qv), qinv(q))[..., 1:]


def qaxis(axis, ang):
    """Rotations about a unit axis by angles ang (radians, an array)."""
    ang = np.asarray(ang, dtype=float)
    s = np.sin(ang * 0.5)
    return np.stack([np.cos(ang * 0.5), axis[0] * s, axis[1] * s, axis[2] * s], -1)


def qarc(a, b):
    """The shortest rotation taking unit direction a onto b."""
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    c = np.cross(a, b)
    d = float(np.dot(a, b))
    if d < -0.99999:
        ax = np.cross(a, [1.0, 0, 0])
        if np.linalg.norm(ax) < 1e-6:
            ax = np.cross(a, [0, 1.0, 0])
        ax /= np.linalg.norm(ax)
        return np.array([0.0, ax[0], ax[1], ax[2]])
    q = np.array([1.0 + d, c[0], c[1], c[2]])
    return q / np.linalg.norm(q)


def qnorm(q):
    return q / np.linalg.norm(q, axis=-1, keepdims=True)


def qslerp(a, b, t):
    d = float(np.dot(a, b))
    if d < 0:
        b = -b
        d = -d
    if d > 0.9995:
        return qnorm(a + (b - a) * t)
    th = math.acos(d)
    return (math.sin((1 - t) * th) * a + math.sin(t * th) * b) / math.sin(th)


def q_to_euler_yxz(q):
    """Godot's Basis.get_euler(EULER_ORDER_YXZ) in degrees (x, y, z): R = Ry * Rx * Rz."""
    w, x, y, z = q
    # The rotation matrix.
    m = np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    m12 = m[1][2]
    if m12 < 1 - 1e-7:
        if m12 > -(1 - 1e-7):
            ex = math.asin(-m12)
            ey = math.atan2(m[0][2], m[2][2])
            ez = math.atan2(m[1][0], m[1][1])
        else:
            ex = math.pi * 0.5
            ey = math.atan2(m[0][1], m[0][0])
            ez = 0.0
    else:
        ex = -math.pi * 0.5
        ey = -math.atan2(m[0][1], m[0][0])
        ez = 0.0
    return [math.degrees(ex), math.degrees(ey), math.degrees(ez)]


def euler_yxz_to_q(e):
    """Degrees (x, y, z), Godot's EULER_ORDER_YXZ, to a quaternion."""
    qx = qaxis(np.array([1.0, 0, 0]), math.radians(e[0]))
    qy = qaxis(np.array([0, 1.0, 0]), math.radians(e[1]))
    qz = qaxis(np.array([0, 0, 1.0]), math.radians(e[2]))
    return qmul(qmul(qy, qx), qz)


# ---------------------------------------------------------------- BVH

class Bvh:
    """A BVH file: joints (name, parent, offset, channels), frames (n, channels), frame time."""

    def __init__(self, path):
        self.names, self.parents, self.offsets, self.chans = [], [], [], []
        with open(path) as f:
            toks = f.read().split()
        i = 0
        stack = []
        while toks[i] != "MOTION":
            t = toks[i]
            if t in ("ROOT", "JOINT"):
                self.names.append(toks[i + 1])
                self.parents.append(stack[-1] if stack else -1)
                self.offsets.append(None)
                self.chans.append([])
                i += 2
            elif t == "End":
                self.names.append(None)   # an end site: no channels
                self.parents.append(stack[-1])
                self.offsets.append(None)
                self.chans.append([])
                i += 2
            elif t == "{":
                stack.append(len(self.names) - 1)
                i += 1
            elif t == "}":
                stack.pop()
                i += 1
            elif t == "OFFSET":
                self.offsets[stack[-1]] = np.array([float(v) for v in toks[i + 1:i + 4]])
                i += 4
            elif t == "CHANNELS":
                n = int(toks[i + 1])
                self.chans[stack[-1]] = toks[i + 2:i + 2 + n]
                i += 2 + n
            else:
                i += 1
        nframes = int(toks[i + 2])
        self.dt = float(toks[i + 5])
        vals = np.array([float(v) for v in toks[i + 6:]])
        ncol = sum(len(c) for c in self.chans)
        self.frames = vals[:nframes * ncol].reshape(nframes, ncol)
        self.index = {n: k for k, n in enumerate(self.names) if n}

    def fk(self):
        """Every joint's world rotation (n, J, 4) and position (n, J, 3), per frame."""
        n = self.frames.shape[0]
        J = len(self.names)
        rot = np.zeros((n, J, 4))
        pos = np.zeros((n, J, 3))
        col = 0
        axes = {"X": np.array([1.0, 0, 0]), "Y": np.array([0, 1.0, 0]), "Z": np.array([0, 0, 1.0])}
        for j in range(J):
            local = np.tile([1.0, 0, 0, 0], (n, 1))
            trans = np.tile(self.offsets[j], (n, 1))
            for c in self.chans[j]:
                v = self.frames[:, col]
                col += 1
                if c.endswith("position"):
                    trans[:, "XYZ".index(c[0])] = v
                else:
                    local = qmul(local, qaxis(axes[c[0]], np.radians(v)))
            p = self.parents[j]
            if p < 0:
                rot[:, j] = local
                pos[:, j] = trans
            else:
                rot[:, j] = qmul(rot[:, p], local)
                pos[:, j] = pos[:, p] + qrot(rot[:, p], trans)
        return rot, pos


# ---------------------------------------------------------------- the game's skeleton

# ToonBody.BONES: name, parent (the owner's model's offsets come from hero.json).
BONES = [("hips", -1), ("spine", 0), ("chest", 1), ("neck", 2), ("head", 3),
         ("upperarm_l", 2), ("forearm_l", 5), ("hand_l", 6), ("upperarm_r", 2), ("forearm_r", 8), ("hand_r", 9),
         ("thigh_l", 0), ("shin_l", 11), ("foot_l", 12), ("thigh_r", 0), ("shin_r", 14), ("foot_r", 15)]
NAMES = [b[0] for b in BONES]
# Each game bone and the CMU joint whose turn carries the same segment.
SOURCE = {"hips": "Hips", "spine": "LowerBack", "chest": "Spine1", "neck": "Neck1", "head": "Head",
          "upperarm_l": "LeftArm", "forearm_l": "LeftForeArm", "hand_l": "LeftHand",
          "upperarm_r": "RightArm", "forearm_r": "RightForeArm", "hand_r": "RightHand",
          "thigh_l": "LeftUpLeg", "shin_l": "LeftLeg", "foot_l": "LeftFoot",
          "thigh_r": "RightUpLeg", "shin_r": "RightLeg", "foot_r": "RightFoot"}
# The segments whose rest directions differ (CMU stands in a T, its legs a little apart; the game's arms and legs
# hang straight): game bone -> (the game's segment, as the child bone whose offset it is; CMU's child joint).
SEGMENT = {"upperarm_l": ("forearm_l", "LeftForeArm"), "forearm_l": ("hand_l", "LeftHand"),
           "hand_l": ("hand_l", "LeftHand"),
           "upperarm_r": ("forearm_r", "RightForeArm"), "forearm_r": ("hand_r", "RightHand"),
           "hand_r": ("hand_r", "RightHand"),
           "thigh_l": ("shin_l", "LeftLeg"), "shin_l": ("foot_l", "LeftFoot"),
           "thigh_r": ("shin_r", "RightLeg"), "shin_r": ("foot_r", "RightFoot")}
MIRROR = [NAMES.index(n[:-2] + ("_r" if n.endswith("_l") else "_l")) if n[-2:] in ("_l", "_r") else i
          for i, n in enumerate(NAMES)]
Y = np.array([0, 1.0, 0])


class Target:
    """The owner's model's skeleton: each bone's offset (m) from hero.json; every rest turn the identity."""

    def __init__(self, hero_json):
        with open(hero_json) as f:
            off = json.load(f)["offsets"]
        self.off = np.array([off[n] for n in NAMES], dtype=float)
        self.parent = [b[1] for b in BONES]
        self.idx = {n: i for i, n in enumerate(NAMES)}
        self.leg = np.linalg.norm(self.off[self.idx["shin_l"]]) + np.linalg.norm(self.off[self.idx["foot_l"]])
        # The ankle's height standing at rest (soles at y = 0, ToonBody's local space).
        self.ankle_rest = float(self.off[0][1] + self.off[self.idx["thigh_l"]][1] + self.off[self.idx["shin_l"]][1]
                                + self.off[self.idx["foot_l"]][1])

    def fk(self, local, root):
        """local (n, 17, 4), root (n, 3) the hips' shift from rest: world turns and positions (n, 17, ...)."""
        n = local.shape[0]
        G = np.zeros((n, 17, 4))
        P = np.zeros((n, 17, 3))
        for j in range(17):
            p = self.parent[j]
            if p < 0:
                G[:, j] = local[:, j]
                P[:, j] = self.off[j] + root
            else:
                G[:, j] = qmul(G[:, p], local[:, j])
                P[:, j] = P[:, p] + qrot(G[:, p], np.tile(self.off[j], (n, 1)))
        return G, P


# ---------------------------------------------------------------- retargeting

def heading(q):
    """The yaw (radians; 0 faces +Z) of rotations q: where their +Z points, on the floor."""
    f = qrot(q, np.broadcast_to(np.array([0, 0, 1.0]), q.shape[:-1] + (3,)))
    return np.arctan2(f[..., 0], f[..., 2])


def retarget(bvh, tgt, a, b):
    """Frames a..b (inclusive) of a BVH on the game's bones: world turns G (n, 17, 4) as the game's bones would have
    them, and CMU's joint positions scaled to the game's legs (n, J, 3), both in CMU's world."""
    rot, pos = bvh.fk()
    rot, pos = rot[a:b + 1], pos[a:b + 1]
    ix = bvh.index
    src_leg = np.linalg.norm(bvh.offsets[ix["LeftLeg"]]) + np.linalg.norm(bvh.offsets[ix["LeftFoot"]])
    s = tgt.leg / src_leg
    n = rot.shape[0]
    G = np.zeros((n, 17, 4))
    for j, name in enumerate(NAMES):
        corr = np.array([1.0, 0, 0, 0])
        if name in SEGMENT:
            child, schild = SEGMENT[name]
            corr = qarc(tgt.off[tgt.idx[child]], bvh.offsets[ix[schild]])
        G[:, j] = qmul(rot[:, ix[SOURCE[name]]], np.tile(corr, (n, 1)))
    return G, pos * s, s


def to_local(tgt, G):
    local = np.zeros_like(G)
    for j in range(17):
        p = tgt.parent[j]
        local[:, j] = G[:, j] if p < 0 else qmul(qinv(G[:, p]), G[:, j])
    return fix_sign(qnorm(local))


def fix_sign(q):
    """Keeps each bone's quaternions in one hemisphere from frame to frame."""
    q = q.copy()
    for i in range(1, q.shape[0]):
        flip = np.sum(q[i] * q[i - 1], -1) < 0
        q[i][flip] *= -1
    return q


def resample(arrs, src_fps, fps=30.0):
    """Each (array (n, ...), is_quaternion) from src_fps to fps: quaternions slerped, the rest lerped."""
    n = arrs[0][0].shape[0]
    m = int(round((n - 1) / src_fps * fps)) + 1
    out = []
    for arr, is_q in arrs:
        o = np.zeros((m,) + arr.shape[1:])
        for k in range(m):
            f = min(k / fps * src_fps, n - 1)
            i = min(int(f), n - 2)
            w = f - i
            if is_q:
                for j in range(arr.shape[1]):
                    o[k, j] = qslerp(arr[i, j], arr[i + 1, j], w)
            else:
                o[k] = arr[i] * (1 - w) + arr[i + 1] * w
        out.append(o)
    return out


def contacts(ank, fps, h_max=0.05, v_max=0.35, min_len=3):
    """Where an ankle (n, 3; world, m) is planted: low and still. Short gaps and blips are cleaned up."""
    h = ank[:, 1] - np.percentile(ank[:, 1], 5)
    v = np.zeros(len(ank))
    v[1:] = np.linalg.norm(np.diff(ank[:, [0, 2]], axis=0), axis=1) * fps
    v[0] = v[1]
    on = (h < h_max) & (v < v_max)
    on = _flip_short(on, True, 2)
    on = _flip_short(on, False, min_len)
    return on


def _flip_short(on, fill, n):
    """fill True: closes gaps shorter than n frames between planted runs; False: drops planted runs shorter than n."""
    on = on.copy()
    for (i, j) in runs(~on if fill else on):
        if j - i < n and (not fill or (i > 0 and j < len(on))):
            on[i:j] = fill
    return on


def runs(on):
    """The runs of True in a boolean array: [(start, end)...]."""
    out = []
    i = 0
    while i < len(on):
        if on[i]:
            j = i
            while j < len(on) and on[j]:
                j += 1
            out.append((i, j))
            i = j
        else:
            i += 1
    return out


# ---------------------------------------------------------------- two-bone IK (the legs)

def leg_ik(tgt, local, root, side, goal):
    """Turns one frame's thigh and shin (local (17, 4), root (3,)) so the ankle reaches goal (body space), the knee
    in the plane it was in; the foot keeps its turn in the world. Returns the new local turns."""
    th, sh, ft = tgt.idx["thigh_" + side], tgt.idx["shin_" + side], tgt.idx["foot_" + side]
    G, P = tgt.fk(local[None], root[None])
    G, P = G[0], P[0]
    H, K, A = P[th], P[sh], P[ft]
    a = np.linalg.norm(tgt.off[sh])
    b = np.linalg.norm(tgt.off[ft])
    d_vec = goal - H
    d = min(max(np.linalg.norm(d_vec), abs(a - b) + 1e-4), (a + b) * 0.999)
    u = d_vec / max(np.linalg.norm(d_vec), 1e-9)
    w = (K - H) - np.dot(K - H, u) * u
    if np.linalg.norm(w) < 1e-4:
        w = qrot(G[th], np.array([0, 0, 1.0]))
        w = w - np.dot(w, u) * u
    w /= np.linalg.norm(w)
    ca = min(1.0, max(-1.0, (a * a + d * d - b * b) / (2 * a * d)))
    K2 = H + a * (ca * u + math.sqrt(1 - ca * ca) * w)
    T = H + u * d
    r1 = qarc(K - H, K2 - H)
    G_th = qmul(r1, G[th])
    A1 = K2 + qrot(r1, A - K)
    r2 = qarc(A1 - K2, T - K2)
    G_sh = qmul(r2, qmul(r1, G[sh]))
    out = local.copy()
    out[th] = qmul(qinv(G[0]), G_th)
    out[sh] = qmul(qinv(G_th), G_sh)
    out[ft] = qmul(qinv(G_sh), G[ft])
    return out


# ---------------------------------------------------------------- a clip

def build(spec, bvh_dir, tgt):
    """One clip of CLIPS, ready for the game: its turns, the hips' shift, the planted feet, its travel."""
    bvh = Bvh(os.path.join(bvh_dir, spec["src"] + ".bvh"))
    src_fps = 1.0 / bvh.dt
    a = int(round(spec["t0"] * src_fps))
    b = int(round(spec["t1"] * src_fps))
    G, pos, s = retarget(bvh, tgt, a, b)
    ix = bvh.index
    track = spec.get("yaw", "const") == "track"
    # Her heading: the clip's mean ("const": her own sway stays in the clip) or frame by frame ("track": the game
    # turns her, so the clip keeps only the turn of each bone against the hips' heading).
    hd = heading(G[:, 0])
    if track:
        hd = np.unwrap(hd)
    else:
        hd = np.full_like(hd, math.atan2(np.mean(np.sin(hd)), np.mean(np.cos(hd))))
    hd = hd + math.radians(spec.get("turn", 0.0))
    unturn = qaxis(Y, -hd)
    G = qmul(np.repeat(unturn[:, None], 17, 1), G)
    # Positions turned by the same heading (about CMU's origin; the anchor is taken off below).
    pos = qrot(np.repeat(unturn[:, None], pos.shape[1], 1), pos)
    local = to_local(tgt, G)
    hips, ank_l, ank_r = pos[:, ix["Hips"]], pos[:, ix["LeftFoot"]], pos[:, ix["RightFoot"]]
    local, hips, ank_l, ank_r, hd = resample([(local, True), (hips, False), (ank_l, False), (ank_r, False),
                                             (hd[:, None], False)], src_fps)
    hd = hd[:, 0] - hd[0, 0]
    n = local.shape[0]
    fps = 30.0
    # The heading's change in world terms: a "track" clip's positions are turned back into the world by it.
    spin = qaxis(Y, hd if track else np.zeros(n))
    ank = {"l": ank_l, "r": ank_r}
    if spec.get("mirror"):
        local = fix_sign(local[:, MIRROR] * np.array([1.0, 1.0, -1.0, -1.0]))
        mx = np.array([-1.0, 1, 1])
        hips = hips * mx
        ank = {"l": ank["r"] * mx, "r": ank["l"] * mx}
        hd = -hd
        spin = qaxis(Y, hd if track else np.zeros(n))
    world = {k: qrot(spin, v) for k, v in ank.items()}
    world_hips = qrot(spin, hips)
    plant = {side: contacts(world[side], fps) for side in "lr"}
    for side, rng in spec.get("plant", {}).items():
        for (f0, f1) in rng:
            plant[side][f0:f1] = True
    for side, rng in spec.get("free", {}).items():
        for (f0, f1) in rng:
            plant[side][f0:f1] = False
    # The anchor (where the game puts the player): "cycle", along a straight line through the cycle; "stop", along
    # her path forward, never back; "foot_l"/"foot_r", that planted foot (a pivot), under the player; "still", the
    # hips' mean. What is left of the hips' movement is a shift of the body.
    mode = spec["mode"]
    if mode == "stop" and "turn" not in spec:
        # Her path straight ahead: the clip turned so the hips go from start to end along +Z (as the game's player
        # does, facing the way she runs).
        D = world_hips[-1] - world_hips[0]
        ang = math.degrees(math.atan2(D[0], D[2])) * (-1.0 if spec.get("mirror") else 1.0)   # turned before mirroring
        return build(dict(spec, turn=round(ang, 1)), bvh_dir, tgt)
    travel = np.zeros(n)
    if mode == "cycle":
        V = world_hips[-1] - world_hips[0]
        V[1] = 0
        anchor = world_hips[0] * np.array([1, 0, 1]) + np.outer(np.arange(n) / (n - 1), V)
        travel = np.arange(n) / (n - 1) * np.linalg.norm(V)
        spec = dict(spec, dir=[round(float(V[0] / np.linalg.norm(V)), 3), round(float(V[2] / np.linalg.norm(V)), 3)])
    elif mode == "stop":
        z = np.maximum.accumulate(world_hips[:, 2] - world_hips[0, 2])
        anchor = np.stack([np.full(n, world_hips[0, 0]), np.zeros(n), world_hips[0, 2] + z], 1)
        travel = z
    elif mode.startswith("foot_"):
        side = mode[-1]
        f = world[side][plant[side]] if plant[side].any() else world[side]
        anchor = np.tile(f.mean(0) * np.array([1, 0, 1]), (n, 1))
    else:
        anchor = np.tile(world_hips.mean(0) * np.array([1, 0, 1]), (n, 1))
    root = qrot(qinv(spin), world_hips - anchor) - tgt.off[0]
    if mode == "cycle":
        # Close the loop: the last frame becomes the first, the difference spread over the cycle.
        for j in range(17):
            err = qmul(local[0, j], qinv(local[-1, j]))
            for f in range(n):
                local[f, j] = qnorm(qmul(qslerp(np.array([1.0, 0, 0, 0]), err, f / (n - 1)), local[f, j]))
        root += np.outer(np.arange(n) / (n - 1), root[0] - root[-1])
    # The height: her planted ankles at the model's ankle height at rest.
    _, P = tgt.fk(local, np.zeros((n, 3)))
    samples = [P[plant[s], tgt.idx["foot_" + s], 1] + root[plant[s], 1] for s in "lr" if plant[s].any()]
    if samples:
        root[:, 1] -= np.median(np.concatenate(samples)) - tgt.ankle_rest
    # The foot locks: each planted run held where it is in the world, the legs turned to reach it.
    _, P = tgt.fk(local, root)
    goals, weight, plant_at = {}, {}, {}
    for side in "lr":
        foot = P[:, tgt.idx["foot_" + side]]
        wfoot = qrot(spin, foot) + anchor
        g = foot.copy()
        wgt = np.zeros(n)
        rr = runs(plant[side])
        for (f0, f1) in rr:
            L = wfoot[f0:f1].mean(0)
            if mode == "cycle" and len(rr) > 1 and rr[0][0] == 0 and rr[-1][1] == n:
                # A plant across the loop's seam: one place, the end's a cycle's travel on from the start's.
                (a0, a1), (b0, b1) = rr[0], rr[-1]
                V = anchor[-1] - anchor[0]
                L = np.concatenate([wfoot[a0:a1], wfoot[b0:b1] - V]).mean(0) + (V if f0 == b0 else 0)
            L[1] = tgt.ankle_rest
            if side not in plant_at:
                # Where the foot first comes down, against the player's position at that moment (m of the model).
                rel = qrot(qinv(spin[f0]), L - anchor[f0])
                plant_at[side] = [round(float(rel[0]), 3), round(float(rel[2]), 3)]
            for f in range(max(0, f0 - 3), min(n, f1 + 3)):
                wv = 1.0 if f0 <= f < f1 else 1.0 - ((f0 - f) if f < f0 else (f - f1 + 1)) / 4.0
                gl = qrot(qinv(spin[f]), L - anchor[f])
                if wv > wgt[f]:
                    g[f] = foot[f] * (1 - wv) + gl * wv
                    wgt[f] = wv
        goals[side], weight[side] = g, wgt
    # Lower the hips where a planted leg could not reach (no straight-leg pops), smoothly.
    reach = tgt.leg * 0.985
    drop = np.zeros(n)
    for side in "lr":
        hipj = P[:, tgt.idx["thigh_" + side]]
        for f in range(n):
            if weight[side][f] > 0:
                dv = goals[side][f] - hipj[f]
                hz = dv[0] ** 2 + dv[2] ** 2
                need = math.sqrt(reach ** 2 - hz) if hz < reach ** 2 else 0.0
                drop[f] = max(drop[f], -dv[1] - need)
    if drop.max() > 0:
        sm = np.convolve(np.pad(drop, 3, mode="edge"), np.ones(7) / 7, mode="valid")
        root[:, 1] -= np.maximum(sm, drop)
    out = local.copy()
    for f in range(n):
        for side in "lr":
            if weight[side][f] > 0:
                out[f] = leg_ik(tgt, out[f], root[f], side, goals[side][f])
    out = fix_sign(qnorm(out))
    return {"local": out, "root": root, "travel": travel, "plant": plant, "hd": hd, "spin": spin, "anchor": anchor,
            "scale": s, "n": n, "spec": spec, "plant_at": plant_at}


def slide_report(tgt, clip):
    """How far each planted foot slides on the floor as the game plays the clip (m): the worst of its planted runs."""
    _, P = tgt.fk(clip["local"], clip["root"])
    out = {}
    for side in "lr":
        world = qrot(clip["spin"], P[:, tgt.idx["foot_" + side]]) + clip["anchor"]
        worst = 0.0
        for (f0, f1) in runs(clip["plant"][side]):
            seg = world[f0:f1]
            worst = max(worst, float(np.max(np.linalg.norm(seg[:, [0, 2]] - seg[0, [0, 2]], axis=1))))
        out[side] = worst
    return out


def encode(clip):
    """The clip as the game reads it: a frame is the 17 turns (degrees, Euler YXZ as Godot's) then the hips' shift."""
    frames = []
    for f in range(clip["n"]):
        row = []
        for j in range(17):
            row += [round(v, 1) for v in q_to_euler_yxz(clip["local"][f, j])]
        row += [round(float(v), 3) for v in clip["root"][f]]
        frames.append(row)
    sp = clip["spec"]
    pl = clip["plant"]
    out = {"src": sp["src"], "fps": 30, "frames": frames,
           "plant": "".join("b" if pl["l"][f] and pl["r"][f] else "l" if pl["l"][f] else "r" if pl["r"][f] else "-"
                            for f in range(clip["n"]))}
    if sp["mode"] in ("cycle", "stop"):
        out["travel"] = [round(float(v), 3) for v in clip["travel"]]
    if sp["mode"] == "stop":
        out["plant_at"] = clip["plant_at"]
    if sp.get("yaw") == "track":
        out["turn"] = [round(math.degrees(float(v)), 1) for v in clip["hd"]]
    for k in ("loop", "dir", "use"):
        if k in sp:
            out[k] = sp[k]
    return out


# ---------------------------------------------------------------- the clips the game uses

# name: the CMU clip, its window (s), how it is anchored (build), its heading, and any fixes to the planted feet
# (30 fps frames of the window).
CLIPS = {
    # The defensive slide (basketball's, as netball's marking): one cycle of 102_27 "DefensiveMoveSideToSide", from
    # one push of the left foot to the next; as captured, and mirrored for the other way.
    "slide_right": {"src": "102_27", "t0": 0.767, "t1": 1.3, "mode": "cycle", "turn": 13.6},
    "slide_left": {"src": "102_27", "t0": 0.767, "t1": 1.3, "mode": "cycle", "turn": 13.6, "mirror": True},
    # The landing: 16_08 "run/jog, sudden stop", from the last stride in the air to both feet down: the right foot
    # lands, the left steps down beside it, and she stops on them (cut before she shuffles the right again).
    # Mirrored for a landing on the left foot.
    "land_r": {"src": "16_08", "t0": 0.80, "t1": 1.667, "mode": "stop", "plant": {"r": [[5, 27]]}},
    "land_l": {"src": "16_08", "t0": 0.80, "t1": 1.667, "mode": "stop", "mirror": True, "plant": {"l": [[5, 27]]}},
}


def main():
    bvh_dir = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(GAME, "assets", "player", "mocap.json")
    only = sys.argv[3].split(",") if len(sys.argv) > 3 else None
    tgt = Target(os.path.join(GAME, "assets", "player", "hero.json"))
    out = {"source": "CMU Graphics Lab Motion Capture Database, mocap.cs.cmu.edu (BVH conversion: B. Hahne)",
           "clips": {}}
    for name, spec in CLIPS.items():
        if only and name not in only:
            continue
        clip = build(spec, bvh_dir, tgt)
        sl = slide_report(tgt, clip)
        print("%-12s %-7s %5.2f-%5.2f s %3d frames  slide l %.3f r %.3f m  travel %.2f m" % (
            name, spec["src"], spec["t0"], spec["t1"], clip["n"], sl["l"], sl["r"], float(clip["travel"][-1])))
        for side in "lr":
            print("   %s %s" % (side, "".join("#" if v else "." for v in clip["plant"][side])))
        out["clips"][name] = encode(clip)
    with open(out_path, "w") as f:
        json.dump(out, f, separators=(",", ":"))
    print("wrote", out_path, os.path.getsize(out_path), "bytes")


if __name__ == "__main__":
    main()


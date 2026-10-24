#!/usr/bin/env python3
"""Retarget CMU motion capture (BVH) onto the game's seventeen-bone skeleton (game/body.gd) and write the compact
pose data the game plays (assets/anim/*.json).

The CMU Graphics Lab Motion Capture Database (mocap.cs.cmu.edu), BVH conversion by Bruce Hahne, fetched from the
GitHub mirror (https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/data/<SSS>/<SS>_<TT>.bvh). The raw
BVH files are not committed; only what this writes.

How:
- Forward kinematics on the BVH (channels Z Y X, applied in that order) gives every joint's position each frame.
- The clip is turned so its subject faces +Z with his left on +X (the game's convention), and moved so the root
  stays over the origin: root motion is dropped, because the game's movement system is the one writer of position.
  What is kept of it is the clip's speed, so the game can play it at the rate that matches the ground covered.
- Each bone's rotation (relative to its parent, the game's rest pose being the identity with arms and legs hanging
  down) is found from the recorded joints: the hips and the chest from the line of the hips and of the shoulders
  (their twist matters in a run), the spine halfway between, and every limb by the shortest turn that points it
  where the recorded limb points.
- Locomotion: one gait cycle is cut, from one left foot strike to the next, resampled to 30 a second and closed into
  a loop. Its length (metres a cycle, at the game's leg length) is written beside it.
- Each frame is written as Euler angles in degrees, in the order Godot's Basis.from_euler(YXZ) reads them (Body.apply),
  unwrapped over the clip so they interpolate smoothly.

Usage:
  python3 tools/mocap/bvh_retarget.py CLIP.bvh NAME (cycle|span START END) [--hit SEC]
"""
import json
import math
import pathlib
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "anim"
FPS = 30.0
GAME_LEG = 0.44 + 0.42          # the game's thigh + shin (game/body.gd BONES)
GAME_HIPS = 0.95


# ---------------------------------------------------------------- BVH

def parse(path):
    lines = pathlib.Path(path).read_text().split("\n")
    joints = []           # [name, parent index, offset, channels]
    stack = []
    i = 0
    while not lines[i].strip().startswith("MOTION"):
        t = lines[i].strip().split()
        if not t:
            i += 1
            continue
        if t[0] in ("ROOT", "JOINT"):
            joints.append([t[1], stack[-1] if stack else -1, None, []])
            pending = len(joints) - 1
        elif t[0] == "End":
            joints.append([joints[stack[-1]][0] + "_End", stack[-1], None, []])
            pending = len(joints) - 1
        elif t[0] == "{":
            stack.append(pending)
        elif t[0] == "}":
            stack.pop()
        elif t[0] == "OFFSET":
            joints[stack[-1]][2] = np.array([float(x) for x in t[1:4]])
        elif t[0] == "CHANNELS":
            joints[stack[-1]][3] = t[2:]
        i += 1
    n = int(lines[i + 1].split(":")[1])
    dt = float(lines[i + 2].split(":")[1])
    data = []
    for line in lines[i + 3:i + 3 + n]:
        if line.strip():
            data.append([float(x) for x in line.split()])
    return joints, np.array(data), dt


def rot(axis, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    if axis == "X":
        return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
    if axis == "Y":
        return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def fk(joints, frame):
    """World positions of every joint in one frame."""
    pos = [None] * len(joints)
    rots = [None] * len(joints)
    k = 0
    for j, (name, parent, off, ch) in enumerate(joints):
        local_t = off.copy()
        r = np.eye(3)
        for c in ch:
            v = frame[k]
            k += 1
            if c.endswith("position"):
                local_t = local_t + np.array([v if c[0] == "X" else 0, v if c[0] == "Y" else 0, v if c[0] == "Z" else 0])
            else:
                r = r @ rot(c[0], v)
        if parent < 0:
            pos[j] = local_t
            rots[j] = r
        else:
            pos[j] = pos[parent] + rots[parent] @ local_t
            rots[j] = rots[parent] @ r
    return {joints[j][0]: pos[j] for j in range(len(joints))}


# ---------------------------------------------------------------- the game's skeleton

BONES = ["hips", "spine", "chest", "neck", "head", "upperarm_l", "forearm_l", "hand_l", "upperarm_r", "forearm_r",
         "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
PARENT = {"spine": "hips", "chest": "spine", "neck": "chest", "head": "neck", "upperarm_l": "chest", "forearm_l": "upperarm_l",
          "hand_l": "forearm_l", "upperarm_r": "chest", "forearm_r": "upperarm_r", "hand_r": "forearm_r", "thigh_l": "hips",
          "shin_l": "thigh_l", "foot_l": "shin_l", "thigh_r": "hips", "shin_r": "thigh_r", "foot_r": "shin_r"}
# Each limb: the recorded segment it follows (from joint, to joint), and its direction at rest in the game.
DOWN = np.array([0.0, -1.0, 0.0])
UP = np.array([0.0, 1.0, 0.0])
FWD = np.array([0.0, 0.0, 1.0])
LIMBS = {
    "neck": ("Neck1", "Head", UP), "head": ("Head", "Head_End", UP),
    "upperarm_l": ("LeftArm", "LeftForeArm", DOWN), "forearm_l": ("LeftForeArm", "LeftHand", DOWN),
    "hand_l": ("LeftHand", "LeftHandIndex1", DOWN),
    "upperarm_r": ("RightArm", "RightForeArm", DOWN), "forearm_r": ("RightForeArm", "RightHand", DOWN),
    "hand_r": ("RightHand", "RightHandIndex1", DOWN),
    "thigh_l": ("LeftUpLeg", "LeftLeg", DOWN), "shin_l": ("LeftLeg", "LeftFoot", DOWN),
    "foot_l": ("LeftFoot", "LeftToeBase", np.array([0.0, -0.35, 1.0]) / np.linalg.norm([0.0, -0.35, 1.0])),
    "thigh_r": ("RightUpLeg", "RightLeg", DOWN), "shin_r": ("RightLeg", "RightFoot", DOWN),
    "foot_r": ("RightFoot", "RightToeBase", np.array([0.0, -0.35, 1.0]) / np.linalg.norm([0.0, -0.35, 1.0])),
}


# The upper arm and the thigh take their twist from the elbow's and the knee's plane, so the forearm and the shin
# bend about their own x like a hinge (the forearm toward the bone's +z, the shin toward its -z, as in game/moves.gd).
HINGE = {"upperarm_l": ("LeftHand", 1.0), "upperarm_r": ("RightHand", 1.0),
         "thigh_l": ("LeftFoot", -1.0), "thigh_r": ("RightFoot", -1.0)}


def hinge(swung, limb, child, sign):
    """The limb's world frame: -y along the limb, z turned toward the way the next segment bends. Nearly straight,
    the bend says little, so the plain swing's frame is kept."""
    y = -limb / np.linalg.norm(limb)
    f = child / np.linalg.norm(child)
    perp = f - y * np.dot(f, y)
    bend = np.linalg.norm(perp)
    zs = swung[:, 2]
    w = min(1.0, max(0.0, (bend - 0.1) / 0.25))
    z = zs * (1.0 - w) + (sign * perp / max(bend, 1e-9)) * w
    z = z - y * np.dot(z, y)
    z = z / np.linalg.norm(z)
    return np.column_stack([np.cross(y, z), y, z])


def frame_basis(left, up):
    """A rotation whose x is left and y is (as near as possible) up."""
    x = left / np.linalg.norm(left)
    y = up - x * np.dot(up, x)
    y = y / np.linalg.norm(y)
    z = np.cross(x, y)
    return np.column_stack([x, y, z])


def swing(a, b):
    """The shortest rotation taking unit vector a to unit vector b."""
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if c < -0.9999:
        axis = np.cross(a, [1, 0, 0])
        if np.linalg.norm(axis) < 1e-6:
            axis = np.cross(a, [0, 0, 1])
        axis = axis / np.linalg.norm(axis)
        return 2.0 * np.outer(axis, axis) - np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1.0 / (1.0 + c))


def slerp_mat(a, b, t):
    """Halfway between two rotations, by their quaternions."""
    qa, qb = to_quat(a), to_quat(b)
    if np.dot(qa, qb) < 0:
        qb = -qb
    q = qa * (1 - t) + qb * t
    q = q / np.linalg.norm(q)
    return from_quat(q)


def to_quat(m):
    w = math.sqrt(max(0.0, 1.0 + m[0, 0] + m[1, 1] + m[2, 2])) / 2.0
    x = math.copysign(math.sqrt(max(0.0, 1.0 + m[0, 0] - m[1, 1] - m[2, 2])) / 2.0, m[2, 1] - m[1, 2])
    y = math.copysign(math.sqrt(max(0.0, 1.0 - m[0, 0] + m[1, 1] - m[2, 2])) / 2.0, m[0, 2] - m[2, 0])
    z = math.copysign(math.sqrt(max(0.0, 1.0 - m[0, 0] - m[1, 1] + m[2, 2])) / 2.0, m[1, 0] - m[0, 1])
    return np.array([x, y, z, w])


def from_quat(q):
    x, y, z, w = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def euler_yxz(m):
    """Godot's Basis.get_euler(EULER_ORDER_YXZ), in degrees: m = Ry(y) Rx(x) Rz(z)."""
    m12 = m[1, 2]
    if m12 < 1.0:
        if m12 > -1.0:
            x = math.asin(-m12)
            y = math.atan2(m[0, 2], m[2, 2])
            z = math.atan2(m[1, 0], m[1, 1])
        else:
            x = math.pi / 2
            y = math.atan2(m[0, 1], m[0, 0])
            z = 0.0
    else:
        x = -math.pi / 2
        y = -math.atan2(m[0, 1], m[0, 0])
        z = 0.0
    return [math.degrees(x), math.degrees(y), math.degrees(z)]


def from_euler_yxz(e):
    return rot("Y", e[1]) @ rot("X", e[0]) @ rot("Z", e[2])


def retarget_frame(p, align):
    """The game's local bone rotations for one frame of recorded joint positions p (already turned and scaled)."""
    q = {k: align @ v for k, v in p.items()}
    world = {}
    local = {}
    hips_w = frame_basis(q["LeftUpLeg"] - q["RightUpLeg"], q["Spine1"] - q["Hips"])
    chest_w = frame_basis(q["LeftArm"] - q["RightArm"], q["Neck1"] - q["Spine1"])   # CMU's Neck sits on Spine1
    spine_w = slerp_mat(hips_w, chest_w, 0.5)
    world["hips"], world["spine"], world["chest"] = hips_w, spine_w, chest_w
    local["hips"] = hips_w
    local["spine"] = hips_w.T @ spine_w
    local["chest"] = spine_w.T @ chest_w
    for b in BONES:
        if b in local:
            continue
        a, c, rest = LIMBS[b]
        par = world[PARENT[b]]
        target = q[c] - q[a]
        if np.linalg.norm(target) < 1e-6:
            l = np.eye(3)
        else:
            l = swing(rest, par.T @ (target / np.linalg.norm(target)))
            if b in HINGE:
                l = par.T @ hinge(par @ l, q[c] - q[a], q[HINGE[b][0]] - q[c], HINGE[b][1])
        local[b] = l
        world[b] = par @ l
    return local, q


# ---------------------------------------------------------------- the game's skeleton, forward

GAME_OFFSETS = {"hips": (0, 0.95, 0), "spine": (0, 0.12, 0), "chest": (0, 0.2, 0), "neck": (0, 0.21, 0), "head": (0, 0.07, 0),
                "upperarm_l": (0.19, 0.16, 0), "forearm_l": (0, -0.28, 0), "hand_l": (0, -0.25, 0),
                "upperarm_r": (-0.19, 0.16, 0), "forearm_r": (0, -0.28, 0), "hand_r": (0, -0.25, 0),
                "thigh_l": (0.1, -0.05, 0), "shin_l": (0, -0.44, 0), "foot_l": (0, -0.42, 0),
                "thigh_r": (-0.1, -0.05, 0), "shin_r": (0, -0.44, 0), "foot_r": (0, -0.42, 0)}
ANKLE_H = 0.04          # the ankle's height standing (game/body.gd: 0.95 - 0.05 - 0.44 - 0.42)
CONTACT = 0.035         # an ankle this close to its standing height is on the ground
TOE = np.array([0.0, -0.025, 0.14])   # the front of the foot, in the foot bone's space (the foot's mesh)


def game_feet(local, hips_y=0.0):
    """Where the game's ankles and toes are for one frame of local rotations (body space, the root at the origin)."""
    world_r = {}
    world_p = {}
    for b in BONES:
        off = np.array(GAME_OFFSETS[b], dtype=float)
        if b == "hips":
            world_p[b] = off + np.array([0.0, hips_y, 0.0])
            world_r[b] = local[b]
        else:
            par = PARENT[b]
            world_p[b] = world_p[par] + world_r[par] @ off
            world_r[b] = world_r[par] @ local[b]
    out = {}
    for side in ("l", "r"):
        out["ankle_" + side] = world_p["foot_" + side]
        out["toe_" + side] = world_p["foot_" + side] + world_r["foot_" + side] @ TOE
    return out


TOE_H = 0.015           # the toe point's height standing (ANKLE_H + TOE's y)
SOLE = 0.02             # a foot whose heel or toe is this close to the ground is planted


def planted(f, side, lift):
    """Is that foot on the ground, and which of its points is (the heel's ankle point or the toe)?"""
    a = f["ankle_" + side][1] + lift - ANKLE_H
    t = f["toe_" + side][1] + lift - TOE_H
    if min(a, t) >= SOLE:
        return None
    return "ankle_" + side if a <= t else "toe_" + side


def foot_lock(mats, duration, speed, loop):
    """Feet that stay put. The game moves the player's root at a steady speed; the clip's own root motion is gone.
    So: the hips are lifted or lowered (hips_y) so the lowest foot stands on the ground, and a small offset of the
    hips in the body (hips_side, hips_fwd; drawing only, the player's position is untouched) holds each planted foot
    still while the root goes on. In a loop, the steadiness of the root is made up for while both feet are in the air.
    Returns those, the cycle's length and the worst slide of a planted foot."""
    m = len(mats)
    dt = duration / m if loop else duration / (m - 1)
    feet = [game_feet(l) for l in mats]
    low = min(min(f["ankle_l"][1] - ANKLE_H, f["ankle_r"][1] - ANKLE_H, f["toe_l"][1] - TOE_H, f["toe_r"][1] - TOE_H) for f in feet)
    lift = -low
    v = speed if loop else 0.0
    steps = m if loop else m - 1
    deltas = []
    free = []
    for k in range(steps):
        a, b = feet[k], feet[(k + 1) % m]
        moves = []
        for side in ("l", "r"):
            pa, pb = planted(a, side, lift), planted(b, side, lift)
            if pa and pb:
                pt = pa if pa == pb else "ankle_" + side
                d = b[pt] - a[pt]
                moves.append(np.array([d[0], d[2] + v * dt]))
        deltas.append(-np.mean(moves, axis=0) if moves else np.zeros(2))
        free.append(not moves)
    deltas = np.array(deltas)
    if loop and any(free):
        # Whatever the planted feet leave over is made up in the air, so the offset comes back round.
        drift = deltas.sum(axis=0)
        deltas[np.array(free)] -= drift / sum(free)
    c = np.vstack([np.zeros(2), np.cumsum(deltas, axis=0)])[:m]
    if loop:
        c = c - c.mean(axis=0)
    else:
        # From the stance and back to it: no offset at the start, eased out over the last quarter.
        tail = max(2, m // 4)
        for j in range(tail):
            k = m - tail + j
            c[k] = c[k] * (1.0 - ((j + 1) / tail) ** 2)
    # Measured where the feet are held: all the loop; a single move up to its last quarter, where it settles back.
    held = m + 1 if loop else m - max(2, m // 4)
    worst = 0.0
    for side in ("l", "r"):
        start = None
        for k in range(held):
            f = feet[k % m]
            pt = planted(f, side, lift)
            t = k * dt
            if pt:
                pos = np.array([f[pt][0] + c[k % m][0], f[pt][2] + c[k % m][1] + v * t])
                if start is None or start[0] != pt:
                    start = (pt, pos)
                worst = max(worst, float(np.linalg.norm(pos - start[1])))
            else:
                start = None
    return [lift] * m, c, speed * duration, worst, (held - 1) * dt


# ---------------------------------------------------------------- clips

def build(path, name, mode, start=0.0, end=0.0, hit=None):
    joints, data, dt = parse(path)
    poses = [fk(joints, f) for f in data]
    # Head_End and the index finger may be missing from a take: fall back sensibly.
    for p in poses:
        if "Head_End" not in p:
            p["Head_End"] = p["Head"] + (p["Head"] - p["Neck1"])
        for side in ("Left", "Right"):
            if side + "HandIndex1" not in p:
                p[side + "HandIndex1"] = p[side + "Hand"] * 2 - p[side + "ForeArm"]
    leg = np.mean([np.linalg.norm(p["LeftUpLeg"] - p["LeftLeg"]) + np.linalg.norm(p["LeftLeg"] - p["LeftFoot"]) for p in poses])
    scale = GAME_LEG / leg
    root = np.array([p["Hips"] for p in poses])
    # Which way the subject goes (locomotion) or faces (in place): turn that to +Z, his left to +X.
    travel = root[-1] - root[0]
    travel[1] = 0.0
    if np.linalg.norm(travel) > 20.0:
        fwd = travel / np.linalg.norm(travel)
    else:
        left = np.mean([p["LeftUpLeg"] - p["RightUpLeg"] for p in poses], axis=0)
        left[1] = 0.0
        left = left / np.linalg.norm(left)
        fwd = np.cross(left, [0.0, 1.0, 0.0])
    fwd = fwd / np.linalg.norm(fwd)
    leftv = np.cross([0.0, 1.0, 0.0], fwd)
    align = np.vstack([leftv, [0.0, 1.0, 0.0], fwd])      # rows: world -> game axes
    n = len(poses)
    times = np.arange(n) * dt
    if mode == "cycle":
        # The left foot's strikes (it comes down through a height near the floor) or, if the take holds only one,
        # its lift-offs: two of the same mark one gait cycle. The first frames of a CMU take can be a rest pose: skipped.
        ly = np.array([p["LeftFoot"][1] for p in poses])
        lo, hi = np.percentile(ly[3:], 5), np.percentile(ly[3:], 95)
        thr = lo + 0.3 * (hi - lo)
        downs = [i for i in range(4, n) if ly[i - 1] > thr >= ly[i]]
        ups = [i for i in range(4, n) if ly[i - 1] < thr <= ly[i]]
        keep = []
        for marks in (downs, ups):
            keep = []
            for s in marks:
                if not keep or times[s] - times[keep[-1]] > 0.45:
                    keep.append(s)
            if len(keep) >= 2:
                break
        if len(keep) < 2:
            raise SystemExit("no full gait cycle found in " + str(path))
        i0, i1 = keep[0], keep[1]
        t0, t1 = times[i0], times[i1]
        dist = np.linalg.norm((root[i1] - root[i0])[[0, 2]]) * scale
    else:
        t0, t1 = start, end
        dist = 0.0
    duration = t1 - t0
    count = max(2, int(round(duration * FPS)))
    mats = []
    for k in range(count + (0 if mode == "cycle" else 1)):
        t = t0 + duration * k / count
        i = min(n - 2, int(t / dt))
        w = t / dt - i
        p = {key: poses[i][key] * (1 - w) + poses[i + 1][key] * w for key in poses[i]}
        r = p["Hips"].copy()
        # In place: the root over the origin; scaled to the game's size.
        p = {key: (v - np.array([r[0], 0.0, r[2]])) * scale for key, v in p.items()}
        local, q = retarget_frame(p, align)
        mats.append(local)
    if mode == "cycle":
        # Close the loop: ease the last quarter toward the first frame.
        m = len(mats)
        tail = max(2, m // 4)
        for j in range(tail):
            k = m - tail + j
            wgt = ((j + 1) / (tail + 1)) ** 2
            for b in BONES:
                mats[k][b] = slerp_mat(mats[k][b], mats[0][b], wgt)
    speed = dist / duration if mode == "cycle" else 0.0
    hips_y, lock, cycle_m, slide, settle = foot_lock(mats, duration, speed, mode == "cycle")
    out_frames = []
    prev = None
    for k, local in enumerate(mats):
        e = {}
        for b in BONES:
            # The two angle sets that make the same turn; the one nearest the last frame (the smaller, at first).
            a = euler_yxz(local[b])
            alt = [180.0 - a[0] if a[0] > 0 else -180.0 - a[0], a[1] + 180.0, a[2] + 180.0]
            best = None
            for cand in (a, alt):
                cand = [(v + 180.0) % 360.0 - 180.0 for v in cand]
                if prev is not None:
                    for c in range(3):
                        while cand[c] - prev[b][c] > 180.0:
                            cand[c] -= 360.0
                        while cand[c] - prev[b][c] < -180.0:
                            cand[c] += 360.0
                    cost = sum(abs(cand[c] - prev[b][c]) for c in range(3))
                else:
                    cost = sum(abs(v) for v in cand)
                if best is None or cost < best[0]:
                    best = (cost, cand)
            e[b] = best[1]
        prev = e
        fr = {b: [round(v, 2) for v in e[b]] for b in BONES}
        fr["hips_y"] = round(float(hips_y[k]), 4)
        fr["hips_side"] = round(float(lock[k][0]), 4)
        fr["hips_fwd"] = round(float(lock[k][1]), 4)
        out_frames.append(fr)
    dist = cycle_m
    # Verify the Euler angles rebuild the rotations (the order Godot reads them in).
    test = retarget_frame({key: (v - np.array([poses[0]["Hips"][0], 0.0, poses[0]["Hips"][2]])) * scale for key, v in poses[0].items()}, align)[0]
    for b in BONES:
        err = np.abs(from_euler_yxz(euler_yxz(test[b])) - test[b]).max()
        if err > 1e-6:
            raise SystemExit("euler round trip failed for %s (%g)" % (b, err))
    clip = {"source": pathlib.Path(path).stem, "fps": FPS, "loop": mode == "cycle", "duration": round(duration, 4),
            "slide": round(slide, 4), "held": round(min(settle, duration), 4),
            "cycle_m": round(float(dist), 3), "speed": round(float(dist / duration), 3) if mode == "cycle" else 0.0,
            "frames": out_frames}
    if hit is not None:
        clip["hit"] = round(hit - t0, 4)
    OUT.mkdir(parents=True, exist_ok=True)
    dst = OUT / (name + ".json")
    dst.write_text(json.dumps(clip, separators=(",", ":")))
    print("%s: %s %d frames, %.2f s, %.2f m a cycle, %.2f m/s, slide %.3f m -> %s (%d KB)" % (name, clip["source"], len(out_frames),
          duration, clip["cycle_m"], clip["speed"], slide, dst.relative_to(ROOT), dst.stat().st_size // 1024))
    return clip


def main():
    a = sys.argv[1:]
    if len(a) < 3:
        print(__doc__)
        return 1
    hit = None
    if "--hit" in a:
        i = a.index("--hit")
        hit = float(a[i + 1])
        a = a[:i] + a[i + 2:]
    if a[2] == "cycle":
        build(a[0], a[1], "cycle", hit=hit)
    else:
        build(a[0], a[1], "span", float(a[3]), float(a[4]), hit=hit)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Clips from the CMU motion capture library (BVH, from the GitHub mirror of Bruce Hahne's conversion) made ready for
tools/models/retarget_bvh.gd: a window of each, at 30 frames a second, its travel over the ground taken out.

The BVH files are not in this repository (see docs/MODELS.md for the clip IDs and where to fetch them):

    python3 tools/models/bvh_to_json.py BVH_DIR OUT_DIR

For each clip in CLIPS it writes OUT_DIR/<name>.json:
  - rest: for each of the player's bones, the direction its bone points in the BVH skeleton at rest (every BVH joint
    rests unturned, so its rest world rotation is the identity), the hips' left-to-right across, and the leg's length;
  - frames: for each frame, each bone's world rotation (a quaternion x, y, z, w) and the hips' position, both in the
    frame of the root (below), and the root itself: x, z (metres) and heading (radians, 0 facing +Z).

The root is the body's path over the ground: the hips' track smoothed, heading where it travels (or, standing still,
where the hips face on average). Taking it out leaves the movement in place, so the game's movement system stays the
one writer of each player's position and facing; the root is kept in the clip's metadata, for its speed and for the
foot-slide test. A looping clip's last half second is blended into the frames just before its first, so it loops
without a jump.
"""
import json
import os
import sys

import numpy as np
from scipy.ndimage import gaussian_filter1d
from scipy.spatial.transform import Rotation as R

UNIT = 0.0254 / 0.45   # metres per BVH unit (the CMU skeletons' scale)
FPS = 30

# name in the game: CMU clip, first and last second kept, loops, and how much of the neck's and head's own movement
# is kept (1: all)
CLIPS = {
    # Subject 127, "Run Left": a run, the right (outside) foot planted, a hard cut to his left. Mirrored for a cut
    # right. The game's DODGE and the AI defenders' dodge.
    "dodge": ("127_11", 0.57, 1.17, False, 1.0),
    # Subject 77, "standing": standing at ease, shifting weight. The actor was looking at the floor; a player watches
    # the play (the game turns his head to it), so the neck and head keep only a third of their own movement.
    "idle": ("77_02", 0.6, 5.6, True, 0.3),
}

# The player's bone: the BVH joint whose world rotation it takes, and the BVH joints its bone runs between (None: it
# is not aimed). BVH and the player's rig both turn a joint's children by the joint's rotation, so each of the
# player's bones takes the rotation of the BVH joint that turns the same stretch of the body.
MAP = {
    "Hips": ("Hips", ("Hips", "Spine")),
    "Spine": ("LowerBack", ("Hips", "Spine")),
    "Spine1": ("Spine", ("Spine", "Spine1")),
    "Spine2": ("Spine1", ("Spine1", "Neck1")),
    "Neck": ("Neck1", ("Neck1", "Head")),
    "Head": ("Head", None),
}
for s in ("Left", "Right"):
    MAP.update({
        s + "Shoulder": (s + "Shoulder", (s + "Shoulder", s + "Arm")),
        s + "Arm": (s + "Arm", (s + "Arm", s + "ForeArm")),
        s + "ForeArm": (s + "ForeArm", (s + "ForeArm", s + "Hand")),
        s + "Hand": (s + "Hand", None),
        s + "UpLeg": (s + "UpLeg", (s + "UpLeg", s + "Leg")),
        s + "Leg": (s + "Leg", (s + "Leg", s + "Foot")),
        s + "Foot": (s + "Foot", (s + "Foot", s + "ToeBase")),
        s + "ToeBase": (s + "ToeBase", None),
    })


def load(path):
    tok = open(path).read().split()
    i = 0
    joints, stack = [], []
    while tok[i] != "MOTION":
        t = tok[i]
        if t in ("ROOT", "JOINT", "End"):
            name = tok[i + 1] if t != "End" else joints[stack[-1]]["name"] + "_end"
            joints.append({"name": name, "parent": stack[-1] if stack else -1, "ch": [], "off": np.zeros(3)})
            i += 2
            continue
        if t == "{":
            stack.append(len(joints) - 1)
        elif t == "}":
            stack.pop()
        elif t == "OFFSET":
            joints[stack[-1]]["off"] = np.array([float(v) for v in tok[i + 1:i + 4]])
            i += 4
            continue
        elif t == "CHANNELS":
            n = int(tok[i + 1])
            joints[stack[-1]]["ch"] = tok[i + 2:i + 2 + n]
            i += 2 + n
            continue
        i += 1
    frames = int(tok[i + 2])
    ft = float(tok[i + 5])
    data = np.array([float(v) for v in tok[i + 6:]]).reshape(frames, -1)
    return joints, data, ft


def fk(joints, data):
    """World positions (BVH units) and rotations of every joint, every frame."""
    nf = data.shape[0]
    pos = np.zeros((nf, len(joints), 3))
    rot = [None] * len(joints)
    c = 0
    for j, jt in enumerate(joints):
        ch = jt["ch"]
        vals = data[:, c:c + len(ch)]
        c += len(ch)
        rc = [k for k in ch if k.endswith("rotation")]
        local = R.from_euler("".join(k[0] for k in rc).upper(), vals[:, [ch.index(k) for k in rc]], degrees=True) if rc else R.identity(nf)
        p = jt["parent"]
        if p < 0:
            pos[:, j] = vals[:, [ch.index(k) for k in ("Xposition", "Yposition", "Zposition")]]
            rot[j] = local
        else:
            pos[:, j] = pos[:, p] + rot[p].apply(np.tile(jt["off"], (nf, 1)))
            rot[j] = rot[p] * local
    return pos, rot


def rest_positions(joints):
    out = []
    for jt in joints:
        out.append(jt["off"] + (out[jt["parent"]] if jt["parent"] >= 0 else 0))
    return np.array(out)


def yaw_of(r):
    f = r.apply([0.0, 0.0, 1.0])
    return np.arctan2(f[..., 0], f[..., 2])


def calm(joints, data, ix, keep):
    """The neck's and head's own turns (relative to the chest) scaled by keep."""
    if keep >= 1.0:
        return data
    data = data.copy()
    c = 0
    for jt in joints:
        n = len(jt["ch"])
        if jt["name"] in ("Neck", "Neck1", "Head"):
            rc = [k for k in jt["ch"] if k.endswith("rotation")]
            cols = [c + jt["ch"].index(k) for k in rc]
            order = "".join(k[0] for k in rc).upper()
            r = R.from_euler(order, data[:, cols], degrees=True)
            data[:, cols] = R.from_rotvec(r.as_rotvec() * keep).as_euler(order, degrees=True)
        c += n
    return data


def convert(path, start, end, loop, head_keep=1.0):
    joints, data, ft = load(path)
    names = [j["name"] for j in joints]
    ix = {n: k for k, n in enumerate(names)}
    data = calm(joints, data, ix, head_keep)
    pos, rot = fk(joints, data)
    pos = pos * UNIT
    step = int(round(1.0 / (FPS * ft)))   # 120 fps to 30: every 4th frame
    h = ix["Hips"]
    # The root, from all the frames (so the smoothing has room at the window's ends).
    xz = gaussian_filter1d(pos[:, h, [0, 2]], sigma=0.1 / ft, axis=0)
    a, b = int(round(start / ft)), int(round(end / ft))
    if loop:
        heading = np.full(len(data), np.angle(np.mean(np.exp(1j * yaw_of(rot[h])[a:b]))))
        xz[:] = xz[a:b].mean(axis=0)
    else:
        v = np.gradient(xz, ft, axis=0)
        heading = gaussian_filter1d(np.unwrap(np.arctan2(v[:, 0], v[:, 1])), sigma=0.05 / ft)
    # Frames kept: the window, and for a loop the half second before it (to blend the end into).
    blend = int(round(0.5 * FPS)) if loop else 0
    idx = list(range(a - blend * step, b + 1, step))
    o_xz, o_h = xz[a].copy(), heading[a]
    turn0 = R.from_euler("y", -o_h)
    frames = []
    for f in idx:
        inv = R.from_euler("y", heading[f]).inv()   # the world into the root's frame
        rel = pos[f, h] - np.array([xz[f, 0], 0.0, xz[f, 1]])
        hips = inv.apply(rel)
        rx = turn0.apply([xz[f, 0] - o_xz[0], 0.0, xz[f, 1] - o_xz[1]])
        fr = {"root": [rx[0], rx[2], float(heading[f] - o_h)], "hips": hips.tolist(), "rot": {}}
        for bone, (src, _) in MAP.items():
            fr["rot"][bone] = (inv * rot[ix[src]][f]).as_quat().tolist()
        frames.append(fr)
    if loop:
        # The last `blend` frames ease into the ones just before the first kept frame: the loop's end is its start.
        pre, frames = frames[:blend], frames[blend:]
        n = len(frames)
        for k in range(blend):
            w = (k + 1) / blend
            w = w * w * (3 - 2 * w)
            fr, to = frames[n - blend + k], pre[k]
            for bone in fr["rot"]:
                q = R.from_quat([fr["rot"][bone], to["rot"][bone]])
                fr["rot"][bone] = (q[0] * R.from_rotvec(w * (q[0].inv() * q[1]).as_rotvec())).as_quat().tolist()
            fr["hips"] = (np.array(fr["hips"]) * (1 - w) + np.array(to["hips"]) * w).tolist()
    rp = rest_positions(joints) * UNIT
    rest = {"aim": {}, "across": (rp[ix["LeftUpLeg"]] - rp[ix["RightUpLeg"]]).tolist(),
            "leg": float(np.linalg.norm(rp[ix["LeftLeg"]] - rp[ix["LeftUpLeg"]]) + np.linalg.norm(rp[ix["LeftFoot"]] - rp[ix["LeftLeg"]]))}
    for bone, (_, seg) in MAP.items():
        if seg:
            d = rp[ix[seg[1]]] - rp[ix[seg[0]]]
            rest["aim"][bone] = (d / np.linalg.norm(d)).tolist()
    return {"fps": FPS, "loop": loop, "rest": rest, "frames": frames}


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    for name, (clip, start, end, loop, head_keep) in CLIPS.items():
        res = convert(os.path.join(src, clip + ".bvh"), start, end, loop, head_keep)
        with open(os.path.join(out, name + ".json"), "w") as fh:
            json.dump(res, fh)
        root = np.array([f["root"] for f in res["frames"]])
        dist = np.linalg.norm(np.diff(root[:, :2], axis=0), axis=1).sum()
        print("%s <- %s %.2f-%.2f s: %d frames, %.2f m travelled, heading %+.0f deg" % (
            name, clip, start, end, len(res["frames"]), dist, np.degrees(root[-1, 2] - root[0, 2])))


if __name__ == "__main__":
    main()

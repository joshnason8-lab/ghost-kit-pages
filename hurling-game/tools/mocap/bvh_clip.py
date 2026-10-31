#!/usr/bin/env python3
"""A CMU motion-capture clip (BVH, from the GitHub mirror of the CMU Graphics Lab database) turned into one of the
game's looping clips: one gait cycle, 30 frames a second, each of the game's 17 bones' turns from its rest stance as
degrees (Euler YXZ, as ToonBody.apply reads them) and the hips' lift, the same form as the Mixamo clips in
assets/player/hero.json. The man is kept over the spot (the game moves him): the clip's travel and its heading are
taken out, and the hips' height is set so the lowest the feet reach over the cycle is the ground.

Retargeting: every bone of the recording is turned, at rest, onto the game's rest stance (the CMU actors stand in a
T-pose with the legs a little apart; the game's men stand with arms down), the shortest way, so a turn in the
recording is the same turn of the game's bone.

  python3 tools/mocap/bvh_clip.py <clip.bvh> <name> <first frame (120 fps)> [frames]   -> prints the clip's JSON
  python3 tools/mocap/bvh_clip.py --all <dir of .bvh>                                  -> writes assets/player/cmu.json

The raw BVH files are not kept in the repository; CLIPS lists each one used (its CMU id) and fetch.sh gets them.
"""
import json
import math
import pathlib
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
HERO = json.loads((ROOT / "assets/player/hero.json").read_text())
OFF = {k: np.array(v) for k, v in HERO["offsets"].items()}

# The clips the game uses: name -> (CMU clip, the frame (120 a second) to look for a clean cycle from).
CLIPS = {
    "CMU_Walk": ("35_01", 0),
    "CMU_Jog": ("35_17", 0),
}

BONES = ["hips", "spine", "chest", "neck", "head", "upperarm_l", "forearm_l", "hand_l", "upperarm_r", "forearm_r",
         "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
PARENT = {"hips": None, "spine": "hips", "chest": "spine", "neck": "chest", "head": "neck", "upperarm_l": "chest",
          "forearm_l": "upperarm_l", "hand_l": "forearm_l", "upperarm_r": "chest", "forearm_r": "upperarm_r",
          "hand_r": "forearm_r", "thigh_l": "hips", "shin_l": "thigh_l", "foot_l": "shin_l", "thigh_r": "hips",
          "shin_r": "thigh_r", "foot_r": "shin_r"}
# Each game bone: the CMU joint whose turning it takes, the CMU joint at the bone's far end (its direction at rest),
# and the game bone at the far end (the game's direction at rest; None: keeps the recording's own rest, as a foot or
# the head, or a hand, which follows its forearm's).
MAP = {
    "hips": ("Hips", None, None),
    "spine": ("Spine", "Spine1", "chest"),
    "chest": ("Spine1", "Neck1", "neck"),
    "neck": ("Neck1", "Head", "head"),
    "head": ("Head", None, None),
    "upperarm_l": ("LeftArm", "LeftForeArm", "forearm_l"),
    "forearm_l": ("LeftForeArm", "LeftHand", "hand_l"),
    "hand_l": ("LeftHand", "forearm_l", None),
    "upperarm_r": ("RightArm", "RightForeArm", "forearm_r"),
    "forearm_r": ("RightForeArm", "RightHand", "hand_r"),
    "hand_r": ("RightHand", "forearm_r", None),
    "thigh_l": ("LeftUpLeg", "LeftLeg", "shin_l"),
    "shin_l": ("LeftLeg", "LeftFoot", "foot_l"),
    "foot_l": ("LeftFoot", None, None),
    "thigh_r": ("RightUpLeg", "RightLeg", "shin_r"),
    "shin_r": ("RightLeg", "RightFoot", "foot_r"),
    "foot_r": ("RightFoot", None, None),
}


def rx(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def ry(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def euler_yxz(m):
    """Degrees (x, y, z) with m = Ry(y) Rx(x) Rz(z), as Godot's Basis.get_euler(EULER_ORDER_YXZ)."""
    x = math.asin(max(-1.0, min(1.0, -m[1, 2])))
    if abs(m[1, 2]) < 0.9999:
        y = math.atan2(m[0, 2], m[2, 2])
        z = math.atan2(m[1, 0], m[1, 1])
    else:
        y = math.atan2(-m[2, 0], m[0, 0])
        z = 0.0
    return [round(math.degrees(x), 1), round(math.degrees(y), 1), round(math.degrees(z), 1)]


def arc(a, b):
    """The shortest turn taking direction a onto direction b."""
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if np.linalg.norm(v) < 1e-9:
        return np.eye(3)
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + k + k @ k * (1.0 / (1.0 + c))


def read_bvh(path):
    toks = pathlib.Path(path).read_text().split()
    joints = []      # [name, parent index, offset, channels]
    stack = []
    i = 0
    while toks[i] != "MOTION":
        t = toks[i]
        if t in ("ROOT", "JOINT"):
            joints.append([toks[i + 1], stack[-1] if stack else -1, None, []])
            i += 2
        elif t == "End":
            joints.append(["_end", stack[-1], None, []])
            i += 2
        elif t == "{":
            stack.append(len(joints) - 1)
            i += 1
        elif t == "}":
            stack.pop()
            i += 1
        elif t == "OFFSET":
            joints[stack[-1]][2] = np.array([float(x) for x in toks[i + 1:i + 4]])
            i += 4
        elif t == "CHANNELS":
            n = int(toks[i + 1])
            joints[stack[-1]][3] = toks[i + 2:i + 2 + n]
            i += 2 + n
        else:
            i += 1
    n = int(toks[i + 2])
    ft = float(toks[i + 5])
    nch = sum(len(j[3]) for j in joints)
    data = np.array([float(x) for x in toks[i + 6:i + 6 + n * nch]]).reshape(n, nch)
    return joints, data, ft


def pose(joints, row):
    """Every joint's world turn and place in one frame."""
    rot = []
    pos = []
    c = 0
    for name, par, off, ch in joints:
        r = np.eye(3)
        p = off.copy()
        for k in ch:
            v = row[c]
            c += 1
            if k == "Xposition":
                p[0] = v
            elif k == "Yposition":
                p[1] = v
            elif k == "Zposition":
                p[2] = v
            elif k == "Xrotation":
                r = r @ rx(math.radians(v))
            elif k == "Yrotation":
                r = r @ ry(math.radians(v))
            elif k == "Zrotation":
                r = r @ rz(math.radians(v))
        if par < 0:
            rot.append(r)
            pos.append(p)
        else:
            rot.append(rot[par] @ r)
            pos.append(pos[par] + rot[par] @ p)
    return rot, pos


def game_fk(turns):
    """The game skeleton's joints placed by a frame's world turns (hips at the origin)."""
    at = {"hips": np.zeros(3)}
    for b in BONES[1:]:
        at[b] = at[PARENT[b]] + turns[PARENT[b]] @ OFF[b]
    return at


def clip(path, first=0, count=None, fps=30):
    joints, data, ft = read_bvh(path)
    idx = {j[0]: n for n, j in enumerate(joints)}
    step = max(1, int(round((1.0 / fps) / ft)))
    rows = data[first::step]
    frames = [pose(joints, r) for r in rows]
    # The rest stance: each mapped bone turned from the recording's rest direction onto the game's.
    rest_at = []
    for name, par, off, ch in joints:
        rest_at.append(off if par < 0 else rest_at[par] + off)
    stance = {}
    for b in BONES:
        j, far, gfar = MAP[b]
        if gfar is not None:
            stance[b] = arc(rest_at[idx[far]] - rest_at[idx[j]], OFF[gfar])
        elif far is not None:
            stance[b] = stance[far]
        else:
            stance[b] = np.eye(3)
    # One gait cycle: from one frame with the left ankle furthest ahead of the right to the next.
    hips = idx["Hips"]

    def heading(f):
        rot, pos = frames[f]
        return rot[hips]

    def left_ahead(f):
        rot, pos = frames[f]
        fwd = rot[hips] @ np.array([0, 0, 1.0])
        fwd[1] = 0
        fwd /= np.linalg.norm(fwd)
        return float(np.dot(pos[idx["LeftFoot"]] - pos[idx["RightFoot"]], fwd))

    la = [left_ahead(f) for f in range(len(frames))]
    # (the highest within a third of a second either side: a peak of the stride, not a tremor in the recording)
    w = fps // 3
    peaks = [f for f in range(1, len(la) - 1) if la[f] > 0 and la[f] == max(la[max(0, f - w):f + w + 1])]
    a, b = peaks[0], peaks[1]
    if count:
        b = a + count
    # Its travel and heading taken out: the man faces +Z, over the spot.
    travel = frames[b][1][hips] - frames[a][1][hips]
    travel[1] = 0
    yaw = math.atan2(travel[0], travel[2])
    unyaw = ry(-yaw)
    out = []
    lows = []
    for f in range(a, b + 1):
        rot, pos = frames[f]
        turns = {}
        for bn in BONES:
            turns[bn] = unyaw @ rot[idx[MAP[bn][0]]] @ stance[bn].T
        at = game_fk(turns)
        lows.append(min(at["foot_l"][1], at["foot_r"][1]))
        fr = {}
        for bn in BONES:
            local = turns[bn] if PARENT[bn] is None else turns[PARENT[bn]].T @ turns[bn]
            fr[bn] = euler_yxz(local)
        fr["_y"] = float(pos[hips][1])
        out.append(fr)
    # The hips' height: the recording's rise and fall, scaled to the game's legs, with the lowest the feet reach (the
    # ankles, a foot's length off the toes) at the stance's height.
    rec_leg = np.linalg.norm(joints[idx["LeftLeg"]][2]) + np.linalg.norm(joints[idx["LeftFoot"]][2])
    game_leg = np.linalg.norm(OFF["shin_l"]) + np.linalg.norm(OFF["foot_l"])
    k = game_leg / rec_leg
    rest_low = game_fk({bn: np.eye(3) for bn in BONES})["foot_l"][1]
    ys = np.array([fr.pop("_y") for fr in out]) * k
    lift = ys - ys.mean()
    drop = min(lows[i] + lift[i] for i in range(len(out))) - rest_low
    for i, fr in enumerate(out):
        fr["hips_y"] = round(float(lift[i] - drop), 3)
    out[-1] = dict(out[0])          # the cycle closes on its first frame
    # The left thigh furthest forward: the stride's phase pi/2 in the game (Player._pose), as for the Mixamo sprint.
    fwd = min(range(len(out) - 1), key=lambda i: out[i]["thigh_l"][0])
    secs = (b - a) / float(fps)
    speed = float(np.linalg.norm(travel)) * k / secs
    print(f"{path}: frames {a}-{b} at {fps} fps ({secs:.2f} s), travels {speed:.2f} m/s at the game's leg length, "
          f"turned {math.degrees(yaw):.0f} degrees", file=sys.stderr)
    return {"fps": fps, "left_forward": round(fwd / float(fps), 3), "speed": round(speed, 2), "source": "CMU " + pathlib.Path(path).stem,
            "frames": out}


def main():
    if sys.argv[1] == "--all":
        # (Only at 30 frames a second: at 60 the planted foot slid more at the game's strides, so the HD pack has none.)
        fps = 30
        src = pathlib.Path(sys.argv[2])
        clips = {name: clip(src / f"{cid}.bvh", first, None, fps) for name, (cid, first) in CLIPS.items()}
        dst = ROOT / "assets/player/cmu.json"
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(json.dumps({"clips": clips}, separators=(",", ":")))
        print("wrote", dst.relative_to(ROOT), dst.stat().st_size, "bytes")
    else:
        c = clip(sys.argv[1], int(sys.argv[3]) if len(sys.argv) > 3 else 0, int(sys.argv[4]) if len(sys.argv) > 4 else None)
        print(json.dumps(c))


if __name__ == "__main__":
    main()

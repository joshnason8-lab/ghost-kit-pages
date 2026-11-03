#!/usr/bin/env python3
"""Take the bow out of the locomotion clips' legs (assets/mocap/move_*.json).

A runner whose knees stand out sideways from the line hip to ankle reads as bow-legged. The captured run did that by
5 cm on average and 14 at worst (the jog, by 1). For each frame and each leg, the whole leg is turned about its own
hip-to-ankle line until the knee stands out by at most MAX_OUT: the foot stays exactly where it was (and so its
stride and its plant), the knee comes in over it. The knee's own bend is untouched; only the hip's rotation changes.
A knee already in line, or in from it, is left alone. A defender's crouched side-shuffle keeps a little more
(SHUFFLE_OUT): knees out over the feet is how one shuffles.

Measured with the game's leg (HumanModel: hips 0.1 m either side, 0.04 below the pelvis' joint, thigh 0.44 m,
shin to the ankle 0.39 m), in the pelvis' frame (the body's left is -x).
    python3 tools/mocap/unbow.py            # rewrites assets/mocap/move_*.json, prints before and after
"""
import glob
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "mocap"))
MAX_OUT = 0.015
SHUFFLE_OUT = 0.04
HIP_X = 0.1
HIP_Y = -0.04
THIGH = 0.44
SHIN = 0.39


def qmul(a, b):
    x1, y1, z1, w1 = a
    x2, y2, z2, w2 = b
    return (w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2, w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
            w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2, w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2)


def qinv(q):
    return (-q[0], -q[1], -q[2], q[3])


def rot(q, v):
    r = qmul(qmul(q, (v[0], v[1], v[2], 0.0)), qinv(q))
    return r[:3]


def axis_angle(u, a):
    s = math.sin(a / 2)
    return (u[0] * s, u[1] * s, u[2] * s, math.cos(a / 2))


def add(a, b): return tuple(x + y for x, y in zip(a, b))
def sub(a, b): return tuple(x - y for x, y in zip(a, b))
def mul(a, k): return tuple(x * k for x in a)
def dot(a, b): return sum(x * y for x, y in zip(a, b))


def norm(a):
    n = math.sqrt(dot(a, a))
    return mul(a, 1.0 / n) if n > 1e-9 else a


def leg(pel, qh_local, qk_local, side):
    """Hip, knee, ankle (pelvis' parent frame) and the world hip rotation."""
    hip = rot(pel, (-HIP_X if side == "l" else HIP_X, HIP_Y, 0.0))
    qh = qmul(pel, qh_local)
    knee = add(hip, rot(qh, (0.0, -THIGH, 0.0)))
    ankle = add(knee, rot(qmul(qh, qk_local), (0.0, -SHIN, 0.0)))
    return hip, knee, ankle, qh


def knee_out(pel, hip, knee, ankle, side):
    out = rot(pel, (-1.0 if side == "l" else 1.0, 0.0, 0.0))
    return dot(sub(knee, mul(add(hip, ankle), 0.5)), out), out


def fix_clip(path):
    with open(path) as f:
        d = json.load(f)
    joints = d["joints"]
    idx = {j: i for i, j in enumerate(joints)}
    limit = SHUFFLE_OUT if "shuffle" in d["name"] else MAX_OUT
    before, after = [], []
    for fr in d["frames"]:
        q = fr["q"]
        get = lambda j: tuple(q[idx[j] * 4: idx[j] * 4 + 4])
        pel = get("pelvis")
        for side in ("l", "r"):
            hj, kj = "hip_" + side, "kn_" + side
            hip, knee, ankle, qh = leg(pel, get(hj), get(kj), side)
            dev, out = knee_out(pel, hip, knee, ankle, side)
            before.append(dev)
            if dev > limit:
                u = norm(sub(ankle, hip))
                best, best_a = dev, 0.0
                # The smallest turn about the hip-ankle line that brings the knee in to the limit.
                for step in range(1, 1801):
                    for sgn in (1.0, -1.0):
                        a = sgn * math.radians(step * 0.05)
                        r = axis_angle(u, a)
                        k2 = add(hip, rot(r, sub(knee, hip)))
                        d2, _ = knee_out(pel, hip, k2, ankle, side)
                        if d2 <= limit:
                            best, best_a = d2, a
                            break
                    if best <= limit:
                        break
                if best_a != 0.0:
                    qh2 = qmul(axis_angle(u, best_a), qh)
                    ql = qmul(qinv(pel), qh2)
                    n = math.sqrt(dot(ql, ql))
                    ql = tuple(round(c / n, 4) for c in ql)
                    q[idx[hj] * 4: idx[hj] * 4 + 4] = list(ql)
            hip, knee, ankle, _ = leg(pel, get(hj), get(kj), side)
            after.append(knee_out(pel, hip, knee, ankle, side)[0])
    with open(path, "w") as f:
        json.dump(d, f, separators=(",", ":"))
    return d["name"], before, after


def main():
    files = sys.argv[1:] or sorted(glob.glob(os.path.join(DIR, "move_*.json")))
    for p in files:
        name, b, a = fix_clip(p)
        print("%-20s knee out: mean %+.3f max %+.3f  ->  mean %+.3f max %+.3f" % (
            name, sum(b) / len(b), max(b), sum(a) / len(a), max(a)))


if __name__ == "__main__":
    main()

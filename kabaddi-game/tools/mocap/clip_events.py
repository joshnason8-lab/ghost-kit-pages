#!/usr/bin/env python3
"""Where the action is in a version 2 clip (tools/mocap/fbx_to_clip.gd): poses the game's own skeleton
(1.78 m, facing -Z) through the clip and reports, per frame, the hips' height, how far each foot and hand
reaches from the hips, and the head's sideways lean, with the frames where each peaks. trim_clip.py then
cuts a clip down to the part a move needs.

Usage: python3 clip_events.py CLIP.json [--plot]
"""

import json
import sys

import numpy as np

HIP_H = 0.98
OFF = {  # joint: (parent, offset from the parent in its frame)
    "pelvis": (None, (0, HIP_H, 0)), "spine": ("pelvis", (0, 0.06, 0)), "chest": ("spine", (0, 0.30, 0)),
    "neck": ("chest", (0, 0.22, 0)), "head": ("neck", (0, 0.10, 0)),
    "sh_l": ("chest", (-0.215, 0.15, 0)), "sh_r": ("chest", (0.215, 0.15, 0)),
    "el_l": ("sh_l", (0, -0.30, 0)), "el_r": ("sh_r", (0, -0.30, 0)),
    "hip_l": ("pelvis", (-0.1, -0.04, 0)), "hip_r": ("pelvis", (0.1, -0.04, 0)),
    "kn_l": ("hip_l", (0, -0.44, 0)), "kn_r": ("hip_r", (0, -0.44, 0)),
}
TIPS = {"foot_l": ("kn_l", (0, -0.44, 0)), "foot_r": ("kn_r", (0, -0.44, 0)),
        "hand_l": ("el_l", (0, -0.30, 0)), "hand_r": ("el_r", (0, -0.30, 0)), "head_top": ("head", (0, 0.2, 0))}


def qmul(a, b):
    x1, y1, z1, w1 = a
    x2, y2, z2, w2 = b
    return np.array([w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2, w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
                     w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2, w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2])


def qrot(q, v):
    u = np.array(q[:3])
    w = q[3]
    v = np.array(v, dtype=float)
    return 2 * np.dot(u, v) * u + (w * w - np.dot(u, u)) * v + 2 * w * np.cross(u, v)


def pose(clip, frame):
    q = np.array(frame["q"], dtype=float).reshape(-1, 4)
    q /= np.linalg.norm(q, axis=1, keepdims=True)
    rot = dict(zip(clip["joints"], q))
    g, pos = {}, {}
    for j in clip["joints"]:
        parent, off = OFF[j]
        if parent is None:
            g[j] = rot[j]
            pos[j] = np.array([0.0, HIP_H * frame["h"], 0.0])
        else:
            g[j] = qmul(g[parent], rot[j])
            pos[j] = pos[parent] + qrot(g[parent], off)
    for t, (j, off) in TIPS.items():
        pos[t] = pos[j] + qrot(g[j], off)
    return pos


def events(clip):
    rows = []
    for f in clip["frames"]:
        p = pose(clip, f)
        hips = p["pelvis"]
        row = {"t": f["t"], "h": f["h"], "head_y": p["head_top"][1],
               "lean": abs(p["head_top"][0] - (p["foot_l"][0] + p["foot_r"][0]) / 2)}
        for k in ("foot_l", "foot_r", "hand_l", "hand_r"):
            d = p[k] - hips
            row[k] = float(np.hypot(d[0], d[2]))     # reach along the ground
            row[k + "_y"] = float(p[k][1])
        rows.append(row)
    return rows


def main():
    clip = json.load(open(sys.argv[1]))
    rows = events(clip)
    t = np.array([r["t"] for r in rows])
    def peak(key, fn=np.argmax):
        v = np.array([r[key] for r in rows])
        i = int(fn(v))
        return f"{key} {'max' if fn is np.argmax else 'min'} {v[i]:.2f} at {t[i]:.2f}s"
    print(clip["name"], f"{clip['length']:.2f}s")
    for k in ("foot_l", "foot_r", "hand_l", "hand_r", "lean"):
        print("  ", peak(k))
    print("  ", peak("h", np.argmin), "|", peak("h"), "|", peak("head_y", np.argmin))
    if "--plot" in sys.argv:
        for r in rows[::3]:
            print(f"   {r['t']:.2f} h {r['h']:.2f} head {r['head_y']:.2f} fl {r['foot_l']:.2f}/{r['foot_l_y']:.2f} "
                  f"fr {r['foot_r']:.2f}/{r['foot_r_y']:.2f} hl {r['hand_l']:.2f} hr {r['hand_r']:.2f} lean {r['lean']:.2f}")


if __name__ == "__main__":
    main()

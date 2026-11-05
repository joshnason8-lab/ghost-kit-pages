"""Joint angles per frame from trace_pose.py's JSON (MediaPipe's world landmarks: metres, y down, the hips' middle at
the origin), measured as tests/pose_probe.gd measures the game's poses, so the two can be put side by side:

  lean     the trunk (the hips' middle to the shoulders') from upright, + forward (toward the camera: the subject faces
           it in the clips traced so far)
  shFlex   the upper arm from the trunk's down line, + forward of it (near the trunk line its sign is unreliable)
  shAbd    the upper arm out to the side
  elbow    the elbow's bend (0: straight)
  kneeR/L  the knees' bends (0: straight)
  wristY-ank, wristY-sh   the wrist's height over the lower ankle, and over (+) or under (-) the shoulder (m)
  wristFwd the wrist forward of the hips (m; depth is MediaPipe's least sure measure)

usage: pose_angles.py POSE.json [r|l] [--csv T0]   (the right or left arm; --csv: comma-separated, times from T0 s)
"""
import json
import math
import sys

import numpy as np

args = [a for a in sys.argv[1:]]
csv = "--csv" in args
t0 = 0.0
if csv:
    i = args.index("--csv")
    t0 = float(args[i + 1])
    del args[i:i + 2]
d = json.load(open(args[0]))
side = args[1] if len(args) > 1 else "r"
S, E, W = (12, 14, 16) if side == "r" else (11, 13, 15)


def ang(a, b):
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    return math.degrees(math.acos(max(-1.0, min(1.0, float(a @ b)))))


cols = ["t", "lean", "shFlex", "shAbd", "elbow", "kneeR", "kneeL", "wristY-ank", "wristY-sh", "wristFwd"]
print(",".join(cols) if csv else "frame " + " ".join("%6s" % c for c in cols))
for i, f in enumerate(d["frames"]):
    if not f["world"]:
        continue
    p = np.array(f["world"])
    hip = (p[23] + p[24]) / 2
    sh = (p[11] + p[12]) / 2
    up = sh - hip
    across = p[11] - p[12]
    fwd = np.cross(across, up)
    fwd = fwd / np.linalg.norm(fwd)
    if fwd[2] > 0:
        fwd = -fwd
    lean = math.degrees(math.atan2(float(-up[2]), float(-up[1])))
    arm = p[E] - p[S]
    flex = ang(arm, -up) * (1 if float(arm @ fwd) >= 0 else -1)
    out = across / np.linalg.norm(across) * (-1 if side == "r" else 1)
    abd = math.degrees(math.asin(max(-1.0, min(1.0, float(arm @ out) / np.linalg.norm(arm)))))
    elbow = 180 - ang(p[S] - p[E], p[W] - p[E])
    kr = 180 - ang(p[24] - p[26], p[28] - p[26])
    kl = 180 - ang(p[23] - p[25], p[27] - p[25])
    floor = max(p[27][1], p[28][1])
    row = [t0 + i / d["fps"], lean, flex, abd, elbow, kr, kl, floor - p[W][1], p[S][1] - p[W][1], float((p[W] - hip) @ fwd)]
    if csv:
        print("%.3f,%.0f,%.0f,%.0f,%.0f,%.0f,%.0f,%.2f,%.2f,%.2f" % tuple(row))
    else:
        print("%5d " % i + " ".join("%6.2f" % v if k == 0 or k >= 7 else "%6.0f" % v for k, v in enumerate(row)))

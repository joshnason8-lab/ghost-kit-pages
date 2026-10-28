#!/usr/bin/env python3
"""A clip of the game's from a video of a hurler: MediaPipe's pose landmarks (33 points a frame, in metres about the
hips; tools/mocap/video_pose.py) turned into the game's 17 bones' turns from their rest stance, as degrees (Euler YXZ,
as ToonBody.apply reads them) with the hips' lift: the same form as the Mixamo clips in assets/player/hero.json.

Each bone is turned the shortest way from its rest direction onto the direction the video shows (shoulder to elbow,
elbow to wrist, hip to knee...), the trunk and the head as whole frames (from the hips, the shoulders, the ears), the
upper arm twisted so the elbow bends on its hinge, the hand from the wrist, index and little finger (so the hurley it
holds turns with it), the foot from the heel to the toes (flat when the foot is flat). The landmarks are smoothed over
a few frames first (the video's jitter). The hips set so the lower ankle stays at the stance's height.

  python3 tools/mocap/video_clip.py <landmarks.json> <name> <first frame> <last frame> <contact frame> [fps]
      -> prints the clip's JSON (fps, contact as a fraction of the clip, yaw 0, frames)

The owner's videos (a free taken from the ground: the lift, the toss, the strike) are not kept in the repository; the
clip made from them is (assets/player/free.json): the front-on one, frames 56 to 190, the strike at 159:
  python3 tools/mocap/video_clip.py shot1.json Free_Strike 56 190 159   (wrapped as {"clips": ...})
"""
import json
import math
import pathlib
import sys

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bvh_clip import BONES, OFF, PARENT, arc, euler_yxz, game_fk  # noqa: E402

# MediaPipe's landmarks (the person's own left and right).
NOSE, L_EAR, R_EAR = 0, 7, 8
L_SH, R_SH, L_EL, R_EL, L_WR, R_WR = 11, 12, 13, 14, 15, 16
L_PINKY, R_PINKY, L_INDEX, R_INDEX = 17, 18, 19, 20
L_HIP, R_HIP, L_KNEE, R_KNEE, L_ANK, R_ANK = 23, 24, 25, 26, 27, 28
L_HEEL, R_HEEL, L_TOE, R_TOE = 29, 30, 31, 32


HURLEY = np.array([0.05, -0.62, 0.78]) / np.linalg.norm([0.05, -0.62, 0.78])   # ToonBody.HURLEY_DIR


def smoothstep(a, b, x):
    k = max(0.0, min(1.0, (x - a) / (b - a)))
    return k * k * (3 - 2 * k)


def unit(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


def frame_from(x, y):
    """The turn whose x and y axes are (as near as can be) these: x kept, y made square to it."""
    x = unit(x)
    y = unit(y - x * np.dot(x, y))
    z = np.cross(x, y)
    return np.column_stack([x, y, z])


def slerp_m(a, b, t):
    """Part way from turn a to turn b."""
    r = a.T @ b
    ang = math.acos(max(-1.0, min(1.0, (np.trace(r) - 1.0) * 0.5)))
    if ang < 1e-6:
        return a.copy()
    axis = unit(np.array([r[2, 1] - r[1, 2], r[0, 2] - r[2, 0], r[1, 0] - r[0, 1]]))
    k = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
    a2 = ang * t
    return a @ (np.eye(3) + math.sin(a2) * k + (1 - math.cos(a2)) * (k @ k))


def smooth(p, sigma):
    """Each landmark's track smoothed with a Gaussian of sigma frames (held at the ends)."""
    if sigma <= 0:
        return p
    r = int(math.ceil(sigma * 3))
    w = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    w /= w.sum()
    pad = np.concatenate([np.repeat(p[:1], r, 0), p, np.repeat(p[-1:], r, 0)])
    out = np.zeros_like(p)
    for i in range(len(p)):
        out[i] = np.tensordot(w, pad[i:i + 2 * r + 1], axes=(0, 0))
    return out


def limb(parent, rest_dir, d, hinge_rest=None, hinge=None):
    """A bone's world turn: its parent's, turned the shortest way so its rest direction lies along d; with a hinge, then
    twisted about d so its rest hinge axis lies along the hinge seen (the elbow bends the way it does)."""
    r = arc(parent @ rest_dir, d) @ parent
    if hinge is not None and np.linalg.norm(hinge) > 1e-6:
        h_now = r @ hinge_rest
        h_now = unit(h_now - d * np.dot(d, h_now))
        h_want = unit(hinge - d * np.dot(d, hinge))
        ang = math.atan2(np.dot(np.cross(h_now, h_want), unit(d)), np.dot(h_now, h_want))
        r = axis_turn(unit(d), ang) @ r
    return r


def axis_turn(axis, ang):
    k = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
    return np.eye(3) + math.sin(ang) * k + (1 - math.cos(ang)) * (k @ k)


def turns_of(p):
    """One frame's landmarks (game axes: +X the man's left, +Y up, +Z ahead of him at rest) -> each bone's world turn."""
    t = {}
    mid_hip = (p[L_HIP] + p[R_HIP]) * 0.5
    mid_sh = (p[L_SH] + p[R_SH]) * 0.5
    t["hips"] = frame_from(p[L_HIP] - p[R_HIP], mid_sh - mid_hip)
    chest = frame_from(p[L_SH] - p[R_SH], mid_sh - mid_hip)
    t["spine"] = slerp_m(t["hips"], chest, 0.5)
    t["chest"] = chest
    mid_ear = (p[L_EAR] + p[R_EAR]) * 0.5
    head = frame_from(p[L_EAR] - p[R_EAR], mid_ear - mid_sh)
    # The face looks along +Z at rest: tilt the head so the nose is ahead of the ears as seen.
    t["neck"] = slerp_m(chest, head, 0.5)
    t["head"] = head
    for side, sh, el, wr, idx, pk, s in (("l", L_SH, L_EL, L_WR, L_INDEX, L_PINKY, 1.0), ("r", R_SH, R_EL, R_WR, R_INDEX, R_PINKY, -1.0)):
        up_d = unit(p[el] - p[sh])
        fo_d = unit(p[wr] - p[el])
        # The elbow's hinge: across the arm (the man's left-right at rest, so a bend at rest brings the hand forward).
        hinge = np.cross(up_d, fo_d)
        rest_hinge = np.array([-1.0, 0.0, 0.0]) if s > 0 else np.array([-1.0, 0.0, 0.0])
        bend = math.degrees(math.acos(max(-1.0, min(1.0, float(np.dot(up_d, fo_d))))))
        upper = limb(t["chest"], unit(OFF["forearm_" + side]), up_d, rest_hinge if bend > 12 else None, hinge if bend > 12 else None)
        t["upperarm_" + side] = upper
        fore = limb(upper, unit(OFF["hand_" + side]), fo_d)
        t["forearm_" + side] = fore
        # The hand: along wrist to the fingers' middle, its palm's normal from the index and little finger.
        fingers = (p[idx] + p[pk]) * 0.5 - p[wr]
        across = p[idx] - p[pk]
        rest_dir = unit(OFF["hand_" + side])
        hand = limb(fore, rest_dir, unit(fingers), np.array([0.0, 0.0, 1.0]), unit(across))
        t["hand_" + side] = hand
    # The hurley (held in the right hand, along HURLEY_DIR at rest): the video does not show it, so it is aimed from the
    # hands. Both on the handle: along the line from the left hand (at its end) through the right. The right hand low
    # by the sliotar on the grass: its bas on the grass just ahead of the feet. Else it goes with the forearm.
    fore_r = t["forearm_r"]
    stick_rest = fore_r @ HURLEY
    ground = min(p[L_ANK][1], p[R_ANK][1]) - 0.08
    ahead = t["hips"][:, 2].copy()
    ahead[1] = 0
    ahead = unit(ahead)
    ball = (p[L_ANK] + p[R_ANK]) * 0.5 + ahead * 0.55
    ball[1] = ground + 0.03
    two = 1.0 - smoothstep(0.18, 0.38, float(np.linalg.norm(p[R_WR] - p[L_WR])))
    low = 1.0 - smoothstep(0.45, 0.8, float(p[R_WR][1] - ground))
    s_two = unit(p[R_WR] - p[L_WR] + (p[R_INDEX] - p[L_INDEX]) * 0.5)
    s_low = unit(ball - p[R_WR])
    want = unit(stick_rest * (1.0 - max(two, low)) + s_low * low * (1.0 - two) + s_two * two)
    t["hand_r"] = arc(stick_rest, want) @ fore_r
    for side, hip, kn, an, heel, toe in (("l", L_HIP, L_KNEE, L_ANK, L_HEEL, L_TOE), ("r", R_HIP, R_KNEE, R_ANK, R_HEEL, R_TOE)):
        th = limb(t["hips"], unit(OFF["shin_" + side]), unit(p[kn] - p[hip]))
        t["thigh_" + side] = th
        sh = limb(th, unit(OFF["foot_" + side]), unit(p[an] - p[kn]))
        t["shin_" + side] = sh
        # The foot: its toes (+Z at rest) along the heel-to-toe line seen, its sole as the leg leaves it.
        foot_fwd = unit(p[toe] - p[heel])
        t["foot_" + side] = limb(sh, np.array([0.0, 0.0, 1.0]), foot_fwd)
    return t


def main():
    src, name, a, b, contact = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
    fps = int(sys.argv[6]) if len(sys.argv) > 6 else 30
    d = json.loads(pathlib.Path(src).read_text())
    rows = [f["w"] for f in d["frames"][a:b + 1]]
    pts = np.array([[[q[0], -q[1], -q[2]] for q in r] for r in rows])     # MediaPipe (x right, y down, z away) -> game
    pts = smooth(pts, 1.4)
    # The man's heading at the first frame taken out: he faces +Z there.
    t0 = turns_of(pts[0])
    f0 = t0["hips"][:, 2].copy()
    f0[1] = 0
    yaw0 = math.atan2(f0[0], f0[2])
    unyaw = np.array([[math.cos(-yaw0), 0, math.sin(-yaw0)], [0, 1, 0], [-math.sin(-yaw0), 0, math.cos(-yaw0)]])
    rest_low = game_fk({bn: np.eye(3) for bn in BONES})["foot_l"][1]
    out = []
    for p in pts:
        t = turns_of(np.array([unyaw @ q for q in p]))
        at = game_fk(t)
        low = min(at["foot_l"][1], at["foot_r"][1])
        fr = {}
        for bn in BONES:
            local = t[bn] if PARENT[bn] is None else t[PARENT[bn]].T @ t[bn]
            fr[bn] = euler_yxz(local)
        fr["hips_y"] = round(float(rest_low - low), 3)
        out.append(fr)
    clip = {"fps": fps, "contact": round((contact - a) / float(b - a), 3), "yaw": 0.0, "source": "video (owner's)",
            "frames": out}
    print(f"{src}: frames {a}-{b} ({(b - a) / fps:.2f} s), contact at {(contact - a) / fps:.2f} s, "
          f"turned {math.degrees(yaw0):.0f} degrees", file=sys.stderr)
    print(json.dumps({name: clip}))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""The free-taker's clips, from the owner's slow-motion video of a free struck off the grass (shot 3: 240 frames a
second played at 30, the camera behind and to the side of him, the posts beyond): MediaPipe's pose landmarks
(tools/mocap/video_pose.py) for the body, and the hurley and the sliotar marked by hand on key frames (below), since
no tracker follows a pale stick against a grey sky.

  python3 tools/mocap/free_clip.py <landmarks.json (shot 3)> > assets/player/free.json

Two clips, each of the game's 17 bones' turns (Euler YXZ degrees, as ToonBody.apply reads them) a frame with the
hips' lift and their travel (root):
- Free_Ready: the stance he takes over the ball once it is down and holds while the free is aimed: upright, side-on to
  the posts (his left shoulder to them), the hurley in both hands in front of him (the video's frame 300).
- Free_Strike: from the stance, down to the ball (300 to 850, quickened), the bas slid under it and the lift, the
  ball rising on the hurley to his head, the toss, the backswing over his right shoulder and the strike as it drops
  past his waist out in front of him, and the follow-through (850 to 1300 at the real pace).

How the hurley is placed: the bas is marked in the image on key frames; its depth comes from the stick's length (the
hand to the bas is 0.85 m), toward or away from the camera as marked; between key frames it turns smoothly. The
right hand is turned so the hurley lies along it (the hurley is built along ToonBody.HURLEY_DIR from the right fist);
the left arm is set by IK so the left hand grips the shaft below the right (where the video shows it: low down for
the lift, beside the right for the swing). The man's travel: his feet stay where they are planted (the hips move over
them); the hips' height keeps the lower foot on the ground.

The sliotar is marked too, which gives the moments it comes up onto the bas, leaves it and is struck (scoop, release,
contact: written with the clip). The game moves it so: on the grass, on the bas as he lifts it, then thrown from the
bas to meet the bas again at contact (match.gd _lift_ball), at the waist out in front of him as the video has it.
"""
import json
import math
import pathlib
import sys

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bvh_clip import BONES, OFF, PARENT, arc, euler_yxz, game_fk  # noqa: E402
from video_clip import HURLEY, limb, slerp_m, smooth, turns_of, unit  # noqa: E402

W, H = 854, 480
SRC_FPS = 240.0          # the video's frames are 1/240 s apart (eight times slowed)
OUT_FPS = 60
STICK = 0.85             # the right wrist to the bas (m)
GRIP_R = np.array([0.056, -0.1, 0.0])      # the fist's middle from the wrist, where the handle passes (HeroBody.GRIP)
GRIP_L = GRIP_R * [-1, 1, 1]
HURLEY_L = HURLEY * [-1, 1, 1]            # the left fist's grip, mirrored

# Key frames, marked by eye on crops of 320 x 320 about the right wrist, drawn at twice the size: the bas's middle
# and the sliotar there (None where it is hidden or still), and which way the hurley leans in depth: +1 toward the
# camera, -1 away, 0 not plain from the picture (whichever keeps it nearer the key before).
KEYS = {
    300: ((440, 262), None, 0),
    450: ((545, 410), None, 0),
    600: ((535, 462), None, 0),
    760: ((540, 465), None, 0),
    850: ((530, 492), (528, 480), 0),
    880: ((535, 458), (518, 440), 0),
    900: ((540, 408), (520, 397), 0),
    920: ((545, 350), (512, 338), 0),
    940: ((530, 288), (500, 282), 0),
    960: ((530, 258), (493, 240), 0),
    980: ((518, 213), (495, 213), 0),
    1000: ((465, 180), (497, 200), 0),
    1020: ((450, 180), (500, 210), 0),
    1040: ((465, 245), (508, 273), 1),
    1060: ((475, 280), (525, 327), 1),
    1075: ((460, 282), (528, 350), 1),
    1090: ((420, 270), (538, 355), 1),
    1100: ((330, 260), (525, 352), 1),
    1106: ((270, 262), (522, 340), 1),
    1112: ((190, 258), (495, 325), 1),
    1118: ((155, 285), (470, 318), 1),
    1126: ((275, 358), (458, 320), 1),
    1140: ((435, 343), (450, 305), 0),
    1160: ((160, 300), None, 1),
    1190: ((235, 272), None, 1),
    1230: ((330, 228), None, 1),
    1280: ((365, 190), None, 1),
}
SCOOP, RELEASE, CONTACT = 880, 985, 1138
READY = 300
FIT = [0, 7, 8, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]


def crop_origin(n):
    cx, cy = n[16][0] * W, n[16][1] * H
    return min(max(cx - 160, 0), W - 320), min(max(cy - 160, 0), H - 320)


def ortho_fit(n, w):
    """The picture's pixels from MediaPipe's world (x right, y down, metres about the hips): px = s * world + t."""
    p = np.array([[n[i][0] * W, n[i][1] * H] for i in FIT])
    q = np.array([[w[i][0], w[i][1]] for i in FIT])
    pm, qm = p.mean(0), q.mean(0)
    s = float(((q - qm) * (p - pm)).sum() / ((q - qm) ** 2).sum())
    return s, pm - s * qm


def to_world(px, s, t):
    return (np.array(px, float) - t) / s


def key_data(frames):
    """Each key frame's hurley (unit, game axes) and sliotar (game axes about the hips, its depth for later)."""
    out = {}
    for f, (bas, ball, sign) in sorted(KEYS.items()):
        n, w = frames[f]["n"], frames[f]["w"]
        s, t = ortho_fit(n, w)
        x0, y0 = crop_origin(n)
        bas_w = to_world((x0 + bas[0] / 2.0, y0 + bas[1] / 2.0), s, t)
        wr = np.array(w[16][:2])
        d = bas_w - wr
        flat = float(np.linalg.norm(d))
        dz = math.sqrt(max(0.0, STICK * STICK - flat * flat))
        # Game axes: x the picture's right, y up, z toward the camera. Its depth is all the length the picture does not
        # show; marked 0, toward the camera or away, whichever is nearer the last key's hurley (it turns smoothly).
        vec = np.array([d[0], -d[1], dz * (-1.0 if sign < 0 else 1.0)])
        if sign == 0 and out:
            prev = out[max(out)]["stick"]
            away = np.array([d[0], -d[1], -dz])
            if np.dot(unit(away), prev) > np.dot(unit(vec), prev):
                vec = away
        ball_w = None
        if ball is not None:
            bw = to_world((x0 + ball[0] / 2.0, y0 + ball[1] / 2.0), s, t)
            ball_w = np.array([bw[0], -bw[1], 0.0])
        out[f] = {"stick": unit(vec), "ball": ball_w, "wr": np.array([w[16][0], -w[16][1], -w[16][2]])}
    return out


def interp_stick(keys, f):
    ks = sorted(keys)
    if f <= ks[0]:
        return keys[ks[0]]["stick"]
    if f >= ks[-1]:
        return keys[ks[-1]]["stick"]
    for a, b in zip(ks, ks[1:]):
        if a <= f <= b:
            k = (f - a) / float(b - a)
            k = k * k * (3 - 2 * k)
            va, vb = keys[a]["stick"], keys[b]["stick"]
            ang = math.acos(max(-1.0, min(1.0, float(np.dot(va, vb)))))
            if ang < 1e-4:
                return va
            return unit((math.sin((1 - k) * ang) * va + math.sin(k * ang) * vb) / math.sin(ang))


def resample(pts, f):
    i = int(math.floor(f))
    i = max(0, min(len(pts) - 2, i))
    k = f - i
    return pts[i] * (1 - k) + pts[i + 1] * k


def ik_arm(t, at, side, target):
    """One arm reaching target (the wrist), its elbow bending the way the video's does."""
    s = at["upperarm_" + side]
    a = float(np.linalg.norm(OFF["forearm_" + side]))
    b = float(np.linalg.norm(OFF["hand_" + side]))
    d_vec = target - s
    d = min(float(np.linalg.norm(d_vec)), (a + b) * 0.995)
    dirn = unit(d_vec)
    x = (a * a - b * b + d * d) / (2 * d)
    h = math.sqrt(max(0.0, a * a - x * x))
    pole = at["forearm_" + side] - s
    pole = pole - dirn * np.dot(pole, dirn)
    if np.linalg.norm(pole) < 1e-5:
        pole = np.array([0.0, -1.0, 0.0]) - dirn * dirn[1]
    elbow = s + dirn * x + unit(pole) * h
    wrist = s + dirn * d
    up_d = unit(elbow - s)
    fo_d = unit(wrist - elbow)
    hinge = np.cross(up_d, fo_d)
    bent = np.linalg.norm(hinge) > 0.05
    upper = limb(t["chest"], unit(OFF["forearm_" + side]), up_d, np.array([-1.0, 0.0, 0.0]) if bent else None,
                 hinge if bent else None)
    t["upperarm_" + side] = upper
    t["forearm_" + side] = limb(upper, unit(OFF["hand_" + side]), fo_d)


def reach(side):
    return (float(np.linalg.norm(OFF["forearm_" + side])) + float(np.linalg.norm(OFF["hand_" + side]))) * 0.97


def pose_frame(p, stick, grip):
    """One frame's world turns: the body from the landmarks, the right hand along the hurley, the left hand on it.
    Both hands hold the one stick: where the left cannot reach its place on the shaft, the hurley (both hands) is
    drawn toward it, as far as the right arm allows."""
    t = turns_of(p)
    t["hand_r"] = arc(t["forearm_r"] @ HURLEY, stick) @ t["forearm_r"]
    at = game_fk(t)
    wr = at["hand_r"].copy()
    for _ in range(6):
        hr = arc(t["forearm_r"] @ HURLEY, stick) @ t["forearm_r"]
        hl = arc(t["forearm_l"] @ HURLEY_L, stick) @ t["forearm_l"]
        wl = wr + hr @ GRIP_R + stick * grip - hl @ GRIP_L
        sl, sr = at["upperarm_l"], at["upperarm_r"]
        over = np.linalg.norm(wl - sl) - reach("l")
        if over > 0:
            wr = wr + unit(sl - wl) * over
        over = np.linalg.norm(wr - sr) - reach("r")
        if over > 0:
            wr = wr + unit(sr - wr) * over
        ik_arm(t, at, "r", wr)
        at = game_fk(t)
        wr = at["hand_r"].copy()
        t["hand_r"] = arc(t["forearm_r"] @ HURLEY, stick) @ t["forearm_r"]
        wl = wr + t["hand_r"] @ GRIP_R + stick * grip - hl @ GRIP_L
        ik_arm(t, at, "l", wl)
        t["hand_l"] = arc(t["forearm_l"] @ HURLEY_L, stick) @ t["forearm_l"]
        at = game_fk(t)
    return t


def to_clip(seq, root=True):
    """World turns per frame -> the clip's frames (local turns, hips' lift, the hips' travel over planted feet)."""
    rest_low = game_fk({bn: np.eye(3) for bn in BONES})["foot_l"][1]
    out = []
    rx = np.zeros(3)
    prev = None
    trail = []
    for t in seq:
        at = game_fk(t)
        feet = [at["foot_l"], at["foot_r"]]
        low = min(feet[0][1], feet[1][1])
        if root and prev is not None:
            # The planted feet stay put: the hips move against the feet's motion, weighted to the lower foot.
            wts = [math.exp(-((f[1] - low) / 0.035) ** 2) for f in feet]
            mv = sum(w * (f - g) for w, f, g in zip(wts, feet, prev)) / max(1e-6, sum(wts))
            rx = rx - np.array([mv[0], 0.0, mv[2]])
        prev = feet
        trail.append(rx.copy())
        fr = {}
        for bn in BONES:
            local = t[bn] if PARENT[bn] is None else t[PARENT[bn]].T @ t[bn]
            fr[bn] = euler_yxz(local)
        fr["hips_y"] = round(float(rest_low - low), 3)
        out.append(fr)
    # The travel smoothed a little, and written.
    tr = smooth(np.array(trail), 3.0)
    for fr, r in zip(out, tr):
        fr["hips_side"] = round(float(r[0]), 3)
        fr["hips_fwd"] = round(float(r[2]), 3)
    return out


def main():
    d = json.loads(pathlib.Path(sys.argv[1]).read_text())
    frames = d["frames"]
    pts = np.array([[[q[0], -q[1], -q[2]] for q in f["w"]] for f in frames])
    pts = smooth(pts, 6.0)
    keys = key_data(frames)
    # Grip: how far down the shaft the left hand is from the right (the wrists' distance along the hurley).
    grip = []
    for f in range(len(frames)):
        st = interp_stick(keys, f)
        g = float(np.dot(pts[f][15] - pts[f][16], st))
        grip.append(min(max(g, 0.07), 0.5))
    grip = smooth(np.array(grip)[:, None], 10.0)[:, 0]
    # Everything turned so he faces +Z in the stance (frame 300): the game turns him to the posts.
    t0 = turns_of(pts[READY])
    f0 = t0["hips"][:, 2].copy()
    f0[1] = 0
    yaw0 = math.atan2(f0[0], f0[2])
    unyaw = np.array([[math.cos(-yaw0), 0, math.sin(-yaw0)], [0, 1, 0], [-math.sin(-yaw0), 0, math.cos(-yaw0)]])

    def pose_at(f):
        p = resample(pts, f)
        p = np.array([unyaw @ q for q in p])
        return pose_frame(p, unyaw @ interp_stick(keys, f), float(resample(grip[:, None], f)[0]))

    clips = {}
    clips["Free_Ready"] = {"fps": OUT_FPS, "yaw": 0.0, "source": "video (owner's, slow motion)",
                           "frames": to_clip([pose_at(READY)], root=False)}
    # The strike: 300 to 850 in DOWN seconds (eased), then the real pace.
    down = 0.6
    seq, src = [], []
    m = int(down * OUT_FPS)
    for i in range(m):
        k = i / float(m)
        src.append(READY + (850 - READY) * (0.5 - 0.5 * math.cos(math.pi * k)))
    f = 850.0
    while f <= 1300.0:
        src.append(f)
        f += SRC_FPS / OUT_FPS
    seq = [pose_at(s) for s in src]

    def t_of(frame):
        return round(down + (frame - 850) / SRC_FPS, 3)

    clip = {"fps": OUT_FPS, "yaw": 0.0, "source": "video (owner's, slow motion)", "frames": to_clip(seq),
            "scoop": t_of(SCOOP), "release": t_of(RELEASE), "contact": t_of(CONTACT)}
    clip["contact_frac"] = round(clip["contact"] / ((len(seq) - 1) / OUT_FPS), 3)
    clips["Free_Strike"] = clip
    print(f"strike {len(seq)} frames ({(len(seq) - 1) / OUT_FPS:.2f} s): scoop {clip['scoop']} release "
          f"{clip['release']} contact {clip['contact']}", file=sys.stderr)
    print(json.dumps({"clips": clips}))


if __name__ == "__main__":
    main()

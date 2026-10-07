#!/usr/bin/env python3
"""Step 4: one player's skeleton over a stretch of time -> a game animation clip.

Measures joint angles from the 2D skeleton (side-on footage works best): trunk lean,
hips, knees, shoulders and elbows, plus how low the hips are. Writes a clip the game's
placeholder athletes play directly (game/mocap_clip.gd). Name the clip after the
move it shows: tackle_dive, struggle, hand_touch, toe_touch, defend_idle, raid_idle,
run. Clips in assets/mocap/ replace the hand-made animation for that move.

Usage:
  python to_clip.py runs/match1 --id 7 --start 12.0 --end 13.4 --name tackle_dive \
      --out ../../assets/mocap/tackle_dive.json
"""
import argparse
import json
import math
import pathlib

import numpy as np

L_SH, R_SH, L_EL, R_EL, L_WR, R_WR, L_HIP, R_HIP, L_KN, R_KN, L_AN, R_AN = 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16


def angle_from_down(a, b, facing):
    """Angle of segment a->b measured from straight down, positive toward the facing direction."""
    dx = (b[0] - a[0]) * facing
    dy = b[1] - a[1]  # image y grows downward
    return math.atan2(dx, dy)


def angle_from_up(a, b, facing):
    dx = (b[0] - a[0]) * facing
    dy = a[1] - b[1]
    return math.atan2(dx, dy)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run")
    ap.add_argument("--id", type=int, required=True)
    ap.add_argument("--start", type=float, required=True)
    ap.add_argument("--end", type=float, required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    data = json.loads((pathlib.Path(args.run) / "poses.json").read_text())

    rows = []
    for f in data["frames"]:
        if not (args.start <= f["t"] <= args.end):
            continue
        for p in f["people"]:
            if p["id"] == args.id:
                rows.append((f["t"], np.array(p["kp"])))
    if len(rows) < 3:
        raise SystemExit(f"player #{args.id} has only {len(rows)} frames in that window")

    # Which way is the player facing? Nose ahead of the hips means facing that way.
    nose_dx = np.median([kp[0][0] - (kp[L_HIP][0] + kp[R_HIP][0]) / 2 for _, kp in rows if kp[0][2] > 0.3] or [1.0])
    facing = 1.0 if nose_dx >= 0 else -1.0

    heights = []
    frames = []
    for t, kp in rows:
        hip = (kp[L_HIP][:2] + kp[R_HIP][:2]) / 2
        sh = (kp[L_SH][:2] + kp[R_SH][:2]) / 2
        ank = (kp[L_AN][:2] + kp[R_AN][:2]) / 2
        trunk = np.linalg.norm(sh - hip) or 1.0
        heights.append((ank[1] - hip[1]) / trunk)
        # Model conventions (human_model.gd): positive hip/shoulder = limb swings forward,
        # knee is negative when bent, elbow positive when bent, spine negative = lean forward.
        thigh_l = angle_from_down(kp[L_HIP], kp[L_KN], facing)
        thigh_r = angle_from_down(kp[R_HIP], kp[R_KN], facing)
        shin_l = angle_from_down(kp[L_KN], kp[L_AN], facing)
        shin_r = angle_from_down(kp[R_KN], kp[R_AN], facing)
        arm_l = angle_from_down(kp[L_SH], kp[L_EL], facing)
        arm_r = angle_from_down(kp[R_SH], kp[R_EL], facing)
        fore_l = angle_from_down(kp[L_EL], kp[L_WR], facing)
        fore_r = angle_from_down(kp[R_EL], kp[R_WR], facing)
        spine = -angle_from_up(hip, sh, facing)
        frames.append({
            "t": round(t - rows[0][0], 3),
            "spine": round(spine, 3),
            "hip_l": round(thigh_l, 3), "hip_r": round(thigh_r, 3),
            # Knees only bend one way; clamp camera-angle noise that reads as hyperextension.
            "knee_l": round(min(0.0, -(thigh_l - shin_l)), 3), "knee_r": round(min(0.0, -(thigh_r - shin_r)), 3),
            "sh_l": round(arm_l - spine, 3), "sh_r": round(arm_r - spine, 3),
            "el_l": round(max(0.0, fore_l - arm_l), 3), "el_r": round(max(0.0, fore_r - arm_r), 3),
        })
    stand = max(heights) or 1.0
    for fr, hgt in zip(frames, heights):
        fr["height"] = round(max(0.15, hgt / stand), 3)  # 1 = standing hip height, lower = crouched/diving

    # Light smoothing across frames.
    keys = [k for k in frames[0] if k != "t"]
    for k in keys:
        vals = [f[k] for f in frames]
        sm = np.convolve(np.pad(vals, (1, 1), mode="edge"), np.ones(3) / 3, mode="valid")
        for f, v in zip(frames, sm):
            f[k] = round(float(v), 3)
    clip = {"name": args.name, "source": data["video"], "player": args.id, "fps": data["fps"],
            "length": frames[-1]["t"], "frames": frames}
    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(clip))
    print(f"{len(frames)} frames, {clip['length']:.2f}s -> {out}")


if __name__ == "__main__":
    main()

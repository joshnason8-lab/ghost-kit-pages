#!/usr/bin/env python3
"""Renders an analysis video: the footage with court lines locked on, skeletons coloured by
team, the raider highlighted with live depth and speed, and a bird's-eye mini-map with trails.

Needs poses.json and tracks.json (and court_lock.json for a moving camera).

Usage:
  python render_analysis.py match.mp4 runs/match1 --raider 5 [--team-colors "left=255,255,255 right=255,150,40"] [--labels "left=Iran right=India"]
"""
import argparse
import json
import math
import pathlib
import subprocess

import cv2
import numpy as np

SKELETON = [(5, 7), (7, 9), (6, 8), (8, 10), (5, 6), (5, 11), (6, 12), (11, 12), (11, 13), (13, 15), (12, 14), (14, 16)]
HALF_W, HALF_L = 5.0, 6.5


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("run")
    ap.add_argument("--raider", help="track id of the raider to highlight")
    ap.add_argument("--team-colors", default="left=255,255,255 right=255,150,40", help="BGR per team")
    ap.add_argument("--labels", default="", help='e.g. "left=Iran right=India"')
    args = ap.parse_args()
    run = pathlib.Path(args.run)
    poses = json.loads((run / "poses.json").read_text())
    tracks = json.loads((run / "tracks.json").read_text())["tracks"]
    lock = None
    if (run / "court_lock.json").exists():
        lock = [np.array(f["M"]) for f in json.loads((run / "court_lock.json").read_text())["frames"]]
    team_col = {k: tuple(int(v) for v in c.split(",")) for k, c in (it.split("=") for it in args.team_colors.split())}
    labels = dict(it.split("=") for it in args.labels.split()) if args.labels else {}
    raider_col = (200, 60, 255)  # magenta (BGR)

    pos_at = {}
    for pid, tr in tracks.items():
        for p in tr["points"]:
            pos_at.setdefault(pid, {})[round(p["t"], 3)] = (p["x"], p["z"])

    cap = cv2.VideoCapture(args.video)
    fps = poses["fps"]
    w, h = poses["width"], poses["height"]
    tmp = run / "analysis_raw.mp4"
    vw = cv2.VideoWriter(str(tmp), cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    trails = {}
    raider_prev = None
    speed_s = 0.0
    lines = [((-HALF_W, -HALF_L), (-HALF_W, HALF_L)), ((HALF_W, -HALF_L), (HALF_W, HALF_L)), ((-HALF_W - 1, 0), (HALF_W + 1, 0))]
    for z in (-HALF_L, -4.75, -3.75, 3.75, 4.75, HALF_L):
        lines.append(((-HALF_W, z), (HALF_W, z)))
    fi = 0
    while True:
        ok, frame = cap.read()
        if not ok or fi >= len(poses["frames"]):
            break
        f = poses["frames"][fi]
        t = round(f["t"], 3)
        if lock is not None:
            M = lock[fi]
            for a, b in lines:
                pts = np.float32([[[a[0] + (b[0] - a[0]) * s, a[1] + (b[1] - a[1]) * s]] for s in np.linspace(0, 1, 24)])
                pr = cv2.perspectiveTransform(pts, M).astype(int).reshape(-1, 2)
                cv2.polylines(frame, [pr], False, (0, 230, 255), 2, cv2.LINE_AA)
        for p in f["people"]:
            pid = str(p["id"])
            if pid not in tracks:
                continue
            col = raider_col if pid == args.raider else team_col.get(tracks[pid]["team"], (200, 200, 200))
            kp = p["kp"]
            thick = 4 if pid == args.raider else 2
            for a, b in SKELETON:
                if kp[a][2] > 0.3 and kp[b][2] > 0.3:
                    cv2.line(frame, (int(kp[a][0]), int(kp[a][1])), (int(kp[b][0]), int(kp[b][1])), col, thick, cv2.LINE_AA)
            if pid == args.raider:
                x1, y1 = int(p["box"][0]), int(p["box"][1])
                cv2.putText(frame, "RAIDER", (x1, max(20, y1 - 8)), cv2.FONT_HERSHEY_DUPLEX, 0.7, raider_col, 2, cv2.LINE_AA)
        # Mini-map (bottom right).
        S = 18
        mw, mh = int((2 * HALF_L + 2) * S), int((2 * HALF_W + 2) * S)
        mm = np.full((mh, mw, 3), (150, 85, 35), np.uint8)
        def px(x, z):
            return int((z + HALF_L + 1) * S), int((x + HALF_W + 1) * S)
        cv2.rectangle(mm, px(-HALF_W, -HALF_L), px(HALF_W, HALF_L), (235, 235, 235), 1)
        cv2.line(mm, px(-HALF_W - 1, 0), px(HALF_W + 1, 0), (235, 235, 235), 2)
        for z in (-3.75, 3.75, -4.75, 4.75):
            cv2.line(mm, px(-HALF_W, z), px(HALF_W, z), (200, 200, 200), 1)
        for pid, d in pos_at.items():
            if t in d:
                trails.setdefault(pid, []).append(d[t])
                trails[pid] = trails[pid][-45:]
                col = raider_col if pid == args.raider else team_col.get(tracks[pid]["team"], (200, 200, 200))
                tr = [px(x, z) for x, z in trails[pid]]
                if len(tr) > 1:
                    cv2.polylines(mm, [np.int32(tr)], False, col, 1, cv2.LINE_AA)
                cv2.circle(mm, tr[-1], 5 if pid == args.raider else 4, col, -1, cv2.LINE_AA)
        oy, ox = h - mh - 40, w - mw - 90
        frame[oy:oy + mh, ox:ox + mw] = cv2.addWeighted(frame[oy:oy + mh, ox:ox + mw], 0.25, mm, 0.75, 0)
        cv2.rectangle(frame, (ox, oy), (ox + mw, oy + mh), (235, 235, 235), 1)
        # Raider readout.
        if args.raider and args.raider in pos_at and t in pos_at[args.raider]:
            x, z = pos_at[args.raider][t]
            team = tracks[args.raider]["team"]
            depth = z if team == "left" else -z
            if raider_prev is not None and t > raider_prev[0]:
                inst = math.hypot(x - raider_prev[1], z - raider_prev[2]) / (t - raider_prev[0])
                speed_s = speed_s * 0.85 + min(inst, 8.0) * 0.15
            raider_prev = (t, x, z)
            txt = f"raider depth {depth:4.1f} m   speed {speed_s:3.1f} m/s"
            zone = "past BONUS line" if depth > 4.75 else ("past BAULK line" if depth > 3.75 else "")
            cv2.rectangle(frame, (ox, oy - 58), (ox + mw, oy - 4), (20, 20, 20), -1)
            cv2.putText(frame, txt, (ox + 8, oy - 34), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1, cv2.LINE_AA)
            if zone:
                cv2.putText(frame, zone, (ox + 8, oy - 12), cv2.FONT_HERSHEY_SIMPLEX, 0.55, raider_col, 2, cv2.LINE_AA)
        if labels:
            lx = ox
            for team, name in labels.items():
                cv2.putText(frame, name, (lx, oy + mh + 24), cv2.FONT_HERSHEY_SIMPLEX, 0.6, team_col.get(team, (255, 255, 255)), 2, cv2.LINE_AA)
                lx += 120
        vw.write(frame)
        fi += 1
    vw.release()
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp), "-c:v", "libx264", "-pix_fmt", "yuv420p",
                    "-crf", "22", str(run / "analysis.mp4")], check=False)
    tmp.unlink(missing_ok=True)
    print(f"{fi} frames -> {run / 'analysis.mp4'}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Step 2: skeletons -> positions on the court, in metres.

Give the pixel positions of the four corners of the playing field (not the lobbies) as
they appear in the video, going round: far-left, far-right, near-right, near-left, with
the court's long side running left to right across the screen (a side-on camera).
Open <run>/frame0.jpg in any image viewer to read the pixel coordinates.

Court coordinates match the game: x across the court (-5..5, near side positive),
z along it (-6.5..6.5, left end negative), midline at z = 0.

Writes:
  <run>/tracks.json   per player id: [{t, x, z}] (smoothed), plus team guess
  <run>/topdown.mp4   a bird's-eye replay of everyone's movement

Usage:
  python court_map.py runs/match1 --corners "412,233 1508,240 1830,690 95,682"
"""
import argparse
import json
import pathlib
import subprocess

import cv2
import numpy as np

HALF_W, HALF_L = 5.0, 6.5
FIELD = np.float32([[-HALF_W, -HALF_L], [-HALF_W, HALF_L], [HALF_W, HALF_L], [HALF_W, -HALF_L]])  # (x, z)


def foot_point(p):
    kp = p["kp"]
    la, ra = kp[15], kp[16]
    if la[2] > 0.3 and ra[2] > 0.3:
        return (la[0] + ra[0]) / 2, max(la[1], ra[1])
    if la[2] > 0.3:
        return la[0], la[1]
    if ra[2] > 0.3:
        return ra[0], ra[1]
    x1, y1, x2, y2 = p["box"]
    return (x1 + x2) / 2, y2


def smooth(vals, k=5):
    if len(vals) < k:
        return vals
    pad = k // 2
    arr = np.pad(np.array(vals, dtype=float), (pad, pad), mode="edge")
    return list(np.convolve(arr, np.ones(k) / k, mode="valid"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run")
    ap.add_argument("--corners", required=True, help='"x,y x,y x,y x,y" far-left, far-right, near-right, near-left')
    ap.add_argument("--min-frames", type=int, default=15, help="drop tracks shorter than this")
    args = ap.parse_args()
    run = pathlib.Path(args.run)
    data = json.loads((run / "poses.json").read_text())
    img_pts = np.float32([[float(v) for v in c.split(",")] for c in args.corners.split()])
    H = cv2.getPerspectiveTransform(img_pts, FIELD)

    raw = {}
    for f in data["frames"]:
        for p in f["people"]:
            if p["id"] < 0:
                continue
            u, v = foot_point(p)
            x, z = cv2.perspectiveTransform(np.float32([[[u, v]]]), H)[0][0]
            # Ignore people well outside the court and lobbies (benches, officials, crowd).
            if abs(x) > HALF_W + 1.6 or abs(z) > HALF_L + 1.5:
                continue
            raw.setdefault(p["id"], []).append((f["t"], float(x), float(z)))

    tracks = {}
    for pid, pts in raw.items():
        if len(pts) < args.min_frames:
            continue
        ts = [p[0] for p in pts]
        xs = smooth([p[1] for p in pts])
        zs = smooth([p[2] for p in pts])
        med_z = float(np.median(zs))
        tracks[str(pid)] = {"team": "left" if med_z < 0 else "right",
                            "points": [{"t": t, "x": round(x, 3), "z": round(z, 3)} for t, x, z in zip(ts, xs, zs)]}
    (run / "tracks.json").write_text(json.dumps({"fps": data["fps"], "court": {"half_w": HALF_W, "half_l": HALF_L}, "tracks": tracks}))
    print(f"{len(tracks)} players on court -> {run / 'tracks.json'}")
    render_topdown(run, data, tracks)


def render_topdown(run, data, tracks):
    S = 40  # pixels per metre
    W, Hh = int((2 * HALF_L + 3) * S), int((2 * HALF_W + 3) * S)
    def px(x, z):
        return int((z + HALF_L + 1.5) * S), int((x + HALF_W + 1.5) * S)
    by_t = {}
    for pid, tr in tracks.items():
        for p in tr["points"]:
            by_t.setdefault(p["t"], []).append((pid, tr["team"], p["x"], p["z"]))
    tmp = run / "topdown_raw.mp4"
    vw = cv2.VideoWriter(str(tmp), cv2.VideoWriter_fourcc(*"mp4v"), data["fps"], (W, Hh))
    for f in data["frames"]:
        img = np.full((Hh, W, 3), (156, 79, 29), np.uint8)  # mat blue (BGR)
        white = (230, 239, 243)
        cv2.rectangle(img, px(-HALF_W, -HALF_L), px(HALF_W, HALF_L), white, 2)
        for z in (0.0,):
            cv2.line(img, px(-HALF_W - 1, z), px(HALF_W + 1, z), white, 3)
        for z in (-3.75, 3.75, -4.75, 4.75):
            cv2.line(img, px(-HALF_W, z), px(HALF_W, z), white, 1)
        for pid, team, x, z in by_t.get(f["t"], []):
            col = (31, 154, 255) if team == "left" else (109, 51, 232)
            cv2.circle(img, px(x, z), 9, col, -1, cv2.LINE_AA)
            cv2.putText(img, pid, (px(x, z)[0] + 10, px(x, z)[1] - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.45, white, 1, cv2.LINE_AA)
        cv2.putText(img, f"{f['t']:.1f}s", (10, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.6, white, 1, cv2.LINE_AA)
        vw.write(img)
    vw.release()
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp), "-c:v", "libx264", "-pix_fmt", "yuv420p",
                    str(run / "topdown.mp4")], check=False)


if __name__ == "__main__":
    main()

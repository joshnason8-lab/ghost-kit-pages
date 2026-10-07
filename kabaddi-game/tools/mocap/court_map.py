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

With a moving broadcast camera, run camera_track.py first and pass --camera; the corners
(or --points) are then read from the reference frame.

Instead of four corners you can give any 4+ known court points with --points
"u,v=x,z ..." in court metres, e.g. midline and baulk-line ends when the end lines are
out of shot: --points "699,306=-5,0 711,597=5,0 1077,308=-5,3.75 1202,597=5,3.75"

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
    ap.add_argument("--corners", help='"x,y x,y x,y x,y" far-left, far-right, near-right, near-left')
    ap.add_argument("--points", help='"u,v=x,z ..." any 4+ image points with known court positions in metres')
    ap.add_argument("--min-frames", type=int, default=15, help="drop tracks shorter than this")
    ap.add_argument("--video", help="the source video; lets teams be told apart by jersey colour "
                                    "(needed when a raider stays in the other half for the whole clip)")
    ap.add_argument("--camera", help="camera.json from camera_track.py, for panning/zooming footage; "
                                     "corners are then read from its reference frame")
    args = ap.parse_args()
    run = pathlib.Path(args.run)
    data = json.loads((run / "poses.json").read_text())
    if not args.points and not args.corners and not (run / "court_lock.json").exists():
        raise SystemExit("give --corners or --points (or run court_lock.py first)")
    H = np.eye(3)
    if args.points:
        img_pts, court_pts = [], []
        for item in args.points.split():
            uv, xz = item.split("=")
            img_pts.append([float(v) for v in uv.split(",")])
            court_pts.append([float(v) for v in xz.split(",")])
        H, _ = cv2.findHomography(np.float32(img_pts), np.float32(court_pts), 0)
    elif args.corners:
        img_pts = np.float32([[float(v) for v in c.split(",")] for c in args.corners.split()])
        H = cv2.getPerspectiveTransform(img_pts, FIELD)
    np.save(run / "court_H.npy", H)
    cam = json.loads(pathlib.Path(args.camera).read_text()) if args.camera else None
    lock = None
    if (run / "court_lock.json").exists():
        # Per-frame court fit from court_lock.py beats chaining camera motion.
        lock = [np.linalg.inv(np.array(f["M"])) for f in json.loads((run / "court_lock.json").read_text())["frames"]]
    cam_H = {}
    if cam:
        for i, f in enumerate(cam["frames"]):
            if f["H"] is not None:
                cam_H[i] = np.array(f["H"], dtype=np.float64)

    raw = {}
    for fi, f in enumerate(data["frames"]):
        Hf = H
        if lock is not None and fi < len(lock):
            Hf = lock[fi]
        elif cam:
            if fi not in cam_H:
                continue  # camera lost for this frame
            Hf = H @ cam_H[fi]  # frame pixels -> reference-frame pixels -> court
        for p in f["people"]:
            if p["id"] < 0:
                continue
            u, v = foot_point(p)
            x, z = cv2.perspectiveTransform(np.float32([[[u, v]]]), Hf)[0][0]
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
        # Officials and benches stand outside the field and lobbies most of the time.
        if abs(float(np.median(xs))) > HALF_W + 1.0 or abs(float(np.median(zs))) > HALF_L + 0.3:
            continue
        med_z = float(np.median(zs))
        tracks[str(pid)] = {"team": "left" if med_z < 0 else "right",
                            "points": [{"t": t, "x": round(x, 3), "z": round(z, 3)} for t, x, z in zip(ts, xs, zs)]}
    if args.video and len(tracks) >= 2:
        assign_teams_by_colour(args.video, data, tracks)
    (run / "tracks.json").write_text(json.dumps({"fps": data["fps"], "court": {"half_w": HALF_W, "half_l": HALF_L}, "tracks": tracks}))
    print(f"{len(tracks)} players on court -> {run / 'tracks.json'}")
    render_topdown(run, data, tracks)


def assign_teams_by_colour(video, data, tracks):
    """Clusters players into two teams by torso colour, then names each team by the half it defends."""
    cols = {pid: [] for pid in tracks}
    cap = cv2.VideoCapture(video)
    fi = 0
    while True:
        ok, frame = cap.read()
        if not ok or fi >= len(data["frames"]):
            break
        if fi % 3 == 0:
            lab = cv2.cvtColor(frame, cv2.COLOR_BGR2LAB)
            for p in data["frames"][fi]["people"]:
                pid = str(p["id"])
                if pid not in cols:
                    continue
                kp = p["kp"]
                torso = [kp[i] for i in (5, 6, 11, 12) if kp[i][2] > 0.3]
                if len(torso) < 4:
                    continue
                xs = [k[0] for k in torso]
                ys = [k[1] for k in torso]
                x0, x1 = int(min(xs)), int(max(xs))
                y0, y1 = int(min(ys)), int(max(ys))
                # Inner part of the torso: the jersey, not the background.
                dx, dy = (x1 - x0) // 4, (y1 - y0) // 5
                patch = lab[y0 + dy:y1 - dy, x0 + dx:x1 - dx]
                if patch.size > 30:
                    cols[pid].append(np.median(patch.reshape(-1, 3), axis=0))
        fi += 1
    ids = [pid for pid in tracks if len(cols[pid]) >= 3]
    if len(ids) < 2:
        return
    feats = np.float32([np.median(cols[pid], axis=0) for pid in ids])
    _, labels, _ = cv2.kmeans(feats, 2, None, (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 50, 0.1), 8, cv2.KMEANS_PP_CENTERS)
    labels = labels.ravel()
    # A team's home half is where most of its players stand; raiders are the exception.
    halves = []
    for k in (0, 1):
        zs = [np.median([p["z"] for p in tracks[pid]["points"]]) for pid, l in zip(ids, labels) if l == k]
        halves.append(np.median([np.sign(z) for z in zs]) if zs else 0)
    names = {0: "left" if halves[0] <= halves[1] else "right", 1: "right" if halves[0] <= halves[1] else "left"}
    for pid, l in zip(ids, labels):
        tracks[pid]["team"] = names[int(l)]
        tracks[pid]["jersey_lab"] = [round(float(v), 1) for v in feats[ids.index(pid)]]


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

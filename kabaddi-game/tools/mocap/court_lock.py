#!/usr/bin/env python3
"""Locks the court to every frame of a moving-camera clip.

Starts from camera_track.py's estimate, then nudges each frame's court -> image
homography until the projected court lines sit on the white lines and red/blue lobby
edges actually visible in that frame. This removes the drift that builds up when a
camera pans for many seconds.

Writes <run>/court_lock.json: per frame, the court -> image homography (court metres
x, z -> pixels). court_map.py uses it automatically when present.

Usage:
  python court_lock.py match.mp4 runs/match1 --points "699,306=-5,0 711,597=5,0 1077,308=-5,3.75 1202,597=5,3.75" \
      --crop "50,28,1446,815" --mask "110,655,300,785"
"""
import argparse
import json
import pathlib

import cv2
import numpy as np
from scipy.ndimage import map_coordinates
from scipy.optimize import least_squares

HALF_W, HALF_L, LOBBY = 5.0, 6.5, 1.0


def court_samples():
    white, edge = [], []
    xs = np.linspace(-HALF_W, HALF_W, 40)
    for z in (-HALF_L, -4.75, -3.75, 3.75, 4.75, HALF_L):
        white += [(x, z) for x in xs]
    white += [(x, 0.0) for x in np.linspace(-HALF_W - LOBBY, HALF_W + LOBBY, 48)]   # midline crosses the lobbies
    zs = np.linspace(-HALF_L, HALF_L, 80)
    for x in (-HALF_W, HALF_W):          # field / lobby boundary
        edge += [(x, z) for z in zs]
    return np.float64(white), np.float64(edge)


def rects(s):
    return [tuple(int(v) for v in r.split(",")) for r in s.split()] if s else []


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("run")
    ap.add_argument("--points", required=True, help='"u,v=x,z ..." court points in the reference frame')
    ap.add_argument("--crop", default="")
    ap.add_argument("--mask", default="")
    args = ap.parse_args()
    run = pathlib.Path(args.run)
    cam = json.loads((run / "camera.json").read_text())
    poses = json.loads((run / "poses.json").read_text())
    img, court = [], []
    for it in args.points.split():
        a, b = it.split("=")
        img.append([float(v) for v in a.split(",")])
        court.append([float(v) for v in b.split(",")])
    H_ref, _ = cv2.findHomography(np.float32(court), np.float32(img), 0)   # court -> reference pixels
    white_pts, edge_pts = court_samples()

    cap = cv2.VideoCapture(args.video)
    out, prev_M, prev_cam = [], None, None
    i = 0
    while True:
        ok, fr = cap.read()
        if not ok:
            break
        h, w = fr.shape[:2]
        valid = np.zeros((h, w), np.uint8)
        if args.crop:
            x0, y0, x1, y1 = rects(args.crop)[0]
            valid[y0:y1, x0:x1] = 255
        else:
            valid[:] = 255
        for x0, y0, x1, y1 in rects(args.mask):
            valid[y0:y1, x0:x1] = 0
        for p in poses["frames"][i]["people"] if i < len(poses["frames"]) else []:
            x0, y0, x1, y1 = [int(v) for v in p["box"]]
            valid[max(0, y0 - 8):y1 + 8, max(0, x0 - 8):x1 + 8] = 0
        hsv = cv2.cvtColor(fr, cv2.COLOR_BGR2HSV)
        white = ((hsv[..., 1] < 70) & (hsv[..., 2] > 175)).astype(np.uint8) * 255
        red = (((hsv[..., 0] < 10) | (hsv[..., 0] > 165)) & (hsv[..., 1] > 70) & (hsv[..., 2] > 90)).astype(np.uint8) * 255
        red = cv2.morphologyEx(red, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
        edges = cv2.morphologyEx(red, cv2.MORPH_GRADIENT, np.ones((3, 3), np.uint8))
        white &= valid
        edges &= valid
        dw = np.minimum(cv2.distanceTransform(255 - white, cv2.DIST_L2, 3), 30.0)
        de = np.minimum(cv2.distanceTransform(255 - edges, cv2.DIST_L2, 3), 30.0)

        Hc = cam["frames"][i]["H"]
        if prev_M is None or Hc is None or prev_cam is None:
            M0 = (np.linalg.inv(np.array(Hc)) if Hc is not None else np.eye(3)) @ H_ref
        else:
            # Carry the previous lock forward by this frame's camera motion.
            F = np.linalg.inv(np.array(Hc)) @ np.array(prev_cam)
            M0 = F @ prev_M
        M0 = M0 / M0[2, 2]

        def project(M, pts):
            P = np.c_[pts, np.ones(len(pts))] @ M.T
            return P[:, :2] / P[:, 2:3]

        def residuals(p):
            M = np.append(p, 1.0).reshape(3, 3)
            res = []
            for pts, dmap, wgt in ((white_pts, dw, 1.0), (edge_pts, de, 0.7)):
                uv = project(M, pts)
                inside = (uv[:, 0] >= 0) & (uv[:, 0] < w - 1) & (uv[:, 1] >= 0) & (uv[:, 1] < h - 1)
                r = np.zeros(len(pts))
                u = uv[inside]
                ui = u.astype(int)
                vis = valid[ui[:, 1], ui[:, 0]] > 0
                # Bilinear sampling keeps the cost smooth so the optimiser can follow it.
                vals = map_coordinates(dmap, [u[:, 1], u[:, 0]], order=1, mode="nearest") * vis
                r[inside] = vals * wgt
                res.append(r)
            # Stay near the camera-tracked estimate where the lines say little.
            res.append((p - M0.flatten()[:8]) * np.array([20, 20, 0.05, 20, 20, 0.05, 2000, 2000]) * 0.2)
            return np.concatenate(res)

        sol = least_squares(residuals, M0.flatten()[:8], loss="soft_l1", f_scale=4.0, max_nfev=200, diff_step=1e-4)
        M = np.append(sol.x, 1.0).reshape(3, 3)
        before = float(np.mean(np.abs(residuals(M0.flatten()[:8])[:len(white_pts) + len(edge_pts)])))
        after = float(np.mean(np.abs(sol.fun[:len(white_pts) + len(edge_pts)])))
        out.append({"M": M.tolist(), "fit_before": round(before, 2), "fit_after": round(after, 2)})
        prev_M, prev_cam = M, Hc
        i += 1
    (run / "court_lock.json").write_text(json.dumps({"frames": out}))
    fb = [f["fit_before"] for f in out]
    fa = [f["fit_after"] for f in out]
    print(f"{len(out)} frames locked; mean line distance {np.mean(fb):.2f} -> {np.mean(fa):.2f} px")


if __name__ == "__main__":
    main()

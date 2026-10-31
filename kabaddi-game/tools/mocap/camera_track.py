#!/usr/bin/env python3
"""Follows a panning / zooming camera so court positions stay correct.

A broadcast camera turns and zooms on a fixed mount, so any two frames are related by a
homography. This matches background features (court lines, boards, stands) between each
frame and a reference frame, ignoring the players (from poses.json) and any on-screen
graphics you mask out, and writes the frame -> reference homography for every frame.

Usage:
  python camera_track.py match.mp4 runs/match1 --ref 0 \
      --mask "110,655,300,785 1360,30,1446,130"   # scorebug, channel logo (x0,y0,x1,y1)
      --crop "50,28,1446,815"                     # the video area inside a screen recording
"""
import argparse
import json
import pathlib

import cv2
import numpy as np


def rects(s):
    return [tuple(int(v) for v in r.split(",")) for r in s.split()] if s else []


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("run")
    ap.add_argument("--ref", type=int, default=0, help="reference frame index (the one you read court points from)")
    ap.add_argument("--mask", default="", help="screen areas to ignore, x0,y0,x1,y1 ...")
    ap.add_argument("--crop", default="", help="only use this area, x0,y0,x1,y1")
    args = ap.parse_args()
    run = pathlib.Path(args.run)
    poses = json.loads((run / "poses.json").read_text())

    cap = cv2.VideoCapture(args.video)
    frames = []
    while True:
        ok, fr = cap.read()
        if not ok:
            break
        frames.append(cv2.cvtColor(fr, cv2.COLOR_BGR2GRAY))
    h, w = frames[0].shape

    def mask_for(i):
        m = np.zeros((h, w), np.uint8)
        if args.crop:
            x0, y0, x1, y1 = rects(args.crop)[0]
            m[y0:y1, x0:x1] = 255
        else:
            m[:] = 255
        for x0, y0, x1, y1 in rects(args.mask):
            m[y0:y1, x0:x1] = 0
        if i < len(poses["frames"]):
            for p in poses["frames"][i]["people"]:
                x0, y0, x1, y1 = [int(v) for v in p["box"]]
                pad = 12
                m[max(0, y0 - pad):y1 + pad, max(0, x0 - pad):x1 + pad] = 0
        return m

    sift = cv2.SIFT_create(nfeatures=3000)
    matcher = cv2.BFMatcher(cv2.NORM_L2)
    feats = [sift.detectAndCompute(frames[i], mask_for(i)) for i in range(len(frames))]

    def homography(a, b):
        ka, da = feats[a]
        kb, db = feats[b]
        if da is None or db is None or len(ka) < 12 or len(kb) < 12:
            return None, 0
        good = [m for m, n in matcher.knnMatch(da, db, k=2) if m.distance < 0.75 * n.distance]
        if len(good) < 12:
            return None, 0
        src = np.float32([ka[m.queryIdx].pt for m in good])
        dst = np.float32([kb[m.trainIdx].pt for m in good])
        H, inl = cv2.findHomography(src, dst, cv2.RANSAC, 3.0)
        return H, int(inl.sum()) if inl is not None else 0

    # Chain frame-to-frame homographies outward from the reference, re-anchoring to the
    # reference directly whenever that match is strong (stops drift building up).
    out = [None] * len(frames)
    out[args.ref] = np.eye(3)
    quality = [0] * len(frames)
    for step, rng in ((1, range(args.ref + 1, len(frames))), (-1, range(args.ref - 1, -1, -1))):
        for i in rng:
            prev = i - step
            Hd, nd = homography(i, args.ref)
            if Hd is not None and nd >= 60:
                out[i], quality[i] = Hd, nd
                continue
            Hs, ns = homography(i, prev)
            if Hs is not None and out[prev] is not None and ns >= 25:
                out[i], quality[i] = out[prev] @ Hs, ns
    lost = sum(1 for H in out if H is None)
    (run / "camera.json").write_text(json.dumps({
        "ref": args.ref,
        "frames": [{"H": None if H is None else H.tolist(), "inliers": q} for H, q in zip(out, quality)],
    }))
    print(f"{len(frames)} frames, {lost} without a camera fix -> {run / 'camera.json'}")


if __name__ == "__main__":
    main()

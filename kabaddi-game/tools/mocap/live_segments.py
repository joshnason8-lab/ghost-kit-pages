#!/usr/bin/env python3
"""Finds where a clip is not live play: frozen stretches (a paused screen recording, a freeze-frame replay
intro) and hard cuts. Writes <run>/live.json, which raid_events.py reads so that paused time is not counted
as raid time and nothing is measured across a cut.

Usage:
  python live_segments.py match.mp4 runs/match1
"""
import argparse
import json
import pathlib

import cv2
import numpy as np


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("run")
    ap.add_argument("--still", type=float, default=0.6, help="mean grey change below this is a frozen frame")
    ap.add_argument("--cut", type=float, default=25.0, help="mean grey change above this is a cut")
    args = ap.parse_args()
    cap = cv2.VideoCapture(args.video)
    fps = cap.get(cv2.CAP_PROP_FPS)
    prev, i, ts, diffs = None, 0, [], []
    while True:
        ok, f = cap.read()
        if not ok:
            break
        h, w = f.shape[:2]
        # The middle of the picture: overlays in the corners and along the bottom change on their own.
        g = cv2.cvtColor(cv2.resize(f[h // 6:h * 7 // 8, w // 6:w * 5 // 6], (220, 130)), cv2.COLOR_BGR2GRAY)
        g = g.astype(np.float32)
        if prev is not None:
            ts.append(i / fps)
            diffs.append(float(np.mean(np.abs(g - prev))))
        prev, i = g, i + 1
    frozen, start = [], None
    for t, d in zip(ts, diffs):
        if d < args.still and start is None:
            start = t - 1 / fps
        elif d >= args.still and start is not None:
            if t - start >= 0.15:
                frozen.append([round(start, 3), round(t - 1 / fps, 3)])
            start = None
    if start is not None:
        frozen.append([round(start, 3), round(ts[-1], 3)])
    cuts = [round(t, 3) for t, d in zip(ts, diffs) if d > args.cut]
    out = {"fps": fps, "frames": i, "frozen": frozen, "cuts": cuts}
    pathlib.Path(args.run, "live.json").write_text(json.dumps(out, indent=1))
    print(f"{i} frames; frozen {frozen}; cuts {cuts}")


if __name__ == "__main__":
    main()

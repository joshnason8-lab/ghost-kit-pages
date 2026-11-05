#!/usr/bin/env python3
"""Checks court_map.py against ground truth recorded by tests/record_footage.tscn.

Matches each tracked position to the nearest true player in the same frame and reports
the position error in metres.

Usage:
  python eval_truth.py runs/game_footage truth.json
"""
import json
import pathlib
import sys

import numpy as np


def main():
    run = pathlib.Path(sys.argv[1])
    truth = json.loads(pathlib.Path(sys.argv[2]).read_text())
    tracks = json.loads((run / "tracks.json").read_text())
    fps = tracks["fps"]
    by_frame = {}
    for pid, tr in tracks["tracks"].items():
        for p in tr["points"]:
            by_frame.setdefault(int(round(p["t"] * fps)), []).append((p["x"], p["z"]))
    errs, found, total = [], 0, 0
    for f in truth["frames"]:
        true_pts = [(p["x"], p["z"]) for p in f["players"]]
        total += len(true_pts)
        est = by_frame.get(f["i"], [])
        for tx, tz in true_pts:
            if not est:
                continue
            d = min(((tx - x) ** 2 + (tz - z) ** 2) ** 0.5 for x, z in est)
            if d < 1.5:
                errs.append(d)
                found += 1
    print(f"players found {found}/{total} ({100 * found / max(total, 1):.0f}%), "
          f"position error median {np.median(errs):.2f} m, 90th pct {np.percentile(errs, 90):.2f} m")


if __name__ == "__main__":
    main()

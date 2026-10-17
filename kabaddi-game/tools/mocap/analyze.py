#!/usr/bin/env python3
"""Step 3: court positions -> numbers the game AI can use.

Finds raids (one player alone in the opposing half), then measures how raiders and
defenders actually move. Writes <run>/motion_stats.json and prints a summary.

The game reads these values (see game/match.gd): defender line depth, chain width,
how close defenders let the raider come, raider speeds, raid length.

Usage:
  python analyze.py runs/match1
"""
import argparse
import json
import pathlib

import numpy as np


def speed_series(points):
    out = []
    for a, b in zip(points, points[1:]):
        dt = b["t"] - a["t"]
        if dt > 0:
            out.append(((b["x"] - a["x"]) ** 2 + (b["z"] - a["z"]) ** 2) ** 0.5 / dt)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run")
    args = ap.parse_args()
    run = pathlib.Path(args.run)
    data = json.loads((run / "tracks.json").read_text())
    tracks = data["tracks"]
    if not tracks:
        print("no tracks")
        return

    # Index positions by time.
    by_t = {}
    for pid, tr in tracks.items():
        for p in tr["points"]:
            by_t.setdefault(round(p["t"], 3), {})[pid] = (p["x"], p["z"], tr["team"])
    times = sorted(by_t)

    # A raid frame: exactly one player standing in the other team's half.
    raid_frames = []
    for t in times:
        intruders = [(pid, x, z, team) for pid, (x, z, team) in by_t[t].items()
                     if (team == "left" and z > 0.3) or (team == "right" and z < -0.3)]
        if len(intruders) == 1:
            raid_frames.append((t, intruders[0]))

    # Group into raids.
    raids = []
    for t, (pid, x, z, team) in raid_frames:
        if raids and raids[-1]["raider"] == pid and t - raids[-1]["end"] < 1.0:
            raids[-1]["end"] = t
            raids[-1]["samples"].append((t, x, z))
        else:
            raids.append({"raider": pid, "team": team, "start": t, "end": t, "samples": [(t, x, z)]})
    raids = [r for r in raids if r["end"] - r["start"] >= 1.5]

    depths, gaps, widths, lines = [], [], [], []
    for r in raids:
        r["max_depth"] = max(abs(z) for _, _, z in r["samples"])
        depths.append(r["max_depth"])
        for t, rx, rz in r["samples"]:
            defs = [(x, z) for pid, (x, z, team) in by_t[t].items() if team != r["team"]]
            if len(defs) >= 3:
                d = sorted(((x - rx) ** 2 + (z - rz) ** 2) ** 0.5 for x, z in defs)
                gaps.append(d[0])
                xs = [x for x, _ in defs]
                widths.append(max(xs) - min(xs))
                lines.append(float(np.median([abs(z) for _, z in defs])))

    all_speeds = [s for tr in tracks.values() for s in speed_series(tr["points"])]
    raider_speeds = []
    for r in raids:
        pts = [{"t": t, "x": x, "z": z} for t, x, z in r["samples"]]
        raider_speeds += speed_series(pts)

    def pct(v, q):
        return round(float(np.percentile(v, q)), 2) if v else None

    stats = {
        "players_tracked": len(tracks),
        "raids_found": len(raids),
        "raid_seconds": {"median": pct([r["end"] - r["start"] for r in raids], 50), "max": pct([r["end"] - r["start"] for r in raids], 100)},
        "raider_max_depth_m": {"median": pct(depths, 50), "p90": pct(depths, 90)},
        "raider_speed_ms": {"median": pct(raider_speeds, 50), "p95": pct(raider_speeds, 95)},
        "any_player_speed_ms": {"median": pct(all_speeds, 50), "p95": pct(all_speeds, 95)},
        "nearest_defender_gap_m": {"p10": pct(gaps, 10), "median": pct(gaps, 50)},
        "defender_chain_width_m": {"median": pct(widths, 50)},
        "defender_line_depth_m": {"median": pct(lines, 50)},
        "raids": [{"raider": r["raider"], "start": r["start"], "end": r["end"], "max_depth": round(r["max_depth"], 2)} for r in raids],
    }
    (run / "motion_stats.json").write_text(json.dumps(stats, indent=2))
    for k, v in stats.items():
        if k != "raids":
            print(f"{k:28s} {v}")


if __name__ == "__main__":
    main()

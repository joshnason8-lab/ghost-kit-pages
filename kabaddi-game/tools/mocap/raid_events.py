#!/usr/bin/env python3
"""Step 4: what happens inside a raid, as timings the game AI can be tuned to.

analyze.py gives the shape of play (depths, spacing, speeds); this follows one raid moment by moment:
  - the raider's path: how deep he goes, how fast he moves probing and escaping, forward, sideways and
    back, how often he changes direction (feints), and the gap he keeps to the nearest defender;
  - the defence's shape while he works: the line's depth from the midline and its spread across;
  - the moments that decide a raid, marked by eye in <run>/events.json (see footage/clip2.events.json):
    hand touches, toe touches and kicks, defenders' dives and blocks, counter-reaches, help arriving. Each
    is measured from the tracking: gap to the nearest defender, the raider's depth and speed, time since
    he came in. Without an events file, attempts are read from the skeleton instead (an arm straightened
    out and up, a foot slid far out, a straight leg swung high), which misses many.

Times are play time: stretches frozen in the video (live_segments.py) don't count. A raider whose
tracking broke into pieces is joined up (same team, close in time and place), or listed in events.json.
Several runs at once also print the numbers combined (--out saves them, as footage/style.json).

Usage:
  python raid_events.py runs/c1 runs/c2 runs/c3 runs/c4 --out footage/style.json
  python raid_events.py runs/match1 --raider 3,86 --from 0 --to 17.1
"""
import argparse
import json
import math
import pathlib

import numpy as np

TORSO_M = 0.5        # shoulder-to-hip length of a 1.78 m player, metres
BAULK, BONUS = 3.75, 4.75
L_SH, R_SH, L_EL, R_EL, L_WR, R_WR, L_HIP, R_HIP, L_KN, R_KN, L_AN, R_AN = 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16


def pct(v, q):
    return round(float(np.percentile(v, q)), 2) if len(v) else None


def series(points, t0, t1):
    pts = [p for p in points if t0 <= p["t"] <= t1]
    return np.array([p["t"] for p in pts]), np.array([[p["x"], p["z"]] for p in pts])


def velocity(ts, xz, span=0.2):
    """Central differences over about `span` seconds."""
    v = np.zeros_like(xz)
    for i in range(len(ts)):
        j0 = np.searchsorted(ts, ts[i] - span / 2)
        j1 = min(len(ts) - 1, np.searchsorted(ts, ts[i] + span / 2))
        if ts[j1] - ts[j0] > 1e-3:
            v[i] = (xz[j1] - xz[j0]) / (ts[j1] - ts[j0])
    return v


def stitch_raider(tracks, ids):
    pts = []
    for pid in ids:
        pts += tracks[pid]["points"]
    pts.sort(key=lambda p: p["t"])
    return pts


def find_raider(tracks, t0, t1):
    """Intruder tracks (players in the other team's half), joined when one ends and the next starts nearby."""
    def intruding(tr):
        side = -1 if tr["team"] == "left" else 1      # the half a team defends
        zs = [p["z"] for p in tr["points"] if t0 <= p["t"] <= t1]
        return zs and np.median([z * side for z in zs]) < -0.3
    cands = sorted((pid for pid, tr in tracks.items() if intruding(tr)), key=lambda pid: tracks[pid]["points"][0]["t"])
    if not cands:
        return []
    # The longest intruder, then whatever continues it on either side.
    best = max(cands, key=lambda pid: len(tracks[pid]["points"]))
    chain = [best]
    for direction in (1, -1):
        cur = best
        while True:
            end = tracks[cur]["points"][-1] if direction > 0 else tracks[cur]["points"][0]
            nxt = None
            for pid in cands:
                if pid in chain or tracks[pid]["team"] != tracks[best]["team"]:
                    continue
                start = tracks[pid]["points"][0] if direction > 0 else tracks[pid]["points"][-1]
                gap = (start["t"] - end["t"]) * direction
                if -0.2 <= gap <= 0.8 and math.hypot(start["x"] - end["x"], start["z"] - end["z"]) < 1.5:
                    nxt = pid
                    break
            if not nxt:
                break
            chain.append(nxt)
            cur = nxt
    return sorted(chain, key=lambda pid: tracks[pid]["points"][0]["t"])


def body_frames(poses, tracks, ids, t0, t1):
    """The raider's skeleton per frame time. A track split by court_map.py ("12.1") is pose id 12 over the
    piece's own frames."""
    want = set()
    for pid in ids:
        base = int(pid.split(".")[0])
        want |= {(base, round(p["t"], 3)) for p in tracks[pid]["points"]}
    out = {}
    for f in poses["frames"]:
        if not t0 <= f["t"] <= t1:
            continue
        t = round(f["t"], 3)
        for p in f["people"]:
            if (p["id"], t) in want:
                out[t] = np.array(p["kp"])
    return out


def limb_measures(kp):
    """Reach of each hand and foot in torso lengths, or None where the body is not seen well."""
    ok = lambda *ix: all(kp[i][2] > 0.35 for i in ix)
    if not ok(L_SH, R_SH, L_HIP, R_HIP):
        return None
    sh = (kp[L_SH][:2] + kp[R_SH][:2]) / 2
    hip = (kp[L_HIP][:2] + kp[R_HIP][:2]) / 2
    L = float(np.linalg.norm(sh - hip))
    if L < 15:
        return None
    m = {"L": L, "hand": 0.0, "hand_side": None, "toe": 0.0, "kick": 0.0, "foot_side": None}
    for side, (s, e, w) in (("l", (L_SH, L_EL, L_WR)), ("r", (R_SH, R_EL, R_WR))):
        if not ok(s, e, w):
            continue
        reach = np.linalg.norm(kp[w][:2] - kp[s][:2]) / L
        up = (kp[s][1] - kp[w][1]) / L                # wrist above the shoulder is positive
        a, b = kp[s][:2] - kp[e][:2], kp[w][:2] - kp[e][:2]
        straight = float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-6))   # -1 = fully straight
        # A reach: the arm nearly straight and raised to shoulder height or close to it, not hanging down.
        score = reach if (straight < -0.75 and up > -0.55) else 0.0
        if score > m["hand"]:
            m["hand"], m["hand_side"] = float(score), side
    if ok(L_AN, R_AN, L_KN, R_KN):
        for side, (h, k, a, other) in (("l", (L_HIP, L_KN, L_AN, R_AN)), ("r", (R_HIP, R_KN, R_AN, L_AN))):
            out = abs(kp[a][0] - hip[0]) / L                 # foot out to the side of the body (screen)
            spread = np.linalg.norm(kp[a][:2] - kp[other][:2]) / L
            lift = (kp[other][1] - kp[a][1]) / L              # foot above the standing foot
            u, w = kp[h][:2] - kp[k][:2], kp[a][:2] - kp[k][:2]
            knee = float(np.dot(u, w) / (np.linalg.norm(u) * np.linalg.norm(w) + 1e-6))
            # A kick swings a straight leg out; a running stride lifts a bent one.
            if lift > 0.45 and out > 0.8 and knee < -0.75:
                if lift + out > m["kick"]:
                    m["kick"], m["foot_side"] = float(lift + out), side
            elif lift < 0.3 and spread > m["toe"]:
                m["toe"] = float(spread)
    return m


def peaks(ts, vals, thresh, min_gap=0.45, min_len=2):
    """Moments a measure rises past `thresh` (held for min_len frames), at its highest point."""
    out = []
    i = 0
    while i < len(vals):
        if vals[i] >= thresh:
            j = i
            while j + 1 < len(vals) and vals[j + 1] >= thresh * 0.9 and ts[j + 1] - ts[j] < 0.2:
                j += 1
            if j - i + 1 >= min_len:
                k = i + int(np.argmax(vals[i:j + 1]))
                if not out or ts[k] - out[-1][0] >= min_gap:
                    out.append((float(ts[k]), float(vals[k]), float(ts[i]), float(ts[j])))
            i = j + 1
        else:
            i += 1
    return out


def live_clock(run, t0, t1):
    """Video time -> play time, skipping frozen stretches (live_segments.py); None for a frame not to use."""
    path = run / "live.json"
    frozen = json.loads(path.read_text())["frozen"] if path.exists() else []
    def to_live(t):
        if not t0 <= t <= t1:
            return None
        lost = 0.0
        for a, b in frozen:
            if a < t <= b + 1e-6:
                return None                   # a repeat of the held frame
            if b < t:
                lost += b - a
        return round(t - lost, 3)
    return to_live, frozen


def retime(tracks, poses, to_live):
    for tr in tracks.values():
        pts = []
        for p in tr["points"]:
            t = to_live(p["t"])
            if t is not None:
                pts.append(dict(p, t=t, vt=p["t"]))
        tr["points"] = pts
    frames = []
    for f in poses["frames"]:
        t = to_live(f["t"])
        if t is not None:
            frames.append(dict(f, t=t, vt=f["t"]))
    poses["frames"] = frames


ATTEMPTS = ("hand", "toe", "kick")
HOLDS = ("dive", "block")


def at(ts, vals, t):
    """The value of a time series nearest to t (None when nothing within 0.1 s)."""
    if not len(ts):
        return None
    i = int(np.argmin(np.abs(ts - t)))
    return vals[i] if abs(ts[i] - t) <= 0.1 else None


def analyze_run(run, raider=None, t0v=None, t1v=None):
    data = json.loads((run / "tracks.json").read_text())
    poses = json.loads((run / "poses.json").read_text())
    marked = json.loads((run / "events.json").read_text()) if (run / "events.json").exists() else {}
    tracks = data["tracks"]
    t0v = t0v if t0v is not None else marked.get("from", 0.0)
    t1v = t1v if t1v is not None else marked.get("to", 1e9)
    # From here on times are play time: the clip with its frozen stretches taken out.
    to_live, frozen = live_clock(run, t0v, t1v)
    retime(tracks, poses, to_live)
    tracks = {pid: tr for pid, tr in tracks.items() if tr["points"]}
    t0, t1 = 0.0, 1e9
    to_video = {}
    for f in poses["frames"]:
        to_video[f["t"]] = f["vt"]
    vt = lambda t: to_video.get(round(t, 3), t)
    def live_of(video_t):
        lt = to_live(video_t)
        if lt is None:   # inside a frozen stretch: the frame it holds
            lt = max((t for t, v in to_video.items() if v <= video_t), default=0.0)
        return lt

    ids = raider or marked.get("raider") or find_raider(tracks, t0, t1)
    if not ids:
        raise SystemExit(f"{run}: no raider found; pass --raider")
    team = tracks[ids[0]]["team"]
    home = -1 if team == "left" else 1        # the raider's own half
    rpts = stitch_raider(tracks, ids)
    rt, rxz = series(rpts, t0, t1)
    rv = velocity(rt, rxz)
    depth = -home * rxz[:, 1]                  # metres into the defenders' half
    in_half = depth > 0.0

    # Path.
    speed = np.linalg.norm(rv, axis=1)
    fwd = -home * rv[:, 1]                     # positive going deeper, negative heading home
    lat = np.abs(rv[:, 0])
    cross = float(rt[np.argmax(in_half)]) if in_half.any() else None
    start = cross if cross is not None and cross > rt[0] + 0.1 else float(rt[0])
    reach_t = lambda line: next((float(t) for t, d in zip(rt, depth) if d >= line), None)
    reversals = 0
    last = 0
    for f in fwd:
        s = 1 if f > 0.6 else (-1 if f < -0.6 else 0)
        if s and last and s != last:
            reversals += 1
        if s:
            last = s
    dur = float(rt[-1] - rt[0])
    # Sustained top speed: best 0.5 s average.
    win = max(1, int(round(0.5 * data["fps"])))
    top = float(np.max(np.convolve(speed, np.ones(win) / win, mode="valid"))) if len(speed) >= win else float(np.max(speed))

    # Attempts read from the skeleton (a check on the marked ones, and a stand-in where none are marked).
    body = body_frames(poses, tracks, ids, t0, t1)
    bt = np.array(sorted(body))
    meas = [limb_measures(body[t]) for t in bt]
    hand = np.array([m["hand"] if m else 0.0 for m in meas])
    toe = np.array([m["toe"] if m else 0.0 for m in meas])
    kick = np.array([m["kick"] if m else 0.0 for m in meas])
    seen = np.array([m is not None for m in meas])
    auto = []
    for kind, vals, th in (("hand", hand, 1.15), ("toe", toe, 2.1), ("kick", kick, 1.6)):
        for t, v, a, b in peaks(bt, vals, th):
            auto.append({"t": round(t, 2), "video_t": round(vt(t), 2), "kind": kind, "reach_m": round(v * TORSO_M, 2)})
    auto.sort(key=lambda e: e["t"])
    # A hand reach at the same moment as a kick or toe touch is the arms balancing; keep the leg move.
    keep = []
    for e in auto:
        if keep and abs(e["t"] - keep[-1]["t"]) < 0.3:
            if keep[-1]["kind"] == "hand" and e["kind"] != "hand":
                keep[-1] = e
            continue
        keep.append(e)
    auto = keep

    # Defenders.
    rpos = {round(t, 3): xz for t, xz in zip(rt, rxz)}
    def_series = {}
    for pid, tr in tracks.items():
        if tr["team"] == team or pid in ids:
            continue
        dt_, dxz = series(tr["points"], t0, t1)
        common = [i for i, t in enumerate(dt_) if round(t, 3) in rpos]
        if len(common) < 5:
            continue
        # Officials: on a side line (umpires) or at the midline (the referee), not in the field.
        if abs(np.median(dxz[:, 0])) > 4.9 or np.median(-home * dxz[:, 1]) < 0.8:
            continue
        ts = dt_[common]
        dxz = dxz[common]
        dist = np.array([np.linalg.norm(dxz[i] - rpos[round(t, 3)]) for i, t in enumerate(ts)])
        # Closing speed from the defender's own movement towards the raider (the raider moving does not count).
        dv = velocity(ts, dxz)
        to_r = np.array([rpos[round(t, 3)] - dxz[i] for i, t in enumerate(ts)])
        unit = to_r / (np.linalg.norm(to_r, axis=1, keepdims=True) + 1e-6)
        def_series[pid] = (ts, dxz, dist, np.sum(dv * unit, axis=1), np.linalg.norm(dv, axis=1))
    def nearest(t):
        ds = [at(s[0], s[2], t) for s in def_series.values()]
        ds = [d for d in ds if d is not None]
        return min(ds) if ds else None
    gaps = [g for g in (nearest(t) for t in rt) if g is not None]
    # Defenders' own footwork: how fast they shuffle while the raider is in, and how far they step back.
    def_speed = [v for s in def_series.values() for v, d in zip(s[4], s[2]) if d < 4.0]
    backs = []
    for pid, (ts, _, dist, closing, _) in def_series.items():
        last_b = -9.0
        for i, t in enumerate(ts):
            if closing[i] < -1.2 and dist[i] < 2.5 and t - last_b > 1.0:
                backs.append({"t": round(float(t), 2), "video_t": round(vt(float(t)), 2), "defender": pid,
                              "gap_m": round(float(dist[i]), 2)})
                last_b = t
    # Linked pairs: two defenders within 1.1 m for a second or more.
    linked = set()
    keys = list(def_series)
    for a in range(len(keys)):
        for b in range(a + 1, len(keys)):
            ta, xa = def_series[keys[a]][:2]
            tb, xb = def_series[keys[b]][:2]
            ib = {round(t, 3): i for i, t in enumerate(tb)}
            run_len = 0
            for i, t in enumerate(ta):
                j = ib.get(round(t, 3))
                if j is not None and np.linalg.norm(xa[i] - xb[j]) < 1.1:
                    run_len += 1
                    if run_len >= data["fps"]:
                        linked.add((keys[a], keys[b]))
                else:
                    run_len = 0

    # Marked moments (events.json, read off the video by eye), measured from the tracking.
    events = []
    for e in marked.get("events", []):
        t = live_of(e["t"])
        g = nearest(t)
        d = at(rt, depth, t)
        sp = [v for tt, v in zip(rt, speed) if abs(tt - t) <= 0.2]
        events.append(dict(e, video_t=e["t"], t=round(t, 2), gap_m=round(float(g), 2) if g is not None else None,
                           depth_m=round(float(d), 2) if d is not None else None,
                           raider_ms=round(float(np.median(sp)), 2) if sp else None))
    attempts = [e for e in events if e["kind"] in ATTEMPTS] if marked else auto
    holds = [e for e in events if e["kind"] in HOLDS and e.get("hold")]
    dives = [e for e in events if e["kind"] in HOLDS]
    tackle = holds[0] if holds else None
    assists = [e for e in events if e["kind"] in ("assist", "swarm")]
    counters = []
    for e in events:
        if e["kind"] == "counter":
            prev = [a for a in attempts if abs(e["t"] - a["t"]) <= 0.6]
            counters.append(round(e["t"] - prev[0]["t"], 2) if prev else None)
    stance_gaps = []
    for e in events:
        if e["kind"] == "stance":
            nxt = min([x["t"] for x in events if x["t"] > e["t"]] + [float(rt[-1])])
            stance_gaps += [g for g in (nearest(t) for t in rt if e["t"] <= t <= nxt) if g is not None]
    # The defence's shape while he works: median depth of the line from the midline and its spread across,
    # over moments with three or more defenders in view (a camera on part of the court shows fewer).
    form_depth, form_width, form_stagger = [], [], []
    for t in rt[::5]:
        if tackle and t >= tackle["t"]:
            break
        pts = [at(s_[0], s_[1], t) for s_ in def_series.values()]
        pts = [p_ for p_ in pts if p_ is not None]
        if len(pts) >= 3:
            form_depth.append(float(np.median([-home * p_[1] for p_ in pts])))
            form_width.append(float(max(p_[0] for p_ in pts) - min(p_[0] for p_ in pts)))
            # How far apart front to back: the standard deviation of their depths (0 for a straight line).
            form_stagger.append(float(np.std([-home * p_[1] for p_ in pts])))
    before_tackle = [a for a in attempts if tackle and a["t"] < tackle["t"]]
    probe = [v for t, v in zip(rt, speed) if not tackle or t < tackle["t"] - 0.3]
    first = attempts[0]["t"] - start if attempts else None
    between = np.diff([a["t"] for a in attempts]).tolist()
    summary = {
        "note": marked.get("note"),
        "outcome": marked.get("outcome"),
        "raider_ids": ids,
        "team": team,
        "seen_s": round(dur, 2),
        "frozen_video_s": frozen,
        "start_video_s": round(vt(start), 2),
        "baulk_reached_after_s": round(reach_t(BAULK) - start, 2) if reach_t(BAULK) is not None else None,
        "max_depth_m": round(float(depth.max()), 2),
        "speed_ms": {"median": pct(speed, 50), "probing_median": pct(probe, 50), "p90": pct(speed, 90), "top_0.5s": round(top, 2)},
        "forward_ms": {"in_p90": pct(fwd[fwd > 0.3], 90), "out_p90": pct(-fwd[fwd < -0.3], 90)},
        "sideways_ms": {"median": pct(lat, 50), "p90": pct(lat, 90)},
        "direction_changes_per_s": round(reversals / dur, 2) if dur > 0 else None,
        "skeleton_seen": round(float(seen.mean()), 2) if len(seen) else 0.0,
        "attempts": attempts,
        "attempts_per_s": round(len(attempts) / max(0.1, float(rt[-1] - start)), 2),
        "first_attempt_after_s": round(first, 2) if first is not None else None,
        "between_attempts_s": [round(b, 2) for b in between],
        "attempt_gap_m": [a.get("gap_m") for a in attempts],
        "nearest_defender_m": {"min": pct(gaps, 0), "p10": pct(gaps, 10), "median": pct(gaps, 50)},
        "stance_gap_m": pct(stance_gaps, 50),
        "dives": dives,
        "tackle": tackle,
        "tackle_after_s": round(tackle["t"] - start, 2) if tackle else None,
        "attempts_before_tackle": len(before_tackle) if tackle else None,
        "help_after_hold_s": [round(a["t"] - tackle["t"], 2) for a in assists] if tackle else [],
        "counter_reach_after_attempt_s": counters,
        "defender_speed_near_ms": {"median": pct(def_speed, 50), "p90": pct(def_speed, 90)},
        "defenders_seen": max((len([1 for s_ in def_series.values() if at(s_[0], s_[1], t) is not None]) for t in rt), default=0),
        "defender_depth_m": pct(form_depth, 50),
        "defender_stagger_m": pct(form_stagger, 50),
        "defender_width_m": pct(form_width, 50),
        "step_backs": backs,
        "linked_pairs": sorted(linked),
        "auto_attempts": auto,
    }
    (run / "raid_events.json").write_text(json.dumps(summary, indent=1))
    return summary


def show(name, summary):
    print(f"== {name}")
    for k, v in summary.items():
        if k in ("attempts", "dives", "step_backs", "auto_attempts"):
            print(f"  {k}:")
            for e in v:
                print("     ", e)
        else:
            print(f"  {k:30s} {v}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("runs", nargs="+")
    ap.add_argument("--raider", help="track ids of the raider, comma separated (default: events.json, else found)")
    ap.add_argument("--from", dest="t0", type=float, help="video seconds")
    ap.add_argument("--to", dest="t1", type=float, help="video seconds")
    ap.add_argument("--out", help="write the combined numbers here (JSON)")
    args = ap.parse_args()
    all_s = {}
    for r in args.runs:
        run = pathlib.Path(r)
        s = analyze_run(run, args.raider.split(",") if args.raider else None, args.t0, args.t1)
        all_s[run.name] = s
        show(run.name, s)
    if len(all_s) < 2:
        return
    flat = lambda key: [v for s in all_s.values() for v in (s[key] or []) if v is not None]
    one = lambda key: [s[key] for s in all_s.values() if s[key] is not None]
    sub = lambda key, sk: [s[key][sk] for s in all_s.values() if s[key][sk] is not None]
    combined = {
        "clips": len(all_s),
        "tackled": sum(1 for s in all_s.values() if s["outcome"] == "tackled"),
        "first_attempt_after_s": one("first_attempt_after_s"),
        "between_attempts_s": {"median": pct(flat("between_attempts_s"), 50), "range": [pct(flat("between_attempts_s"), 0), pct(flat("between_attempts_s"), 100)]},
        "attempt_gap_m": {"median": pct(flat("attempt_gap_m"), 50), "range": [pct(flat("attempt_gap_m"), 0), pct(flat("attempt_gap_m"), 100)]},
        "attempts_per_s": one("attempts_per_s"),
        "stance_gap_m": one("stance_gap_m"),
        "nearest_defender_median_m": sub("nearest_defender_m", "median"),
        "raider_probing_ms": sub("speed_ms", "probing_median"),
        "raider_top_ms": sub("speed_ms", "top_0.5s"),
        "raider_sideways_p90_ms": sub("sideways_ms", "p90"),
        "max_depth_m": one("max_depth_m"),
        "dive_gap_m": [d["gap_m"] for s in all_s.values() for d in s["dives"] if d.get("gap_m") is not None],
        "tackle_after_s": one("tackle_after_s"),
        "attempts_before_tackle": one("attempts_before_tackle"),
        "help_after_hold_s": flat("help_after_hold_s"),
        "counter_reach_after_attempt_s": flat("counter_reach_after_attempt_s"),
        "defender_speed_near_ms": sub("defender_speed_near_ms", "median"),
        "defender_depth_m": one("defender_depth_m"),
        "defender_stagger_m": one("defender_stagger_m"),
        "defender_width_m": one("defender_width_m"),
        "defenders_seen": one("defenders_seen"),
    }
    print("== combined")
    for k, v in combined.items():
        print(f"  {k:30s} {v}")
    if args.out:
        pathlib.Path(args.out).write_text(json.dumps({"clips": all_s, "combined": combined}, indent=1))


if __name__ == "__main__":
    main()

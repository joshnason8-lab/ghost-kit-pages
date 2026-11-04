#!/usr/bin/env python3
"""Kho Kho's balance runs (.github/workflows/kho-kho-balance.yml): the MATCH_ROW lines of tests/match_sim, one
folder of logs a variant and format, into one table - outs, khos and fouls a minute, each with its 95% confidence
interval, and each variant against the game as it is (current) on the same seeds (paired: the same matches but for
the one change), with that difference's interval.
  python3 report.py LOGS_DIR > BALANCE.md      (LOGS_DIR/<variant>-<format>-<shard>/sim.log)
"""
import json, math, os, sys, collections

T95 = 1.96


def rows(path):
    out = []
    for line in open(path, errors="replace"):
        if line.startswith("MATCH_ROW "):
            out.append(json.loads(line[len("MATCH_ROW "):]))
    return out


def mean_ci(xs):
    n = len(xs)
    if n == 0:
        return (float("nan"), float("nan"), 0)
    m = sum(xs) / n
    if n < 2:
        return (m, float("nan"), n)
    sd = math.sqrt(sum((x - m) ** 2 for x in xs) / (n - 1))
    return (m, T95 * sd / math.sqrt(n), n)


def main(root):
    data = collections.defaultdict(dict)   # (variant, fmt) -> seed -> row
    for d in sorted(os.listdir(root)):
        p = os.path.join(root, d, "sim.log")
        if not os.path.isfile(p):
            continue
        variant, fmt = d.rsplit("-", 2)[0], d.rsplit("-", 2)[1]
        for r in rows(p):
            data[(variant, fmt)][r["seed"]] = r
    print("# Kho Kho Rush: balance runs\n")
    print("Each match: tests/match_sim (AI v AI, the village ground, %s-second turns), its seed's own pairing of sides." % "180")
    print("Rates are per match (a minute of play), then averaged; ± is the 95% confidence interval.\n")
    for fmt in ("classic", "fast"):
        cells = {v: s for (v, f), s in data.items() if f == fmt}
        if not cells:
            continue
        print("## %s\n" % fmt.capitalize())
        print("| variant | matches | outs a min | khos a min | fouls a min | outs vs current (same seeds) |")
        print("|---|---|---|---|---|---|")
        cur = cells.get("current", {})
        for v in ["current"] + sorted(k for k in cells if k != "current"):
            s = cells[v]
            per = lambda key: [r[key] / (r["secs"] / 60.0) for r in s.values() if r["secs"] > 0]
            o, oc, n = mean_ci(per("outs"))
            k, kc, _ = mean_ci(per("khos"))
            fo, fc, _ = mean_ci(per("fouls"))
            diff = ""
            if v != "current" and cur:
                both = [sd for sd in s if sd in cur]
                ds = [s[sd]["outs"] / (s[sd]["secs"] / 60.0) - cur[sd]["outs"] / (cur[sd]["secs"] / 60.0) for sd in both]
                dm, dc, dn = mean_ci(ds)
                sig = "" if math.isnan(dc) or abs(dm) <= dc else " (beyond chance)"
                diff = "%+.2f ± %.2f over %d pairs%s" % (dm, dc, dn, sig)
            print("| %s | %d | %.2f ± %.2f | %.1f ± %.1f | %.2f ± %.2f | %s |" % (v, n, o, oc, k, kc, fo, fc, diff))
        print()
    print("Variants: tools/balance/*.patch, each applied to a copy of the game for its run (never to the game).")


if __name__ == "__main__":
    main(sys.argv[1])

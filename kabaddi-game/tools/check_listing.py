#!/usr/bin/env python3
"""Check the Play store listing texts (store/listing/*.txt) against Play Console's limits: app name 30 characters,
short description 80, full description 4000, release notes 500. Prints each language's lengths; exits 1 if any is
over or missing.

    python3 tools/check_listing.py
"""
import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LIMITS = {"App name": 30, "Short description": 80, "Full description": 4000, "Release notes (first release)": 500}


def sections(path):
    out, cur = {}, None
    for line in open(path, encoding="utf-8").read().splitlines():
        if line.startswith("#") and cur is None:
            continue
        if line.startswith("== ") and line.endswith(" =="):
            cur = line[3:-3]
            out[cur] = []
        elif cur is not None:
            out[cur].append(line)
    return {k: "\n".join(v).strip() for k, v in out.items()}


def main():
    bad = 0
    for path in sorted(glob.glob(os.path.join(HERE, "..", "store", "listing", "*.txt"))):
        s = sections(path)
        parts = []
        for name, limit in LIMITS.items():
            n = len(s.get(name, ""))
            ok = 0 < n <= limit
            bad += not ok
            parts.append("%s %d/%d%s" % (name.split()[0].lower(), n, limit, "" if ok else " BAD"))
        print("%-10s %s" % (os.path.basename(path)[:-4], ", ".join(parts)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

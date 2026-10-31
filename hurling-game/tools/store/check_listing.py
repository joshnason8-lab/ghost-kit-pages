#!/usr/bin/env python3
"""Counts each store listing's parts against Google Play's limits (app name 30 characters, short description 80, full
description 4000, release notes 500), so a draft can be checked before it is pasted into Play Console.

Usage: python3 tools/store/check_listing.py   (from hurling-game/; exits 1 if any part is too long)
"""
import pathlib
import sys

LIMITS = {"App name": 30, "Short description": 80, "Full description": 4000, "Release notes": 500}


def parts(text):
    out, name, buf = {}, None, []
    for line in text.splitlines():
        if line.startswith("== ") and line.endswith(" =="):
            if name:
                out[name] = "\n".join(buf).strip()
            name, buf = line[3:-3], []
        elif name and not line.startswith("#"):
            buf.append(line)
    if name:
        out[name] = "\n".join(buf).strip()
    return out


def main():
    bad = 0
    for f in sorted(pathlib.Path("store/listing").glob("*.txt")):
        for name, body in parts(f.read_text()).items():
            limit = next((v for k, v in LIMITS.items() if name.startswith(k)), None)
            if limit is None:
                continue
            ok = len(body) <= limit
            bad += not ok
            print(f"{'ok ' if ok else 'TOO LONG'} {f.name}: {name}: {len(body)}/{limit}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()

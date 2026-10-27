#!/usr/bin/env python3
"""Checks the store listing's text against Play's limits: app name 30 characters, short description 80, full
description 4,000, release notes 500. Usage: python3 tools/store/check_listing.py"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
LIMITS = {"App name": 30, "Short description": 80, "Full description": 4000}

bad = 0
for f in sorted((ROOT / "store" / "listing").glob("*.txt")):
    parts = re.split(r"^== (.*?) ==\s*$", f.read_text(encoding="utf-8"), flags=re.M)
    for name, text in zip(parts[1::2], parts[2::2]):
        limit = LIMITS.get(name, 500 if name.startswith("Release notes") else None)
        n = len(text.strip())
        if limit and n > limit:
            print(f"{f.name}: {name} is {n} characters, over {limit}")
            bad += 1
print(f"check_listing: {bad} over Play's limits")
sys.exit(1 if bad else 0)

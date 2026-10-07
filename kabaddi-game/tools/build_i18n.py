#!/usr/bin/env python3
"""Build i18n/strings.csv (Godot's translation import format) from i18n/src/*.json.

en.json is the source of truth. Any key missing from another language falls back to English,
and the script lists what is missing so translators know what to fill in.

Usage: python3 tools/build_i18n.py
"""
import csv
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "i18n" / "src"
OUT = ROOT / "i18n" / "strings.csv"
LANGS = ["en", "hi", "mr", "ta", "te", "kn", "bn", "pa"]


def main() -> int:
    data = {}
    for lang in LANGS:
        path = SRC / f"{lang}.json"
        data[lang] = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    keys = list(data["en"].keys())
    missing = {lang: [k for k in keys if k not in data[lang]] for lang in LANGS[1:]}
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["keys"] + LANGS)
        for k in keys:
            w.writerow([k] + [data[lang].get(k, data["en"][k]) for lang in LANGS])
    print(f"wrote {OUT.relative_to(ROOT)}: {len(keys)} keys x {len(LANGS)} languages")
    for lang, ks in missing.items():
        if ks:
            print(f"  {lang}: {len(ks)} missing, using English: {', '.join(ks[:8])}{' ...' if len(ks) > 8 else ''}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

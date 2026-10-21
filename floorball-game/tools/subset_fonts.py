#!/usr/bin/env python3
"""Make the fonts small enough to ship (Kabaddi Raid went from 5.3 MB of fonts to 2.2 MB this way).

- Noto Sans, the body font: Latin, Latin Extended A and B (Czech, Slovak, Polish, Latvian, Estonian, the Nordic
  letters), punctuation and arrows; the width axis pinned to normal, the weight axis kept.
- Caveat, the marker hand of the whiteboard titles: the same Latin ranges, weight axis kept.
- Barlow Condensed SemiBold and Bold, the scoreboard and numbers: the same Latin ranges.
- Noto Sans Thai: kept whole (it is small).
- Noto Sans JP: cut down to the characters the Japanese text uses (i18n/src/ja.json) plus Latin, digits and
  punctuation. The full font is 9 MB; the cut one a few hundred KB. Run this again after changing ja.json.

The full fonts are fetched from github.com/google/fonts once into ~/.cache/fbfonts.

Usage: python3 tools/subset_fonts.py   (needs fonttools: pip install fonttools)
"""
import json
import pathlib
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CACHE = pathlib.Path.home() / ".cache" / "fbfonts"
RAW = "https://raw.githubusercontent.com/google/fonts/main/ofl/"
LATIN = "U+0000-024F,U+0300-036F,U+1E00-1EFF,U+2000-206F,U+20A0-20CF,U+2190-21FF,U+2212,U+2423,U+25CF,U+00D7"
BASE = "".join(chr(c) for c in range(0x20, 0x7F)) + "·–—…“”‘’「」『』、。，．！？：；（）《》〈〉・ー〜％＋－×÷°"


def fetch(path: str) -> pathlib.Path:
    local = CACHE / path.split("/")[-1].replace("%5B", "[").replace("%5D", "]")
    if not local.exists():
        print("fetching", RAW + path)
        urllib.request.urlretrieve(RAW + path, local)
    return local


def subset(src: pathlib.Path, out_name: str, *args: str) -> None:
    out = ROOT / "fonts" / out_name
    subprocess.run([sys.executable, "-m", "fontTools.subset", str(src), *args, "--layout-features=*",
                    "--output-file=" + str(out)], check=True)
    print(f"{out.relative_to(ROOT)}: {out.stat().st_size // 1024} KB")


def main() -> int:
    CACHE.mkdir(parents=True, exist_ok=True)
    noto = fetch("notosans/NotoSans%5Bwdth,wght%5D.ttf")
    pinned = CACHE / "NotoSans-wght.ttf"
    subprocess.run([sys.executable, "-m", "fontTools.varLib.instancer", str(noto), "wdth=100", "-o", str(pinned)], check=True)
    subset(pinned, "NotoSans.ttf", "--unicodes=" + LATIN)
    subset(fetch("caveat/Caveat%5Bwght%5D.ttf"), "Caveat.ttf", "--unicodes=" + LATIN)
    subset(fetch("barlowcondensed/BarlowCondensed-SemiBold.ttf"), "BarlowCondensed-SemiBold.ttf", "--unicodes=" + LATIN)
    subset(fetch("barlowcondensed/BarlowCondensed-Bold.ttf"), "BarlowCondensed-Bold.ttf", "--unicodes=" + LATIN)
    thai = fetch("notosansthai/NotoSansThai%5Bwdth,wght%5D.ttf")
    thai_pinned = CACHE / "NotoSansThai-wght.ttf"
    subprocess.run([sys.executable, "-m", "fontTools.varLib.instancer", str(thai), "wdth=100", "-o", str(thai_pinned)], check=True)
    subset(thai_pinned, "NotoSansThai.ttf", "--unicodes=U+0020-007E,U+0E00-0E7F,U+2000-206F")
    ja = fetch("notosansjp/NotoSansJP%5Bwght%5D.ttf")
    src = ROOT / "i18n" / "src" / "ja.json"
    text = json.loads(src.read_text(encoding="utf-8")) if src.exists() else {}
    chars = set(BASE) | set("".join(text.values()))
    subset(ja, "NotoSansJP.ttf", "--text=" + "".join(sorted(chars)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

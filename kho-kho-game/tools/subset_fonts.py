#!/usr/bin/env python3
"""Make the fonts small enough to ship (Kabaddi Raid's fonts went from 5.3 MB to 2.2 MB this way).

Every font is a Noto Sans variable font from github.com/google/fonts: the width axis pinned to normal, the weight axis
cut to 400-700 (the weights the game draws with), and the letters cut to the font's own script, the Indian danda and
the Latin digits and punctuation that the text mixes in. Fetched once into ~/.cache/khofonts.

Usage: python3 tools/subset_fonts.py   (needs fonttools: pip install fonttools)
"""
import pathlib
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CACHE = pathlib.Path.home() / ".cache" / "khofonts"
COMMON = "U+0020-007E,U+00A0,U+00B7,U+00D7,U+2010-2027,U+2030-203A,U+20B9,U+200B-200D,U+25CF,U+0964-0965"
# file name, google/fonts folder, the script's Unicode ranges
FONTS = [
    ("NotoSans", "notosans", "U+0000-024F,U+0300-036F,U+1E00-1EFF,U+2000-206F,U+20A0-20CF,U+2190-21FF,U+2212,U+2423,U+25CF"),
    ("NotoSansDevanagari", "notosansdevanagari", "U+0900-097F,U+A8E0-A8FF,U+1CD0-1CFF"),   # Hindi, Marathi, Nepali
    ("NotoSansBengali", "notosansbengali", "U+0980-09FF"),                                  # Bengali, Assamese
    ("NotoSansGurmukhi", "notosansgurmukhi", "U+0A00-0A7F"),                                # Punjabi
    ("NotoSansGujarati", "notosansgujarati", "U+0A80-0AFF"),
    ("NotoSansOriya", "notosansoriya", "U+0B00-0B7F"),                                      # Odia
    ("NotoSansTamil", "notosanstamil", "U+0B80-0BFF"),
    ("NotoSansTelugu", "notosanstelugu", "U+0C00-0C7F"),
    ("NotoSansKannada", "notosanskannada", "U+0C80-0CFF"),
    ("NotoSansMalayalam", "notosansmalayalam", "U+0D00-0D7F"),
    ("NotoSansSinhala", "notosanssinhala", "U+0D80-0DFF"),
    ("Baloo2", "baloo2", "U+0000-017F,U+0900-097F,U+2000-206F,U+20B9"),                     # the display face: Latin and Devanagari
]


def main() -> int:
    CACHE.mkdir(parents=True, exist_ok=True)
    total = 0
    for name, folder, ranges in FONTS:
        src = CACHE / f"{name}.ttf"
        axes = "wght" if name == "Baloo2" else "wdth,wght"
        if not src.exists():
            url = f"https://raw.githubusercontent.com/google/fonts/main/ofl/{folder}/{name}%5B{axes}%5D.ttf"
            print("fetching", url)
            urllib.request.urlretrieve(url, src)
        pinned = CACHE / f"{name}-pinned.ttf"
        subprocess.run([sys.executable, "-m", "fontTools.varLib.instancer", str(src), *(["wdth=100"] if "wdth" in axes else []), ("wght=700" if name == "Baloo2" else "wght=400:700"),
                        "-q", "-o", str(pinned)], check=True)
        out = ROOT / "fonts" / f"{name}.ttf"
        subprocess.run([sys.executable, "-m", "fontTools.subset", str(pinned), f"--unicodes={ranges},{COMMON}",
                        "--layout-features=*", "--output-file=" + str(out)], check=True)
        size = out.stat().st_size
        total += size
        print(f"{out.relative_to(ROOT)}: {size // 1024} KB")
    print(f"total {total // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())

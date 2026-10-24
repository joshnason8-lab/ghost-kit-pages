#!/usr/bin/env python3
"""Make the fonts small enough to ship: Noto Sans (the text) and Oswald (the headings), cut to Latin, Latin
Extended-A (every Irish letter with its fada, and the dotted consonants of the old script), general punctuation,
the euro and the arrows, the weight axis kept. Uncial Antiqua (the title) has a Reserved Font Name, so it ships as it
is. The full fonts are fetched from github.com/google/fonts once into ~/.cache/ash-fonts.

Usage: python3 tools/subset_fonts.py   (needs fonttools: pip install fonttools)
"""
import pathlib
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CACHE = pathlib.Path.home() / ".cache" / "ash-fonts"
UNICODES = ("U+0000-017F,U+0218-021B,U+02C6-02DC,U+0300-036F,U+1E02-1E03,U+1E0A-1E0B,U+1E1E-1E1F,U+1E40-1E41,"
            "U+1E56-1E57,U+1E60-1E61,U+1E6A-1E6B,U+2000-206F,U+20AC,U+2190-21FF,U+2212,U+2423,U+25CF")
FONTS = {
    "NotoSans.ttf": ("https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/NotoSans%5Bwdth,wght%5D.ttf", True),
    "Oswald.ttf": ("https://raw.githubusercontent.com/google/fonts/main/ofl/oswald/Oswald%5Bwght%5D.ttf", False),
}


def main() -> int:
    CACHE.mkdir(parents=True, exist_ok=True)
    for name, (url, pin_width) in FONTS.items():
        src = CACHE / name
        if not src.exists():
            print("fetching", url)
            urllib.request.urlretrieve(url, src)
        if pin_width:
            pinned = CACHE / ("pinned-" + name)
            subprocess.run([sys.executable, "-m", "fontTools.varLib.instancer", str(src), "wdth=100", "-o", str(pinned)], check=True)
            src = pinned
        out = ROOT / "fonts" / name
        subprocess.run([sys.executable, "-m", "fontTools.subset", str(src), "--unicodes=" + UNICODES,
                        "--layout-features=*", "--output-file=" + str(out)], check=True)
        print(f"{out.relative_to(ROOT)}: {out.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())

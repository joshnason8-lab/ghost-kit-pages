#!/usr/bin/env python3
"""Make the fonts small enough to ship: Noto Sans (the text) and Oswald (the headings and the title), cut to Latin and
Latin Extended-A (every accented letter of Spanish, Portuguese, French, German and Italian: á é í ó ú ñ ü ç ã õ â ê ô à
è ì ò ù ë ï œ ß, and the Maya apostrophe), general punctuation, the euro and the arrows, the weight axis kept. The full
fonts are fetched from github.com/google/fonts once into ~/.cache/pokta-fonts.

Usage: python3 tools/subset_fonts.py   (needs fonttools: pip install fonttools)
"""
import pathlib
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CACHE = pathlib.Path.home() / ".cache" / "pokta-fonts"
UNICODES = ("U+0000-017F,U+0218-021B,U+02BC,U+02C6-02DC,U+0300-036F,U+2000-206F,U+20AC,U+2190-21FF,U+2212,U+2423,U+25CF")
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

#!/usr/bin/env python3
"""Make the fonts small enough to ship. Noto Sans (the Latin font): the Latin, Latin Extended and Vietnamese letters,
the width axis pinned to normal, the weight axis kept. And the Chinese, Japanese and Korean fonts: each Noto Sans CJK font cut down to the
characters its language's text uses (i18n/src/<lang>.json), plus Latin letters, digits and punctuation, keeping the
weight axis. The full fonts are 10-18 MB each; the cut ones a few hundred KB. Run it after changing a translation.

The full fonts are fetched from github.com/google/fonts once into ~/.cache/takraw-fonts.

Usage: python3 tools/subset_fonts.py   (needs fonttools: pip install fonttools)
"""
import json
import pathlib
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CACHE = pathlib.Path.home() / ".cache" / "takraw-fonts"
FONTS = {"ja": ("notosansjp", "NotoSansJP"), "ko": ("notosanskr", "NotoSansKR"), "zh": ("notosanssc", "NotoSansSC")}
BASE = "".join(chr(c) for c in range(0x20, 0x7F)) + "·–—…“”‘’「」『』、。，．！？：；（）《》〈〉・ー〜％＋－×÷°₩¥"


def latin() -> None:
    src = CACHE / "NotoSans.ttf"
    if not src.exists():
        url = "https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/NotoSans%5Bwdth,wght%5D.ttf"
        print("fetching", url)
        urllib.request.urlretrieve(url, src)
    pinned = CACHE / "NotoSans-wght.ttf"
    subprocess.run([sys.executable, "-m", "fontTools.varLib.instancer", str(src), "wdth=100", "-o", str(pinned)], check=True)
    out = ROOT / "fonts" / "NotoSans.ttf"
    subprocess.run([sys.executable, "-m", "fontTools.subset", str(pinned),
                    "--unicodes=U+0000-024F,U+0300-036F,U+1E00-1EFF,U+2000-206F,U+20A0-20CF,U+2190-21FF,U+2212,U+2423,U+25CF",
                    "--layout-features=*", "--output-file=" + str(out)], check=True)
    print(f"{out.relative_to(ROOT)}: {out.stat().st_size // 1024} KB")


def main() -> int:
    CACHE.mkdir(parents=True, exist_ok=True)
    latin()
    for lang, (folder, name) in FONTS.items():
        src = CACHE / f"{name}.ttf"
        if not src.exists():
            url = f"https://raw.githubusercontent.com/google/fonts/main/ofl/{folder}/{name}%5Bwght%5D.ttf"
            print("fetching", url)
            urllib.request.urlretrieve(url, src)
        text = json.loads((ROOT / "i18n" / "src" / f"{lang}.json").read_text(encoding="utf-8"))
        chars = set(BASE) | set("".join(text.values()))
        out = ROOT / "fonts" / f"{name}.ttf"
        subprocess.run([sys.executable, "-m", "fontTools.subset", str(src), "--text=" + "".join(sorted(chars)),
                        "--layout-features=*", "--output-file=" + str(out)], check=True)
        print(f"{out.relative_to(ROOT)}: {len(chars)} characters, {out.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())

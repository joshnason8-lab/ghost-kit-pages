#!/usr/bin/env python3
"""Make the fonts small enough to ship.

- Noto Sans (Latin): Latin, Latin Extended (Welsh ŵ ŷ, Māori, Samoan and Tongan macrons), the spacing modifier
  letters (the Polynesian ʻokina, U+02BB), general punctuation; width pinned to normal, weight axis kept.
- Noto Sans Sinhala and Noto Sans Tamil: pinned to normal width, cut to their own script plus punctuation.
- Noto Sans SC (Chinese): cut to the characters zh.json uses, plus Latin, digits and punctuation.

The full fonts are fetched from github.com/google/fonts once into ~/.cache/netball-fonts. Run after changing a
translation.

Usage: python3 tools/subset_fonts.py   (needs fonttools: pip install fonttools)
"""
import json
import pathlib
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CACHE = pathlib.Path.home() / ".cache" / "netball-fonts"
GF = "https://raw.githubusercontent.com/google/fonts/main/ofl"
BASE = "".join(chr(c) for c in range(0x20, 0x7F)) + "·–—…“”‘’、。，．！？：；（）《》％＋－×÷°"


def fetch(folder: str, name: str, axes: str) -> pathlib.Path:
    src = CACHE / f"{name}.ttf"
    if not src.exists():
        url = f"{GF}/{folder}/{name}%5B{axes}%5D.ttf"
        print("fetching", url)
        urllib.request.urlretrieve(url, src)
    return src


def run(*args: str) -> None:
    subprocess.run([sys.executable, "-m", *args], check=True)


def pinned(src: pathlib.Path) -> pathlib.Path:
    out = CACHE / (src.stem + "-wght.ttf")
    run("fontTools.varLib.instancer", str(src), "wdth=100", "-o", str(out))
    return out


def report(out: pathlib.Path) -> None:
    print(f"{out.relative_to(ROOT)}: {out.stat().st_size // 1024} KB")


def main() -> int:
    CACHE.mkdir(parents=True, exist_ok=True)
    latin = pinned(fetch("notosans", "NotoSans", "wdth,wght"))
    out = ROOT / "fonts" / "NotoSans.ttf"
    run("fontTools.subset", str(latin),
        "--unicodes=U+0000-024F,U+02B0-02FF,U+0300-036F,U+1E00-1EFF,U+2000-206F,U+20A0-20CF,U+2190-21FF,U+2212,U+25CF",
        "--layout-features=*", "--output-file=" + str(out))
    report(out)
    for folder, name, block in [("notosanssinhala", "NotoSansSinhala", "U+0D80-0DFF,U+111E0-111FF"),
                                ("notosanstamil", "NotoSansTamil", "U+0B80-0BFF,U+11FC0-11FFF")]:
        src = pinned(fetch(folder, name, "wdth,wght"))
        out = ROOT / "fonts" / f"{name}.ttf"
        run("fontTools.subset", str(src), f"--unicodes={block},U+0020-0040,U+200C-200D,U+25CC",
            "--layout-features=*", "--output-file=" + str(out))
        report(out)
    src = fetch("notosanssc", "NotoSansSC", "wght")
    text = json.loads((ROOT / "i18n" / "src" / "zh.json").read_text(encoding="utf-8"))
    chars = set(BASE) | set("".join(text.values()))
    out = ROOT / "fonts" / "NotoSansSC.ttf"
    run("fontTools.subset", str(src), "--text=" + "".join(sorted(chars)), "--layout-features=*", "--output-file=" + str(out))
    report(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""The game's icon, from the owner's artwork (store/graphics/icon-source.jpg: a chaser in orange reaching for a
defender in blue past the pole). Writes assets/icon/ (192, 512, and the adaptive 432 background with an empty
foreground: the artwork is full-bleed, and the launcher's mask keeps its middle two-thirds, where both faces are)
and store/graphics/icon-512.png (Play's icon) and icon-1024.png (the media kit's).

Usage: python3 tools/store/make_icons.py   (needs Pillow)
"""
import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]


def main() -> None:
    src = Image.open(ROOT / "store/graphics/icon-source.jpg").convert("RGBA")
    out = ROOT / "assets/icon"
    for n in (192, 512):
        src.resize((n, n), Image.LANCZOS).save(out / f"icon_{n}.png")
    src.resize((432, 432), Image.LANCZOS).save(out / "icon_bg_432.png")
    Image.new("RGBA", (432, 432), (0, 0, 0, 0)).save(out / "icon_fg_432.png")
    src.convert("RGB").resize((512, 512), Image.LANCZOS).save(ROOT / "store/graphics/icon-512.png")
    src.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(ROOT / "store/graphics/icon-1024.png")
    print("icons written")


if __name__ == "__main__":
    main()

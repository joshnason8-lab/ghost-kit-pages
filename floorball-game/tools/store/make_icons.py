#!/usr/bin/env python3
"""The app icon, from the owner's artwork (store/graphics/icon_art.webp: a floorball on a stick's blade, in a streak of
fire, under the lights of a hall). Writes assets/icon/icon_512.png, icon_192.png, the adaptive icon's layers
(icon_bg_432.png: the artwork, which the launcher's mask crops; icon_fg_432.png: empty) and store/graphics/icon-512.png.

Usage: python3 tools/store/make_icons.py   (needs Pillow)
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    art = Image.open(ROOT / "store" / "graphics" / "icon_art.webp").convert("RGB")
    side = min(art.size)
    art = art.crop(((art.width - side) // 2, (art.height - side) // 2, (art.width + side) // 2, (art.height + side) // 2))
    out = ROOT / "assets" / "icon"
    out.mkdir(parents=True, exist_ok=True)
    art.resize((512, 512), Image.LANCZOS).save(out / "icon_512.png")
    art.resize((192, 192), Image.LANCZOS).save(out / "icon_192.png")
    # Play wants the hi-res icon as a 32-bit PNG (RGBA); the artwork fills it, so it is opaque.
    art.resize((512, 512), Image.LANCZOS).convert("RGBA").save(ROOT / "store" / "graphics" / "icon-512.png")
    # Adaptive icon: the whole artwork as the background layer (the launcher shows its middle, the ball and blade),
    # nothing in front of it.
    art.resize((432, 432), Image.LANCZOS).save(out / "icon_bg_432.png")
    Image.new("RGBA", (432, 432), (0, 0, 0, 0)).save(out / "icon_fg_432.png")


if __name__ == "__main__":
    main()

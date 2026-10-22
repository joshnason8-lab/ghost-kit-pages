#!/usr/bin/env python3
"""Make the game's icons from the owner's artwork (store/graphics/icon-source.jpg, kept out of the game's files: a netball sweeping through the ring under
the arena's floodlights). Writes assets/icon/icon_512.png (Play's store icon and the launcher), icon_192.png, and
the adaptive icon's two layers: the artwork as the background (icon_bg_432.png) and an empty foreground
(icon_fg_432.png), so the phone's mask shows its middle, the ball and the ring.

Usage: python3 tools/store/make_icons.py   (needs Pillow)
"""
import pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent


def main() -> None:
    out = ROOT / "assets" / "icon"
    src = Image.open(ROOT / "store" / "graphics" / "icon-source.jpg").convert("RGB")
    side = min(src.size)
    src = src.crop(((src.width - side) // 2, (src.height - side) // 2, (src.width + side) // 2, (src.height + side) // 2))
    src.resize((512, 512), Image.LANCZOS).convert("RGBA").save(out / "icon_512.png")
    src.resize((192, 192), Image.LANCZOS).convert("RGBA").save(out / "icon_192.png")
    src.resize((432, 432), Image.LANCZOS).convert("RGBA").save(out / "icon_bg_432.png")
    Image.new("RGBA", (432, 432), (0, 0, 0, 0)).save(out / "icon_fg_432.png")
    print("icons written to", out)


if __name__ == "__main__":
    main()

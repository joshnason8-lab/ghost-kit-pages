#!/usr/bin/env python3
"""The player model's texture for phones: its 4096 atlas down to 1024 (assets/player/hero_albedo.jpg), and a mask of
where its kit is (assets/player/hero_mask.png, 512: red the jersey's green, green the gold trim, blue the white
shorts, alpha the skin), so the game can draw every county's colours on the one model (hero_body.gd's shader).
For Medium and High, sharper ones beside them: hero_albedo_hd.jpg at 2048 and hero_mask_hd.png at 1024.
The mask's mean colours go in hero.json ("ref") for the shader to keep the texture's folds and shading.

Usage: python3 make_textures.py <player_texture_0.png> <hurling-game/assets/player>   (needs Pillow and numpy)
"""
import json
import pathlib
import sys

import numpy as np
from PIL import Image, ImageFilter


def main():
    src, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    img = Image.open(src).convert("RGB")
    small = img.resize((1024, 1024), Image.LANCZOS)
    small.save(out / "hero_albedo.jpg", quality=88, optimize=True, progressive=True)
    # Classify at 2048, then shrink: the mask's edges come out soft.
    mid = img.resize((2048, 2048), Image.LANCZOS)
    hsv = np.asarray(mid.convert("HSV")).astype(np.float32) / 255.0
    h, s, v = hsv[..., 0] * 360.0, hsv[..., 1], hsv[..., 2]
    jersey = (h > 75) & (h < 175) & (s > 0.25) & (v > 0.07)
    trim = (h > 28) & (h < 70) & (s > 0.35) & (v > 0.35)
    shorts = (s < 0.14) & (v > 0.62)
    skin = (h > 5) & (h < 32) & (s > 0.16) & (s < 0.62) & (v > 0.4) & ~trim
    rgb = np.asarray(mid).astype(np.float32) / 255.0
    ref = {}
    for name, m in [("jersey", jersey), ("trim", trim), ("shorts", shorts), ("skin", skin)]:
        ref[name] = [round(float(rgb[..., i][m].mean()), 4) for i in range(3)]
        print(name, f"{m.mean() * 100:.1f}% of the atlas", ref[name])
    # Each channel shrunk on its own (an RGBA image would be shrunk with its alpha premultiplied).
    chans = [Image.fromarray(m.astype(np.uint8) * 255).resize((512, 512), Image.BOX).filter(ImageFilter.GaussianBlur(0.6))
             for m in [jersey, trim, shorts, skin]]
    mimg = Image.merge("RGBA", chans)
    mimg.save(out / "hero_mask.png", optimize=True)
    mid.save(out / "hero_albedo_hd.jpg", quality=90, optimize=True, progressive=True)
    chans = [Image.fromarray(m.astype(np.uint8) * 255).resize((1024, 1024), Image.BOX).filter(ImageFilter.GaussianBlur(0.6))
             for m in [jersey, trim, shorts, skin]]
    Image.merge("RGBA", chans).save(out / "hero_mask_hd.png", optimize=True)
    js = out / "hero.json"
    data = json.loads(js.read_text()) if js.exists() else {}
    data["ref"] = ref
    js.write_text(json.dumps(data, separators=(",", ":")))
    for p in ["hero_albedo.jpg", "hero_mask.png", "hero_albedo_hd.jpg", "hero_mask_hd.png"]:
        print("wrote", p, (out / p).stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()

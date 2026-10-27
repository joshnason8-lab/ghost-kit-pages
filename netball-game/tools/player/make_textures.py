#!/usr/bin/env python3
"""The player model's texture for phones: its 4096 atlas down to 1024 (assets/player/hero_albedo.jpg), and a mask of
where its kit is (assets/player/hero_mask.png, 512: red the dress's navy, and the shorts under it; green the light blue
side panels and trim, with the teal of their folds; blue the hair; alpha the skin), so the game can draw every team's
colours on the one model (hero_body.gd's shader). The white of the socks, the shoes and the little chest patches is
left as it is. The mask's mean colours go in hero.json ("ref") for the shader to keep the texture's folds and shading.
Medium and High load sharper copies: hero_albedo_2k.jpg (2048) and hero_mask_1k.png (1024, classified at 4096); Low
keeps the 1024 and 512 ones (game/hero_body.gd).

Usage: python3 make_textures.py <player_texture_0.png> <netball-game/assets/player>   (needs Pillow and numpy)
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
    blue = (h > 140) & (h < 250) & (s > 0.18)
    trim = blue & (v > 0.55) & (s < 0.75)
    dress = blue & ~trim
    warm = (h < 45) | (h > 340)
    hair = warm & (v < 0.42) & (s > 0.3)
    skin = warm & (s > 0.15) & (s < 0.7) & (v >= 0.42)
    rgb = np.asarray(mid).astype(np.float32) / 255.0
    ref = {}
    for name, m in [("dress", dress), ("trim", trim), ("hair", hair), ("skin", skin)]:
        ref[name] = [round(float(rgb[..., i][m].mean()), 4) for i in range(3)]
        print(name, f"{m.mean() * 100:.1f}% of the atlas", ref[name])
    # Each channel shrunk on its own (an RGBA image would be shrunk with its alpha premultiplied).
    chans = [Image.fromarray(m.astype(np.uint8) * 255).resize((512, 512), Image.BOX).filter(ImageFilter.GaussianBlur(0.6))
             for m in [dress, trim, hair, skin]]
    mimg = Image.merge("RGBA", chans)
    mimg.save(out / "hero_mask.png", optimize=True)
    # The sharper pair for Medium and High (the same classes, found at full size; ref stays the 2048 one above).
    img.resize((2048, 2048), Image.LANCZOS).save(out / "hero_albedo_2k.jpg", quality=90, optimize=True, progressive=True)
    hsv = np.asarray(img.convert("HSV")).astype(np.float32) / 255.0
    h, s, v = hsv[..., 0] * 360.0, hsv[..., 1], hsv[..., 2]
    blue = (h > 140) & (h < 250) & (s > 0.18)
    trim = blue & (v > 0.55) & (s < 0.75)
    dress = blue & ~trim
    warm = (h < 45) | (h > 340)
    hair = warm & (v < 0.42) & (s > 0.3)
    skin = warm & (s > 0.15) & (s < 0.7) & (v >= 0.42)
    chans = [Image.fromarray(m.astype(np.uint8) * 255).resize((1024, 1024), Image.BOX).filter(ImageFilter.GaussianBlur(0.8))
             for m in [dress, trim, hair, skin]]
    Image.merge("RGBA", chans).save(out / "hero_mask_1k.png", optimize=True)
    js = out / "hero.json"
    data = json.loads(js.read_text()) if js.exists() else {}
    data["ref"] = ref
    js.write_text(json.dumps(data, separators=(",", ":")))
    for p in ["hero_albedo.jpg", "hero_mask.png", "hero_albedo_2k.jpg", "hero_mask_1k.png"]:
        print("wrote", p, (out / p).stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()

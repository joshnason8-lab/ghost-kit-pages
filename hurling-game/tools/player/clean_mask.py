#!/usr/bin/env python3
"""Cleans the kit mask (make_textures.py) so every county's colours cover the whole kit: the mask is found from the
texture's colours, and the kit's folds, shadows and the edges of its UV islands fall outside them, so the model's
own texture (its green, white and grey) showed through the county's colours as streaks and smudges.

From the 2048 mask (ultra/player/hero_mask_2k.png): each pixel's part (jersey, trim, shorts, skin or none). Small
patches of one part inside another become the part round them (a pale fold on a jersey had been read as the white
shorts and painted the shorts' colour; small gold flecks as trim); thin runs and small holes of none beside the kit
become the nearest kit part (big none areas, the helmet, the guard and the boots, stay as they are; nothing becomes
skin); then the kit is grown 2 px into what is left, so a texture sample at an island's edge does not pick up the
gutter. Written back at 2048, 1024 (hero_mask_hd.png) and 512
(hero_mask.png), shrunk and softened as make_textures.py does.

Usage: python3 tools/player/clean_mask.py      (from hurling-game/; needs Pillow, numpy, scipy)
"""
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

SRC = "ultra/player/hero_mask_2k.png"
NEAR = 8          # px at 2048: how far a hole may be from the kit it joins
SMALL = 1500      # px at 2048: a none area this small, inside or beside the kit, is a hole
# px at 2048: a patch of a part this small, with another kit part all round it, is that part (the trim's numbers and
# bands are larger than its limit).
PATCH = {1: 4000, 2: 250, 3: 4000, 4: 1500}


def main():
    m = np.asarray(Image.open(SRC).convert("RGBA")).astype(np.float32) / 255.0
    part = np.where(m.max(axis=2) > 0.5, m.argmax(axis=2) + 1, 0)      # 1 jersey, 2 trim, 3 shorts, 4 skin, 0 none
    ring = np.ones((5, 5), bool)
    moved = 0
    for k, limit in PATCH.items():
        lab, n = ndimage.label(part == k)
        if n == 0:
            continue
        sizes = ndimage.sum(part == k, lab, index=np.arange(1, n + 1))
        objs = ndimage.find_objects(lab)
        for i in np.nonzero(sizes < limit)[0]:
            sl = tuple(slice(max(0, s.start - 3), s.stop + 3) for s in objs[i])
            blob = lab[sl] == i + 1
            edge = ndimage.binary_dilation(blob, structure=ring) & ~blob
            around = part[sl][edge]
            kits = around[(around >= 1) & (around <= 3) & (around != k)]
            # Taken over only when nearly all round it is one other kit part.
            if kits.size and kits.size >= 0.9 * around.size:
                vals, counts = np.unique(kits, return_counts=True)
                part[sl][blob] = vals[counts.argmax()]
                moved += int(blob.sum())
    print(f"patches moved to the part round them: {moved / part.size * 100:.2f}% of the atlas")
    none = part == 0
    disk = np.hypot(*np.mgrid[-4:5, -4:5]) <= 4
    thin = none & ~ndimage.binary_opening(none, structure=disk)
    lab, n = ndimage.label(none)
    sizes = ndimage.sum(none, lab, index=np.arange(1, n + 1))
    small = none & np.isin(lab, np.nonzero(sizes < SMALL)[0] + 1)
    kit = (part >= 1) & (part <= 3)
    dist, (iy, ix) = ndimage.distance_transform_edt(~kit, return_indices=True)
    nearest = part[iy, ix]
    fill = (thin | small) & (dist <= NEAR)
    out = part.copy()
    out[fill] = nearest[fill]
    # Grown 2 px into what is still none.
    grow = (out == 0) & (dist <= 2)
    out[grow] = nearest[grow]
    print(f"filled {fill.mean() * 100:.2f}% of the atlas, grown {grow.mean() * 100:.2f}%")
    chans = [(out == k).astype(np.uint8) * 255 for k in (1, 2, 3, 4)]
    Image.merge("RGBA", [Image.fromarray(c).filter(ImageFilter.GaussianBlur(0.6)) for c in chans]).save(SRC, optimize=True)
    for size, name in [(1024, "assets/player/hero_mask_hd.png"), (512, "assets/player/hero_mask.png")]:
        Image.merge("RGBA", [Image.fromarray(c).resize((size, size), Image.BOX).filter(ImageFilter.GaussianBlur(0.6))
                             for c in chans]).save(name, optimize=True)
        print("wrote", name)


if __name__ == "__main__":
    main()

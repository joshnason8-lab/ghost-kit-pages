#!/usr/bin/env python3
"""Makes the court mat's texture: a seamless tile, a detail albedo (multiplied with the material's colour, so one
texture serves every court colour) and a normal map, generated from noise, so there is nothing to license. (It made
the concrete, stands, grass, mud and sand too until 0.9.0, when photographed surfaces took their place:
assets/scenery/surfaces.)

    python3 tools/ground_art/make_textures.py            # writes assets/grounds/textures/*.png

Each texture covers a known patch of ground (PERIOD, metres), so the arena sets its UV scale from the size of what
it covers (Arena._surface_mat). Noise is made in the frequency domain, which makes it tile without seams.
"""
import os
import sys

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "grounds", "textures")
RNG = np.random.default_rng(7)

# Metres of ground one texture covers (Arena reads the same numbers: keep them in step).
PERIOD = {"mat": 2.0}


def noise(n, beta=2.0, lo=1.0, hi=None):
    """Seamless fractal noise, n x n, about zero mean and unit spread: white noise shaped to a 1/f^beta spectrum
    between frequencies lo and hi (cycles across the tile)."""
    w = RNG.standard_normal((n, n))
    f = np.fft.fftfreq(n) * n
    fx, fy = np.meshgrid(f, f)
    r = np.sqrt(fx * fx + fy * fy)
    amp = np.where(r > 0, 1.0 / np.maximum(r, 1e-6) ** (beta / 2.0), 0.0)
    amp[r < lo] = 0.0
    if hi is not None:
        amp *= np.exp(-((r / hi) ** 2))
    out = np.real(np.fft.ifft2(np.fft.fft2(w) * amp))
    return (out - out.mean()) / (out.std() + 1e-9)


def normal_map(height, strength):
    """Tangent-space normal map (OpenGL convention, +Y up, as Godot reads it) from a height field in pixels."""
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5 * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5 * strength
    nx, ny, nz = -dx, dy, np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack([nx / length, ny / length, nz / length], axis=-1) * 0.5 + 0.5
    return (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)


def save_gray(a, name):
    """a: 0..1 linear-ish detail value, saved as an sRGB grey image."""
    img = (np.clip(a, 0, 1) ** (1 / 2.2) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(img, "L").convert("RGB").save(os.path.join(OUT, name), optimize=True)


def save_normal(rgb, name):
    Image.fromarray(rgb, "RGB").save(os.path.join(OUT, name), optimize=True)


def mat(n=512):
    """A foam kabaddi mat: 1 m tiles (four to the texture) with fine seams, each tile a touch lighter or darker,
    a fine grain, and faint scuffs and shoe marks where play goes."""
    tile = n // 2
    y, x = np.mgrid[0:n, 0:n]
    shade = np.zeros((n, n))
    for ty in range(2):
        for tx in range(2):
            shade[ty * tile:(ty + 1) * tile, tx * tile:(tx + 1) * tile] = RNG.uniform(-0.035, 0.035)
    grain = noise(n, beta=0.6, lo=40) * 0.018
    mottle = noise(n, beta=2.6, lo=1) * 0.03
    scuff = np.clip(noise(n, beta=1.8, lo=3, hi=40), 1.2, None) - 1.2
    # A seam: a 1.5 px groove at each tile edge, wrapping.
    dx = np.minimum(x % tile, tile - (x % tile))
    dy = np.minimum(y % tile, tile - (y % tile))
    seam = np.exp(-(np.minimum(dx, dy) ** 2) / 1.2)
    albedo = 0.9 + shade + grain + mottle - scuff * 0.05 - seam * 0.22
    height = noise(n, beta=0.9, lo=30) * 0.6 - seam * 3.0 + mottle * 4.0
    save_gray(albedo, "mat_albedo.png")
    save_normal(normal_map(height, 0.9), "mat_normal.png")


IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/grounds/textures/{name}"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map={normal}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


def write_imports():
    """Import settings Godot cannot guess for textures only used from code: compressed for the GPU, with mipmaps,
    and the normal maps as normal maps. Godot adds the rest (uid, paths) when it imports them."""
    for f in sorted(os.listdir(OUT)):
        if f.endswith(".png") and not os.path.exists(os.path.join(OUT, f + ".import")):
            with open(os.path.join(OUT, f + ".import"), "w") as out:
                out.write(IMPORT.format(name=f, normal=1 if f.endswith("_normal.png") else 0))


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in (mat,):
        f()
        print("made", f.__name__)
    write_imports()


if __name__ == "__main__":
    sys.exit(main())

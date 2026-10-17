#!/usr/bin/env python3
"""Makes the grounds' surface textures: seamless tiles for the court mat, concrete, the stands, grass, mud and
sand, each a detail albedo (multiplied with the material's colour, so one mat texture serves every court colour) and
a normal map. Everything is generated here from noise, so there is nothing to license.

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
PERIOD = {"mat": 2.0, "concrete": 4.0, "stand": 1.8, "grass": 3.0, "mud": 3.0, "sand": 3.0}


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


def blur(a, px):
    """Seamless gaussian blur of px pixels."""
    n = a.shape[0]
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    g = np.exp(-2.0 * (np.pi * px) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


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


def save_rgb(a, name):
    """a: n x n x 3, 0..1 linear colour, saved as sRGB."""
    img = (np.clip(a, 0, 1) ** (1 / 2.2) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(img, "RGB").save(os.path.join(OUT, name), optimize=True)


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


def concrete(n=512):
    """Polished concrete for an indoor floor: soft clouds, small aggregate flecks, a few hairline cracks."""
    clouds = noise(n, beta=2.4, lo=1) * 0.05
    fleck = np.clip(noise(n, beta=0.2, lo=60), 2.0, None) - 2.0
    crack = np.zeros((n, n))
    for _ in range(4):
        # A wandering hairline: a random walk drawn across part of the tile, wrapping.
        px, py = RNG.uniform(0, n, 2)
        ang = RNG.uniform(0, 2 * np.pi)
        for _ in range(int(RNG.uniform(80, 260))):
            ang += RNG.normal(0, 0.25)
            px, py = (px + np.cos(ang)) % n, (py + np.sin(ang)) % n
            crack[int(py), int(px)] = 1.0
    crack = blur(crack, 0.6)
    crack /= crack.max() + 1e-9
    albedo = 0.82 + clouds - fleck * 0.06 - crack * 0.18
    height = clouds * 6 - crack * 2.0 + noise(n, beta=0.8, lo=50) * 0.25
    save_gray(albedo, "concrete_albedo.png")
    save_normal(normal_map(height, 0.8), "concrete_normal.png")


def stand(n=512):
    """A row of the stands seen from the front and above, 1.8 m of it: a concrete step with moulded plastic seats
    every 0.55 m across... in world space it is laid on each tier's tread (Arena: triplanar on the stand blocks), so
    it is concrete with the seats' pale outlines, dirt in the corners, and streaks running down."""
    y, x = np.mgrid[0:n, 0:n] / n
    base = 0.78 + noise(n, beta=2.2, lo=1) * 0.05
    streak = blur(noise(n, beta=1.0, lo=2) * np.exp(-((x * 8 % 1 - 0.5) ** 2) * 6), 3)
    streak = np.repeat(streak.mean(axis=0, keepdims=True), n, axis=0) * 0.08 + blur(noise(n, beta=1.2, lo=2), 2) * 0.03
    albedo = base - np.abs(streak)
    height = noise(n, beta=1.6, lo=2) * 2 + noise(n, beta=0.6, lo=60) * 0.3
    save_gray(albedo, "stand_albedo.png")
    save_normal(normal_map(height, 0.6), "stand_normal.png")


def grass(n=512):
    """Close-cut grass: blades as fine streaks leaning one way, patches lighter and darker, a little earth."""
    blades = blur(noise(n, beta=0.3, lo=80), 0.6)
    # Lean the blades: stretch the fine noise along one diagonal.
    lean = np.zeros_like(blades)
    for k in range(6):
        lean += np.roll(np.roll(blades, k, axis=0), k // 2, axis=1)
    lean /= 6
    patch = noise(n, beta=2.5, lo=1)
    earth = np.clip(noise(n, beta=2.0, lo=2) - 1.4, 0, None)
    g = np.stack([0.20 + patch * 0.03, 0.34 + patch * 0.05, 0.10 + patch * 0.02], axis=-1)
    g *= (0.85 + lean[..., None] * 0.18)
    dirt = np.array([0.32, 0.24, 0.15])
    g = g * (1 - np.clip(earth, 0, 1)[..., None] * 0.7) + dirt * np.clip(earth, 0, 1)[..., None] * 0.7
    save_rgb(g, "grass_albedo.png")
    save_normal(normal_map(lean * 2.0 + patch * 1.5, 0.9), "grass_normal.png")


def mud(n=512):
    """Packed earth for a village court: clods and cracks, darker damp patches, pale dust."""
    big = noise(n, beta=2.3, lo=1)
    clods = noise(n, beta=1.2, lo=8)
    cells = np.abs(blur(noise(n, beta=1.8, lo=6), 1.0))
    crack = np.exp(-(cells ** 2) / 0.01) * 0.6
    col = np.stack([0.40 + big * 0.04, 0.28 + big * 0.03, 0.17 + big * 0.02], axis=-1)
    col *= (0.92 + clods[..., None] * 0.05 - crack[..., None] * 0.25)
    dust = np.clip(noise(n, beta=2.0, lo=3) - 1.0, 0, 1)[..., None]
    col = col * (1 - dust * 0.25) + np.array([0.55, 0.45, 0.33]) * dust * 0.25
    save_rgb(col, "mud_albedo.png")
    save_normal(normal_map(clods * 2.5 - crack * 3.0 + noise(n, beta=0.5, lo=60) * 0.4, 1.0), "mud_normal.png")


def sand(n=512):
    """Beach sand: wind ripples, fine grains, a few footprints' worth of disturbance."""
    y, x = np.mgrid[0:n, 0:n] / n
    warp = noise(n, beta=2.5, lo=1) * 0.04
    ripples = np.sin((y + warp) * 2 * np.pi * 14 + noise(n, beta=2.0, lo=1) * 0.8)
    grains = noise(n, beta=0.1, lo=100)
    big = noise(n, beta=2.4, lo=1)
    col = np.stack([0.62 + big * 0.03, 0.50 + big * 0.03, 0.33 + big * 0.02], axis=-1)
    col *= (0.95 + ripples[..., None] * 0.03 + grains[..., None] * 0.035)
    save_rgb(col, "sand_albedo.png")
    save_normal(normal_map(ripples * 2.0 + grains * 0.5 + big * 2.0, 0.8), "sand_normal.png")


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
    for f in (mat, concrete, stand, grass, mud, sand):
        f()
        print("made", f.__name__)
    write_imports()


if __name__ == "__main__":
    sys.exit(main())

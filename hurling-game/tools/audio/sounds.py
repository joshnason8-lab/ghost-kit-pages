#!/usr/bin/env python3
"""The recorded sounds the game ships, made from their sources (each listed in docs/SOUNDS.md with its author and
licence): downloaded into a scratch directory, trimmed, levelled, the loops made seamless (the end crossfaded into the
start), and written as mono Ogg Vorbis, 22,050 a second, into assets/audio/.

  python3 tools/audio/sounds.py <scratch dir>        (needs ffmpeg and numpy)

The game makes the rest of its sounds in code (autoload/sfx.gd); a file here with the same name takes the place of a
made one.
"""
import pathlib
import subprocess
import sys
import urllib.request
import zipfile

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/audio"
RATE = 22050

PACKS = {
    "kenney_impact": "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
    "kenney_ui": "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
    "quendel": "https://opengameart.org/sites/default/files/gregor_quendel_-_free_crowd_cheering_sounds_-_mp3.zip",
}
FILES = {
    "park_birds.wav": "https://opengameart.org/sites/default/files/park_ambience_birds.wav",
}
Q = "quendel/Gregor Quendel - Free Crowd Cheering Sounds - MP3/Gregor Quendel - Crowd Cheering Sounds - "

# name -> (source in the scratch dir, start s (None: the loudest stretch), length s, level, loop)
# level: the stretch's RMS in dBFS for a bed or a crowd (they sit under the play), its peak for a one-shot.
SOUNDS = {
    # The crowd: a stadium's murmur under the play, a cheer for a point, the roar for a goal.
    # (three of each reaction, one picked each time: Sfx.VARIANTS)
    "crowd_loop": (Q + "10 - Ambience.mp3", 0.5, 32.0, ("rms", -22.0), True),
    "crowd_cheer": (Q + "04 - Strong cheering - II - Short.mp3", None, 4.5, ("rms", -16.0), False),
    "crowd_cheer_2": (Q + "05 - Soft cheering - I.mp3", None, 4.5, ("rms", -16.0), False),
    "crowd_cheer_3": (Q + "06 - Soft cheering - II.mp3", None, 4.5, ("rms", -16.0), False),
    "roar": (Q + "03 - Strong cheering - I.mp3", None, 7.0, ("rms", -15.0), False),
    "roar_2": (Q + "01 - Strong cheering and strong rhythmic cheering.mp3", None, 8.0, ("rms", -15.0), False),
    "roar_3": (Q + "02 - Strong cheering and soft rhythmic cheering.mp3", None, 7.0, ("rms", -15.0), False),
    # Birdsong round the parish field and the county ground by day.
    "birds_loop": ("park_birds.wav", 30.0, 90.0, ("rms", -30.0), True),
    # Boots on grass: the man you play.
    "step_1": ("kenney_impact/Audio/footstep_grass_000.ogg", 0.0, 0.5, ("peak", -6.0), False),
    "step_2": ("kenney_impact/Audio/footstep_grass_001.ogg", 0.0, 0.5, ("peak", -6.0), False),
    "step_3": ("kenney_impact/Audio/footstep_grass_002.ogg", 0.0, 0.5, ("peak", -6.0), False),
    "step_4": ("kenney_impact/Audio/footstep_grass_003.ogg", 0.0, 0.5, ("peak", -6.0), False),
    # The game's knocks: hurleys clashing (ash on ash), the aluminium upright, the ball on the grass, into the hand,
    # a shoulder.
    "clash": ("kenney_impact/Audio/impactWood_medium_002.ogg", 0.0, 0.6, ("peak", -2.0), False),
    "post": ("kenney_impact/Audio/impactMetal_light_001.ogg", 0.0, 0.9, ("peak", -2.0), False),
    "bounce": ("kenney_impact/Audio/impactSoft_medium_000.ogg", 0.0, 0.4, ("peak", -4.0), False),
    "catch": ("kenney_impact/Audio/impactPunch_medium_000.ogg", 0.0, 0.4, ("peak", -4.0), False),
    "shoulder": ("kenney_impact/Audio/impactSoft_heavy_001.ogg", 0.0, 0.5, ("peak", -3.0), False),
    # A tap on the menus.
    "click": ("kenney_ui/Audio/click_001.ogg", 0.0, 0.2, ("peak", -6.0), False),
}


def fetch(scratch):
    for name, url in PACKS.items():
        d = scratch / name
        if not d.exists():
            z = scratch / (name + ".zip")
            urllib.request.urlretrieve(url, z)
            d.mkdir(parents=True)
            zipfile.ZipFile(z).extractall(d)
    for name, url in FILES.items():
        if not (scratch / name).exists():
            urllib.request.urlretrieve(url, scratch / name)


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).copy()


def loudest(x, n):
    """Where the loudest stretch of n samples starts."""
    e = np.convolve(x * x, np.ones(RATE // 10), "same")
    c = np.cumsum(e)
    best = np.argmax(c[n:] - c[:-n]) if len(x) > n else 0
    return int(best)


def make(name, src, start, dur, level, loop, scratch):
    x = decode(scratch / src)
    n = int(dur * RATE)
    fade = int(0.6 * RATE) if loop else 0
    a = loudest(x, n) if start is None else int(start * RATE)
    seg = x[a:a + n + fade].astype(np.float64)
    if loop:
        # The end crossfaded into the start, equal power, so the loop has no seam.
        t = np.linspace(0, 1, fade)
        head = seg[:fade] * np.sin(t * np.pi / 2) + seg[n:n + fade] * np.cos(t * np.pi / 2)
        seg = np.concatenate([head, seg[fade:n]])
    else:
        # A short fade in (no click), a longer one out.
        fi = min(len(seg), int(0.004 * RATE))
        seg[:fi] *= np.linspace(0, 1, fi)
        fo = min(len(seg), int((0.6 if dur > 2 else 0.05) * RATE))
        seg[-fo:] *= np.linspace(1, 0, fo)
        # Trimmed of silence at the end.
        loud = np.nonzero(np.abs(seg) > np.max(np.abs(seg)) * 0.01)[0]
        if len(loud):
            seg = seg[:loud[-1] + 1]
    kind, db = level
    have = np.sqrt(np.mean(seg ** 2)) if kind == "rms" else np.max(np.abs(seg))
    seg *= 10 ** (db / 20) / max(have, 1e-9)
    peak = np.max(np.abs(seg))
    if peak > 0.97:
        seg *= 0.97 / peak
    pcm = (seg * 32767).astype("<i2").tobytes()
    out = OUT / f"{name}.ogg"
    q = "3"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", q, str(out)], input=pcm, check=True)
    print(f"{name}: {len(seg) / RATE:.2f} s, {out.stat().st_size // 1024} KB")


def main():
    scratch = pathlib.Path(sys.argv[1])
    scratch.mkdir(parents=True, exist_ok=True)
    fetch(scratch)
    for name, (src, start, dur, level, loop) in SOUNDS.items():
        make(name, src, start, dur, level, loop, scratch)


if __name__ == "__main__":
    main()

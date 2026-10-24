#!/usr/bin/env python3
"""Make the game's recorded sounds (assets/audio/*.ogg) from the downloaded packs listed in docs/SOUNDS.md.

Each sound is cut from its source (or two sources laid over each other), faded in and out, made into a seamless loop
where it plays as one (the end crossfaded into the start), brought to the level of the set (LEVELS), and encoded as
Ogg Vorbis, mono. The packs aren't in the repository (some are tens of megabytes): download each from its page in
docs/SOUNDS.md into one folder, keeping each pack's own file names, then

    python3 tools/audio/prepare_sounds.py DOWNLOADS_DIR [name ...]

Needs ffmpeg (with libvorbis) and numpy.
"""
import pathlib
import subprocess
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "assets" / "audio"

# How loud each kind of sound is made (dBFS): one-shots by their loudest 50 ms, beds and music by their average.
# The ball's sounds sit where the game's synthesised ones did (the volumes in the game were set for those).
LEVELS = {"hit": -12.0, "soft": -14.0, "step": -16.0, "ui": -12.0, "react": -18.0, "bed": -26.0, "amb": -24.0, "music": -18.0}
PEAK = -1.0   # nothing louder than this

KW = "oga-wood-and-metal-sound-effects-volume-2/extracted/wood_and_metal_vol.2/"
KI = "kenney-impact-sounds/extracted/Audio/"
GQ = "oga-free-crowd-cheering-sounds/extracted/Gregor Quendel - Free Crowd Cheering Sounds - MP3/Gregor Quendel - Crowd Cheering Sounds - "
JC = "oga-jc-sounds-nature-ambient-pack-vol-1/extracted/Nature Ambient Pack Vol 1 - mp3/"
FT = "oga-footsteps-on-different-surfaces/extracted/footsteps/tile/"
FZ = "oga-fantozzis-footsteps-grasssand-stone/extracted/Fantozzi-footsteps/flac/"

# name: kind, rate, layers [(source, gain dB, offset s)], start s, length s (None: to the end), fade in, fade out, loop
# crossfade s (0: a one-shot).
SOUNDS = {
    # The ball: a hollow knock for a kick (three takes), a duller one for a thigh, chest or head touch, a knock with a
    # slap for a spike, a heavy thud for a block; on the court and on sand.
    "kick": ("hit", 22050, [(KW + "wood14.aif", 0, 0)], 0, 0.25, 0.0, 0.08, 0),
    "kick_2": ("hit", 22050, [(KW + "wood7.aif", 0, 0)], 0, 0.25, 0.0, 0.08, 0),
    "kick_3": ("hit", 22050, [(KW + "wood10.aif", 0, 0)], 0, 0.25, 0.0, 0.08, 0),
    "knee": ("soft", 22050, [(KI + "impactSoft_medium_000.ogg", 0, 0)], 0, 0.2, 0.0, 0.05, 0),
    "knee_2": ("soft", 22050, [(KI + "impactSoft_medium_002.ogg", 0, 0)], 0, 0.2, 0.0, 0.05, 0),
    "spike": ("hit", 22050, [(KW + "wood1.aif", 0, 0), ("oga-punch-slap-n-kick/extracted/11.ogg", -4, 0)], 0, 0.4, 0.0, 0.12, 0),
    "block": ("hit", 22050, [(KI + "impactPunch_heavy_000.ogg", 0, 0), (KW + "wood1.aif", -8, 0)], 0, 0.35, 0.0, 0.1, 0),
    "bounce": ("soft", 22050, [(KI + "impactWood_medium_000.ogg", 0, 0)], 0, 0.35, 0.0, 0.1, 0),
    "bounce_2": ("soft", 22050, [(KI + "impactWood_medium_002.ogg", 0, 0)], 0, 0.35, 0.0, 0.1, 0),
    "bounce_sand": ("soft", 22050, [(KI + "impactSoft_heavy_000.ogg", 0, 0), (FZ + "Fantozzi-SandL1.flac", -6, 0)], 0, 0.45, 0.0, 0.15, 0),
    # Into the net: a soft thud and the mesh's rustle.
    "net": ("soft", 22050, [(KI + "impactSoft_medium_001.ogg", 0, 0), ("kenney-rpg-audio/extracted/Audio/cloth1.ogg", -3, 0)], 0, 0.5, 0.0, 0.2, 0),
    # The crowd: its murmur (the bed, louder as a rally builds), a cheer, applause.
    "crowd_loop": ("bed", 32000, [(GQ + "10 - Ambience.mp3", 0, 0)], 2.0, 30.0, 0.0, 0.0, 1.5),
    "crowd_cheer": ("react", 32000, [(GQ + "03 - Strong cheering - I.mp3", 0, 0)], 0.0, 3.6, 0.05, 1.2, 0),
    "crowd_cheer_2": ("react", 32000, [(GQ + "04 - Strong cheering - II - Short.mp3", 0, 0)], 0.0, 3.8, 0.05, 1.2, 0),
    "crowd_cheer_3": ("react", 32000, [(GQ + "02 - Strong cheering and soft rhythmic cheering.mp3", 0, 0)], 0.0, 4.0, 0.05, 1.4, 0),
    # The crowd clapping in time at a set point or match point.
    "crowd_rhythm": ("react", 32000, [(GQ + "08 - Rhythmic cheering.mp3", 0, 0)], 0.0, 7.0, 0.3, 1.5, 0),
    "applause": ("react", 32000, [("oga-applause-in-a-large-hall-or-church/applause-clapping-church-crowd-immersive.wav", 0, 0)], 4.0, 4.0, 0.3, 1.5, 0),
    "applause_2": ("react", 32000, [("oga-applause-in-a-large-hall-or-church/applause-clapping-church-crowd-immersive.wav", 0, 0)], 18.0, 4.0, 0.3, 1.5, 0),
    "applause_3": ("react", 32000, [("oga-applause/applause.wav", 0, 0)], 0.5, 4.0, 0.2, 1.5, 0),
    # Each outdoor venue's own sound, and the chatter of a mall or a market.
    "amb_beach": ("amb", 32000, [(JC + "Water Enviroments/AMB_Nature Pack Vol 1_Water Enviroments_Ocean Waves.mp3", 0, 0)], 4.0, 60.0, 0.0, 0.0, 2.5),
    "amb_temple": ("amb", 32000, [(JC + "Forest Enviroments/AMB_Nature Pack Vol 1_Forest Enviroments_Rainforest Canopy.mp3", 0, 0)], 12.0, 60.0, 0.0, 0.0, 2.5),
    "amb_park": ("amb", 32000, [(JC + "Weather/AMB_Nature Pack Vol 1_Weather_Summer Evening.mp3", 0, 0)], 38.5, 36.0, 0.0, 0.0, 2.5),
    "amb_chatter": ("amb", 32000, [("oga-free-general-ambience-sounds/crowd_-_mall_ambience.mp3", 0, 0)], 3.0, 52.0, 0.0, 0.0, 2.5),
    # Footsteps: trainers on a court (a squeak in some), bare feet on sand.
    "step_court": ("step", 22050, [(FT + "0.ogg", 0, 0)], 0, None, 0.0, 0.03, 0),
    "step_court_2": ("step", 22050, [(FT + "3.ogg", 0, 0)], 0, None, 0.0, 0.03, 0),
    "step_court_3": ("step", 22050, [(FT + "6.ogg", 0, 0)], 0, None, 0.0, 0.03, 0),
    "step_sand": ("step", 22050, [(FZ + "Fantozzi-SandL1.flac", 0, 0)], 0, 0.4, 0.0, 0.1, 0),
    "step_sand_2": ("step", 22050, [(FZ + "Fantozzi-SandR1.flac", 0, 0)], 0, 0.4, 0.0, 0.1, 0),
    "step_sand_3": ("step", 22050, [(FZ + "Fantozzi-SandL2.flac", 0, 0)], 0, 0.4, 0.0, 0.1, 0),
    # The menus.
    "click": ("ui", 22050, [("kenney-interface-sounds/extracted/Audio/click_002.ogg", 0, 0)], 0, None, 0.0, 0.0, 0),
    "menu_music": ("music", 32000, [("oga-kingdom-of-a-million-elephants-under-a-white-parasol/kingdom of a million elephants under a white parasol_4.ogg", 0, 0)], 0.0, None, 0.0, 0.0, 0),
}


def decode(path: pathlib.Path, rate: int) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(rate), "-f", "f32le", "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def loudest_50ms(x: np.ndarray, rate: int) -> float:
    w = max(1, int(0.05 * rate))
    return max(np.sqrt(np.mean(x[i:i + w] ** 2)) for i in range(0, max(1, len(x) - w), max(1, w // 2)))


def make(name: str, src: pathlib.Path) -> None:
    kind, rate, layers, start, length, fade_in, fade_out, xfade = SOUNDS[name]
    mix = None
    for path, gain, offset in layers:
        x = decode(src / path, rate) * 10 ** (gain / 20)
        x = np.concatenate([np.zeros(int(offset * rate)), x])
        if mix is None:
            mix = x
        else:
            n = max(len(mix), len(x))
            mix = np.pad(mix, (0, n - len(mix))) + np.pad(x, (0, n - len(x)))
    a = int(start * rate)
    n = len(mix) - a if length is None else int((length + xfade) * rate)
    x = mix[a:a + n].copy()
    if xfade > 0:
        # A seamless loop: the stretch after the end faded into the start.
        k = int(xfade * rate)
        body = x[:-k].copy()
        w = np.linspace(0.0, 1.0, k)
        body[:k] = body[:k] * np.sqrt(w) + x[-k:] * np.sqrt(1.0 - w)
        x = body
    if fade_in > 0:
        k = int(fade_in * rate)
        x[:k] *= np.linspace(0.0, 1.0, k)
    if fade_out > 0:
        k = min(len(x), int(fade_out * rate))
        x[-k:] *= np.linspace(1.0, 0.0, k) ** 2
    # (A one-shot starts at its first sound, not at silence before it.)
    if xfade == 0 and kind not in ("music", "react"):
        on = np.argmax(np.abs(x) > np.max(np.abs(x)) * 0.05)
        x = x[max(0, on - int(0.003 * rate)):]
    level = loudest_50ms(x, rate) if kind in ("hit", "soft", "step", "ui") else np.sqrt(np.mean(x ** 2))
    x *= 10 ** (LEVELS[kind] / 20) / max(level, 1e-9)
    peak = np.max(np.abs(x))
    if peak > 10 ** (PEAK / 20):
        x *= 10 ** (PEAK / 20) / peak
    out = OUT / (name + ".ogg")
    q = "2" if kind in ("music", "amb", "bed") else "3"   # (the long ones a little smaller)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(rate), "-ac", "1", "-i", "-", "-c:a", "libvorbis",
                    "-q:a", q, str(out)], input=x.astype(np.float32).tobytes(), check=True)
    print("%-14s %5.2f s  %6.1f KB  %s" % (name, len(x) / rate, out.stat().st_size / 1024, kind))


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    src = pathlib.Path(sys.argv[1])
    names = sys.argv[2:] or list(SOUNDS)
    for name in names:
        make(name, src)
    return 0


if __name__ == "__main__":
    sys.exit(main())

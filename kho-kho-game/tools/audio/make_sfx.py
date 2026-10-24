#!/usr/bin/env python3
"""The recorded sounds the game plays, made from their sources (Kenney's packs and OpenGameArt; docs/SOUNDS.md says
where each comes from, who made it and under what licence). The sources are not in the repository; download them to
one folder (SRC), as docs/SOUNDS.md lists, then:

    python3 tools/audio/make_sfx.py SRC assets/audio

Each sound is cut from its source, made mono at 22,050 Hz (the game's rate), filtered where the recording carries
noise the game does not want, set to a common loudness (one-shots by their peak, beds by their average), faded at its
ends, and for a loop, its end crossfaded into its start so it loops without a seam. Written as Ogg Vorbis (needs
ffmpeg with libvorbis).
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

RATE = 22050

# name in the game: source file (under SRC), start and length kept (s), kind, filter, level
#   kind: "hit" a short one-shot, cut from where it starts, set by its peak (dBFS); "swell" a long one-shot (a cheer,
#   applause), set by its average (dBFS RMS); "bed" a loop, set by its average
SOUNDS = {
    # The kho: a palm on the seated chaser's back. Two takes of a slap (CGEffex, via congusbongus).
    "slap_1": ("hits/3.ogg", 0.0, 0.3, "hit", None, -3.0),
    "slap_2": ("hits/5.ogg", 0.0, 0.3, "hit", None, -3.0),
    # A dive landing: a body on soft ground (Kenney, Impact Sounds).
    "thud_1": ("impact-sounds/Audio/impactSoft_heavy_000.ogg", 0.0, 0.45, "hit", None, -2.0),
    "thud_2": ("impact-sounds/Audio/impactSoft_heavy_002.ogg", 0.0, 0.45, "hit", None, -2.0),
    # Footsteps: on earth (the outdoor grounds) and on the hall's mat (Kenney, Impact Sounds: grass, carpet).
    "step_earth_1": ("impact-sounds/Audio/footstep_grass_000.ogg", 0.0, 0.22, "hit", "highpass=f=70", -6.0),
    "step_earth_2": ("impact-sounds/Audio/footstep_grass_001.ogg", 0.0, 0.22, "hit", "highpass=f=70", -6.0),
    "step_earth_3": ("impact-sounds/Audio/footstep_grass_002.ogg", 0.0, 0.22, "hit", "highpass=f=70", -6.0),
    "step_earth_4": ("impact-sounds/Audio/footstep_grass_003.ogg", 0.0, 0.22, "hit", "highpass=f=70", -6.0),
    # (Kenney's carpet has three different takes: 001 and 002 are one, 003 and 004 another.)
    "step_mat_1": ("impact-sounds/Audio/footstep_carpet_000.ogg", 0.0, 0.18, "hit", "highpass=f=70", -6.0),
    "step_mat_2": ("impact-sounds/Audio/footstep_carpet_001.ogg", 0.0, 0.18, "hit", "highpass=f=70", -6.0),
    "step_mat_3": ("impact-sounds/Audio/footstep_carpet_003.ogg", 0.0, 0.18, "hit", "highpass=f=70", -6.0),
    # The menus' tap (Kenney, UI Audio).
    "click": ("ui-audio/Audio/click1.ogg", 0.0, 0.2, "hit", None, -6.0),
    # The crowd: a stand's murmur and cheering, a cheer, applause (Gregor Quendel; eXpl0it3r).
    "crowd_loop": ("cheering/Gregor Quendel - Free Crowd Cheering Sounds - MP3/Gregor Quendel - Crowd Cheering Sounds - 10 - Ambience.mp3", 10.0, 24.0, "bed", "highpass=f=80", -20.0),
    "crowd_cheer": ("cheering/Gregor Quendel - Free Crowd Cheering Sounds - MP3/Gregor Quendel - Crowd Cheering Sounds - 04 - Strong cheering - II - Short.mp3", 5.0, 10.0, "swell", None, -15.0),
    "applause": ("applause-clapping-church-crowd-immersive.wav", 1.0, 5.5, "swell", None, -17.0),
    # The places: crickets at the village's dusk and the stadium's night (Wolfgang_), birds at the school's noon
    # (Thimras, a park; its traffic's rumble filtered out).
    "amb_crickets": ("crickets_1.mp3", 0.0, 11.4, "bed", None, -24.0),
    "amb_birds": ("park_ambience_birds.wav", 185.0, 205.0, "bed", "highpass=f=300", -26.0),
}
FADE_IN = 0.004
LOOP_XFADE = 0.8


def read(path, start, end, filt):
    with tempfile.NamedTemporaryFile(suffix=".f32") as tmp:
        af = ["-af", filt] if filt else []
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(start), "-t", str(end - start), "-i", path, *af,
                        "-ac", "1", "-ar", str(RATE), "-f", "f32le", tmp.name], check=True)
        return np.fromfile(tmp.name, np.float32).astype(np.float64)


def write_ogg(x, out, quality):
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", str(quality), out], check=True)


def make(src, name, spec):
    path, start, end, kind, filt, level = spec
    if kind == "hit":
        # From its first sound (wherever it is in the file), as long as asked or to where it has died away.
        x = read(os.path.join(src, path), start, end + 2.0, filt)
        x -= x.mean()
        on = np.argmax(np.abs(x) > np.abs(x).max() * 0.05)
        x = x[max(0, on - int(0.003 * RATE)):][:int((end - start) * RATE)]
        env = np.abs(x)
        tail = np.where(env > env.max() * 0.003)[0]
        x = x[:tail[-1] + 1] if len(tail) else x
        x *= 10 ** (level / 20) / np.abs(x).max()
    if kind in ("hit", "swell"):
        if kind == "swell":
            x = read(os.path.join(src, path), start, end, filt)
            x -= x.mean()
            x *= 10 ** (level / 20) / np.sqrt(np.mean(x ** 2))
            x *= min(1.0, 0.97 / np.abs(x).max())
        n_in = int((FADE_IN if kind == "hit" else 0.15) * RATE)
        x[:n_in] *= np.linspace(0, 1, n_in)
        n_out = min(len(x) // 3, int(0.08 * RATE)) if kind == "hit" else int(1.2 * RATE)
        x[-n_out:] *= np.linspace(1, 0, n_out) ** 2
        return x, 3
    x = read(os.path.join(src, path), start, end, filt)
    x -= x.mean()
    # A bed: its end crossfaded into its start (equal power), set by its average.
    n = int(LOOP_XFADE * RATE)
    body, tail = x[:-n].copy(), x[-n:]
    t = np.linspace(0, np.pi / 2, n)
    body[:n] = body[:n] * np.sin(t) + tail * np.cos(t)
    body *= 10 ** (level / 20) / np.sqrt(np.mean(body ** 2))
    peak = np.abs(body).max()
    if peak > 0.97:
        body *= 0.97 / peak
    return body, 2


def main():
    src, out = sys.argv[1], sys.argv[2]
    for name, spec in SOUNDS.items():
        x, q = make(src, name, spec)
        dest = os.path.join(out, name + ".ogg")
        write_ogg(x, dest, q)
        print("%-14s %5.2f s  %6.1f KB  <- %s" % (name, len(x) / RATE, os.path.getsize(dest) / 1024, spec[0].split("/")[-1]))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Make the game's recorded sounds in assets/audio/ from the downloads listed in docs/SOUNDS.md.

Every source is CC0, CC-BY or OGA-BY (kenney.nl and opengameart.org); docs/SOUNDS.md and the Licences screen credit
each one. The downloads are not kept in the repository: fetch them (the URLs are in docs/SOUNDS.md), unpack any
archives anywhere under one folder, and point this script at it. Files are found by their own names.

What it does to each:
  one-shots (footsteps, thuds, slaps, the click): mono, 22.05 kHz, silence trimmed off both ends, a short fade out,
    peak-normalised (so the game's per-call volumes set the mix);
  beds and ambiences (the crowd, rain, waves, birds, crickets): mono, the steadiest stretch of the recording, set to
    one loudness (RMS), and crossfaded end into start so it loops without a seam;
  cheers and applause: the loudest stretch, faded in and out.
Then Ogg Vorbis at a low quality setting: these play under a match, and small files keep the APK small.

Needs: python3 with numpy and scipy, ffmpeg (with libvorbis).
    python3 tools/audio/make_recorded.py ~/Downloads/kabaddi-sounds      # writes assets/audio/*.ogg
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

RATE = 22050
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "audio"))
QUENDEL = "Gregor Quendel - Crowd Cheering Sounds - "

# name in the game: [source file, ...] (one-shots: one file per variant, name_1, name_2...)
STEPS = {
    "step_mat": ["footstep_carpet_000.ogg", "footstep_carpet_001.ogg", "footstep_carpet_003.ogg"],    # Kenney
    "step_earth": ["footstep_grass_000.ogg", "footstep_grass_001.ogg", "footstep_grass_002.ogg",
                   "footstep_grass_004.ogg"],                                                         # Kenney
    "step_sand": ["Fantozzi-SandL1.flac", "Fantozzi-SandR1.flac", "Fantozzi-SandL2.flac",
                  "Fantozzi-SandR3.flac"],                                                            # Fantozzi
}
HITS = {
    "thud": ["impactSoft_heavy_000.ogg", "impactSoft_heavy_002.ogg", "impactSoft_heavy_003.ogg"],     # Kenney
    "slap": ["impactSoft_medium_000.ogg", "impactSoft_medium_001.ogg", "impactSoft_medium_003.ogg"],  # Kenney
}


def find(root, name):
    for d, _, files in os.walk(root):
        if name in files:
            return os.path.join(d, name)
    sys.exit("not found under %s: %s" % (root, name))


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def save(name, x, quality):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    path = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(quality), path],
                   check=True)
    os.unlink(tmp)
    print("wrote %-22s %5.2f s %4d KB" % (name + ".ogg", len(x) / RATE, os.path.getsize(path) // 1024))


def env(x, win=0.05):
    n = max(1, int(win * RATE))
    return np.sqrt(np.convolve(x * x, np.ones(n) / n, "same"))


def trim(x, floor_db=-40.0, pad=0.01):
    """Cut the silence off both ends (below floor_db of the peak), keeping a little before the onset."""
    e = env(x, 0.005)
    on = np.where(e > e.max() * 10 ** (floor_db / 20))[0]
    a = max(0, on[0] - int(pad * RATE))
    return x[a:on[-1] + 1]


def fade(x, a=0.002, r=0.03):
    out = x.copy()
    na, nr = int(a * RATE), min(len(x), int(r * RATE))
    if na:
        out[:na] *= np.linspace(0, 1, na)
    if nr:
        out[-nr:] *= np.linspace(1, 0, nr)
    return out


def peak(x, db=-1.0):
    return x / (np.max(np.abs(x)) or 1.0) * 10 ** (db / 20)


def rms_to(x, db):
    return x / (np.sqrt(np.mean(x * x)) or 1.0) * 10 ** (db / 20)


def highpass(x, hz, order=2):
    """Rumble and handling noise out of the field recordings."""
    return signal.sosfilt(signal.butter(order, hz, "high", fs=RATE, output="sos"), x)


def steadiest(x, dur):
    """The stretch of dur seconds whose loudness varies least (a bed with no one shout or gust in it)."""
    n = int(dur * RATE)
    e = env(x, 0.25)
    best, at = None, 0
    for s in range(0, len(x) - n, RATE // 2):
        v = np.std(e[s:s + n]) / (np.mean(e[s:s + n]) or 1.0)
        if best is None or v < best:
            best, at = v, s
    return x[at:at + n]


def loudest(x, dur):
    n = int(dur * RATE)
    e = env(x, 0.5)
    s = int(np.clip(np.argmax(np.convolve(e, np.ones(n), "valid")), 0, max(0, len(x) - n)))
    return x[s:s + n]


def loopable(x, cross=1.0):
    """Crossfade the tail into the head (equal power) so the clip loops without a seam."""
    n = int(cross * RATE)
    w = np.linspace(0, 1, n)
    head = x[:n] * np.sqrt(w) + x[-n:] * np.sqrt(1 - w)
    return np.concatenate([head, x[n:-n]])


def one_shots(root, table, quality=1):
    for name, files in table.items():
        for i, f in enumerate(files):
            save("%s_%d" % (name, i + 1), peak(fade(trim(load(find(root, f))))), quality)


def bed(root, name, f, dur, db, hp=0.0, quality=0):
    x = load(find(root, f))
    if hp:
        x = highpass(x, hp)
    save(name, rms_to(loopable(steadiest(x, dur + 1.0)), db), quality)


def waves(root):
    """The sea: the four waves of one recording, overlapping one after another round a 32 s loop, each twice, the
    second time a little softer and later, so no two come round alike."""
    x = np.zeros(32 * RATE)
    at = 0.0
    for i, f in enumerate(["wave_0%d_cc0-18363__jasinski__alkaibeach.flac" % k for k in (1, 3, 2, 4, 3, 1, 4, 2)]):
        w = load(find(root, f))
        s = int(at * RATE)
        for j in range(len(w)):   # wrapped round, so the last wave runs on into the first
            x[(s + j) % len(x)] += w[j] * (1.0 if i < 4 else 0.8)
        at += 4.0 if i < 4 else 4.3
    save("amb_beach", rms_to(x, -22.0), 0)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    root = sys.argv[1]
    one_shots(root, STEPS)
    one_shots(root, HITS)
    # The UI's click (Kenney Interface Sounds).
    save("click", peak(fade(trim(load(find(root, "click_002.ogg"))), 0.0005, 0.005), -3.0), 2)
    # The crowd: Gregor Quendel's crowd at a match (CC-BY 4.0).
    # (0.12.0: the bed and the grounds' loops two to three times as long, so they come round less often; three
    # cheers, one picked each time; the crowd's rhythmic chant for a do-or-die raid.)
    bed(root, "crowd_loop", QUENDEL + "10 - Ambience.mp3", 30.0, -18.0, 60.0)
    for i, (f, at) in enumerate([("04 - Strong cheering - II - Short", None), ("02 - Strong cheering and soft rhythmic"
                                 " cheering", None), ("05 - Soft cheering - I", None)]):
        save("crowd_cheer_%d" % (i + 1), rms_to(fade(loudest(load(find(root, QUENDEL + f + ".mp3")), 5.0),
                                                     0.15, 2.0), -14.0), 1)
    save("crowd_rhythm", rms_to(fade(loudest(load(find(root, QUENDEL + "08 - Rhythmic cheering.mp3")), 8.0), 0.5, 2.5),
                                -16.0), 1)
    save("roar", rms_to(fade(loudest(load(find(root, QUENDEL + "03 - Strong cheering - I.mp3")), 3.5), 0.25, 1.5), -14.0), 1)
    save("applause", rms_to(fade(loudest(load(find(root, "applause-clapping-church-crowd-immersive.wav")), 5.0),
                                 0.2, 2.0), -16.0), 1)
    # Each ground's own sound under the crowd.
    bed(root, "amb_monsoon", "amb_rain_loop_1.wav", 40.0, -22.0)                 # Kresiek The Furry, CC0
    bed(root, "amb_village", "park_ambience_birds.wav", 40.0, -26.0, 150.0)      # Thimras, CC0
    bed(root, "amb_stadium", "crickets_1.mp3", 10.0, -28.0, 1500.0)              # Wolfgang_, CC0
    waves(root)                                                                 # jasinski, CC0


if __name__ == "__main__":
    main()

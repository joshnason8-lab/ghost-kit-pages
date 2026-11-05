#!/usr/bin/env python3
"""Make the crowd's reactions and the players' voices in assets/audio/ from CC0 recordings on freesound.org.

0.13.0 replaced the synthetic ones (tools/audio/make_sounds.py) with these: a real crowd's gasp and disappointed sigh,
and real men's grunts, pain sounds and breaths. Each source is fetched by tools/audio/freesound_fetch.py, which checks
on the sound's page that it is CC0; docs/SOUNDS.md and the Licences screen credit each one anyway.

A file with several takes (a grunt pack) is cut into its takes at the silences between them. Each one-shot is then as
tools/audio/make_recorded.py makes them: mono, 22.05 kHz, trimmed, faded, peak-normalised, Ogg Vorbis.

    python3 tools/audio/make_freesound.py [download folder]       # writes assets/audio/*.ogg
"""
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_recorded import RATE, env, fade, highpass, load, loudest, peak, save, trim  # noqa: E402

# name in the game: (freesound id, which take (0: the whole file), what to do with it)
SOUNDS = {
    "crowd_ooh": (763875, 0, "whole"),          # ShangusBurger: crowd gasping in surprise, voiced
    "crowd_groan": (763880, 0, "sigh"),         # ShangusBurger: crowd sigh in disappointment
    "grunt_1": (256603, 1, "take"),             # Kodack: male grunts
    "grunt_2": (256603, 2, "take"),
    "grunt_3": (256603, 3, "take"),
    "grunt_4": (795440, 1, "take"),             # randbsoundbites: grunting
    "grunt_5": (795440, 3, "take"),
    "oof_1": (547209, 0, "whole"),              # MrFossy: adult male pain grunt
    "oof_2": (413186, 0, "whole"),              # micahlg: male hurt
    "oof_3": (795440, 2, "take"),
    "hup_1": (558489, 3, "take"),               # SuddenDice: short exertion
    "hup_2": (558489, 1, "take"),
    "exhale_1": (65619, 0, "whole"),            # otherthings: exhale
    "exhale_2": (65619, 0, "lower"),
}


def takes(x, floor_db=-35.0, gap=0.12):
    """The takes in a file of several, split at silences of gap seconds or more."""
    e = env(x, 0.01)
    on = e > e.max() * 10 ** (floor_db / 20)
    out, start, quiet = [], None, 0
    for i, v in enumerate(on):
        if v:
            if start is None:
                start = i
            quiet = 0
        elif start is not None:
            quiet += 1
            if quiet > gap * RATE:
                out.append(x[start:i - quiet + 1])
                start, quiet = None, 0
    if start is not None:
        out.append(x[start:])
    return [t for t in out if len(t) > 0.08 * RATE]


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "build", "freesound")
    ids = sorted({v[0] for v in SOUNDS.values()})
    missing = [str(i) for i in ids if not os.path.exists(os.path.join(src, "%d.ogg" % i))]
    if missing:
        subprocess.run([sys.executable, os.path.join(HERE, "freesound_fetch.py"), src] + missing, check=True)
    for name, (sid, take, how) in SOUNDS.items():
        x = highpass(load(os.path.join(src, "%d.ogg" % sid)), 70.0)
        if take:
            x = takes(x)[take - 1]
        if how == "sigh":
            x = loudest(x, 3.6)
            x = fade(trim(x, -45.0), 0.08, 0.8)
        elif how == "lower":
            # The same breath a little deeper and longer: another man's.
            n = int(len(x) / 0.9)
            x = np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)
            x = fade(trim(x), 0.004, 0.08)
        else:
            x = fade(trim(x, -40.0 if how == "take" else -45.0), 0.003, 0.06)
        save(name, peak(x, -1.0), 2 if name.startswith("crowd") else 1)


if __name__ == "__main__":
    main()

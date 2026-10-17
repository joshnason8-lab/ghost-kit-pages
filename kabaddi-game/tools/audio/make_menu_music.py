#!/usr/bin/env python3
"""The menus' music: assets/audio/menu_music.ogg, from "Indian" by LNPLUSMUSIC (Pixabay, track 611803).

    python3 tools/audio/make_menu_music.py lnplusmusic-indian-indian-music-611803.mp3

The track (80 BPM, 80 s) is a quiet opening, a full section from 13.875 s, a softer bar or four, the full
section again, and a fade from 73.875 s. The menus play the opening once and then the middle minute (13.875 s
to 73.875 s, 20 bars) round and round: the file runs to 73.875 s, its last few hundredths of a second fading
into the start of the loop, and Sfx loops it from just after that (LOOP_START, printed here), so the joint is
on a downbeat with no click and no gap. Loudness is brought to about -16 LUFS.

The track is under the Pixabay Content License (pixabay.com/service/license-summary): free to use in an app,
edited, without credit (credited anyway, in docs/ASSETS.md). The licence does not allow passing the track on
by itself, so only this edited loop, inside the game, is in the repository; not the download.
"""
import json
import os
import subprocess
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "audio", "menu_music.ogg"))
SR = 44100
LOOP_A = 13.875   # s, the downbeat the full section starts on
LOOP_B = 73.875   # s, the same downbeat 20 bars on, where the fade begins
XF = 0.04         # s of crossfade at the joint


def main(src):
    with tempfile.TemporaryDirectory() as tmp:
        raw = os.path.join(tmp, "a.f32")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-ac", "2", "-ar", str(SR), "-f", "f32le", raw],
                       check=True)
        x = np.fromfile(raw, dtype=np.float32).reshape(-1, 2)
        a, b, n = int(LOOP_A * SR), int(LOOP_B * SR), int(XF * SR)
        ramp = np.linspace(0.0, 1.0, n, dtype=np.float32)[:, None]
        joint = x[b:b + n] * (1.0 - ramp) + x[a:a + n] * ramp
        y = np.concatenate([x[:b], joint])
        y[: int(0.02 * SR)] *= np.linspace(0.0, 1.0, int(0.02 * SR), dtype=np.float32)[:, None]
        pcm = os.path.join(tmp, "b.f32")
        y.astype(np.float32).tofile(pcm)
        inp = ["-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", pcm]
        # One gain for the whole file (loudnorm measured, then applied linearly): a gain that moved with the music
        # would be different at the two ends of the loop's joint.
        m = subprocess.run(["ffmpeg", "-hide_banner", "-y"] + inp + ["-af", "loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json",
                           "-f", "null", "-"], check=True, capture_output=True, text=True).stderr
        js = json.loads(m[m.rindex("{"):m.rindex("}") + 1])
        norm = ("loudnorm=I=-16:TP=-1.5:LRA=11:linear=true:measured_I=%s:measured_TP=%s:measured_LRA=%s:"
                "measured_thresh=%s:offset=%s" % (js["input_i"], js["input_tp"], js["input_lra"], js["input_thresh"],
                                                   js["target_offset"]))
        subprocess.run(["ffmpeg", "-v", "error", "-y"] + inp + ["-af", norm, "-ar", str(SR), "-c:a", "libvorbis",
                        "-q:a", "4", OUT], check=True)
    print("wrote", OUT)
    print("LOOP_START = %.4f" % (LOOP_A + XF))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1])

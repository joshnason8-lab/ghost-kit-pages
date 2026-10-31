#!/usr/bin/env python3
"""The game's music, slower than before (0.13.0), from CC0 recordings on freesound.org:

  menu_music.ogg  the menus: a tanpura's drone ("Tanpura 10" by sankalp, 153262) under a tabla playing kherwa ("Tabla
                  Rhythm Bayan Tala Kherwa" by afleetingspeck, 151176), the tabla slowed from about 107 to 75 beats a
                  minute. The tabla is tuned near C sharp (142 Hz) and the tanpura's Sa a little under it (138.6 Hz):
                  the tanpura is raised 42 cents to sit with it. Six of the tabla's cycles, 38.4 s, round and round.
  dhol_loop.ogg   under a match (Sfx.drums): a tabla loop ("tabla 5to4 85bpm -loop" by MieliTietty, 633150) slowed from
                  85 to 72 beats a minute, its 48 beats a seamless loop of 40 s. (Before, a dhol synthesised at 100.)

Both set to about -16 LUFS, Ogg Vorbis. Slowed with ffmpeg's atempo (the pitch kept).

    python3 tools/audio/make_music.py [download folder]      # fetches what is missing (tools/audio/freesound_fetch.py)
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "audio"))
SR = 44100
TANPURA, KHERWA, TABLA = 153262, 151176, 633150
KHERWA_CYCLE = 4.48     # s, its eight beats as recorded (onset autocorrelation)
MENU_TEMPO = 0.70       # 107 -> 75 beats a minute
MATCH_TEMPO = 72.0 / 85.0


def load(path, filters=""):
    cmd = ["ffmpeg", "-v", "error", "-i", path]
    if filters:
        cmd += ["-af", filters]
    raw = subprocess.run(cmd + ["-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def rms_to(x, db):
    return x / (np.sqrt(np.mean(x * x)) or 1.0) * 10 ** (db / 20)


def loop_join(x, cross):
    """The tail crossfaded into the head (equal power), so it loops without a seam."""
    n = int(cross * SR)
    w = np.linspace(0, 1, n)
    return np.concatenate([x[:n] * np.sqrt(w) + x[-n:] * np.sqrt(1 - w), x[n:-n]])


def first_onset(x):
    e = np.convolve(np.abs(x), np.ones(441) / 441, "same")
    return int(np.argmax(e > e.max() * 0.3))


def save(name, x):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    path = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", tmp, "-af", "loudnorm=I=-16:TP=-1.5:LRA=11",
                    "-ar", "44100", "-c:a", "libvorbis", "-q:a", "3", path], check=True)
    os.unlink(tmp)
    print("wrote %-16s %5.1f s %4d KB" % (name + ".ogg", len(x) / SR, os.path.getsize(path) // 1024))


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "build", "freesound")
    missing = [str(i) for i in (TANPURA, KHERWA, TABLA) if not os.path.exists(os.path.join(src, "%d.ogg" % i))]
    if missing:
        subprocess.run([sys.executable, os.path.join(HERE, "freesound_fetch.py"), src] + missing, check=True)
    p = lambda i: os.path.join(src, "%d.ogg" % i)

    # The menus.
    kher = load(p(KHERWA), "atempo=%.4f" % MENU_TEMPO)
    cycle = int(KHERWA_CYCLE / MENU_TEMPO * SR)
    at = first_onset(kher)
    two = kher[at:at + 2 * cycle]
    if len(two) < 2 * cycle:
        two = np.concatenate([two, np.zeros(2 * cycle - len(two))])
    fade = int(0.03 * SR)
    two[-fade:] *= np.linspace(1, 0, fade)
    tabla = np.tile(two, 3)                                  # six cycles
    n = len(tabla)
    k = 2 ** (42 / 1200)
    drone = load(p(TANPURA), "asetrate=%d,aresample=%d,atempo=%.5f" % (int(SR * k), SR, 1 / k))
    drone = drone[int(2.0 * SR):int(2.0 * SR) + n + int(2.0 * SR)]
    drone = loop_join(drone, 2.0)[:n]
    save("menu_music", rms_to(drone, -22.0) + rms_to(tabla, -21.0))

    # A match.
    t = load(p(TABLA), "atempo=%.5f" % MATCH_TEMPO)
    save("dhol_loop", loop_join(t, 0.05))


if __name__ == "__main__":
    main()

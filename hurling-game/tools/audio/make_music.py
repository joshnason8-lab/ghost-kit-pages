#!/usr/bin/env python3
"""Make the menus' music: assets/audio/menu_music.ogg, a jig of the game's own in D, as a session might play it on a
summer evening: a tin whistle with the tune, a harp picking the chords, a bodhrán keeping the 6/8 lilt. All
synthesised; the tune is written for the game (two parts of eight bars, each played once, then back to the top, so
it loops).

Usage: python3 tools/audio/make_music.py   (needs numpy and ffmpeg with libvorbis)
"""
import pathlib
import subprocess
import tempfile
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio"
RATE = 44100
EIGHTH = 60.0 / 92.0 / 3.0   # a dotted crotchet at 92: an easy, lilting jig
rng = np.random.default_rng(11)

# D major, from the D above middle C.
D_MAJOR = [293.66, 329.63, 369.99, 392.00, 440.00, 493.88, 554.37, 587.33, 659.26, 739.99, 783.99, 880.00]

# The tune: (degree, eighths). Each bar is six eighths.
PART_A = [
    (4, 2), (7, 1), (9, 2), (7, 1),
    (8, 1), (7, 1), (5, 1), (4, 2), (2, 1),
    (3, 2), (5, 1), (8, 2), (5, 1),
    (4, 3), (4, 2), (2, 1),
    (4, 2), (7, 1), (9, 2), (11, 1),
    (10, 1), (9, 1), (8, 1), (7, 2), (5, 1),
    (4, 1), (5, 1), (7, 1), (8, 1), (6, 1), (4, 1),
    (7, 3), (7, 3),
]
PART_B = [
    (9, 2), (10, 1), (11, 2), (9, 1),
    (10, 1), (9, 1), (8, 1), (9, 2), (7, 1),
    (8, 2), (9, 1), (10, 2), (8, 1),
    (9, 3), (7, 2), (5, 1),
    (4, 2), (7, 1), (9, 2), (7, 1),
    (8, 1), (7, 1), (5, 1), (4, 2), (3, 1),
    (2, 1), (4, 1), (7, 1), (6, 1), (8, 1), (6, 1),
    (7, 3), (7, 2), (4, 1),
]
# A chord root (Hz, low) for each bar, played on the two beats of the bar.
CHORDS = [146.8, 196.0, 196.0, 220.0, 146.8, 196.0, 220.0, 146.8, 146.8, 196.0, 196.0, 146.8, 146.8, 196.0, 220.0, 146.8]
THIRDS = {146.8: 1.26, 196.0: 1.26, 220.0: 1.26}


def env(n, attack, decay):
    t = np.arange(n) / RATE
    return np.minimum(1.0, t / attack) * np.exp(-t / decay)


def whistle(freq, dur):
    """A tin whistle: a nearly pure tone, a little second harmonic, breath, and vibrato that comes in on long notes."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1.0, t / 0.25)
    phase = 2 * np.pi * np.cumsum(freq * vib) / RATE
    s = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.05 * np.sin(3 * phase)
    breath = np.convolve(rng.uniform(-1, 1, n), np.ones(6) / 6, mode="same") * 0.06
    shape = np.minimum(1.0, t / 0.02) * np.clip((dur - t) / 0.04, 0.0, 1.0) * (0.85 + 0.15 * np.exp(-t / 0.08))
    return (s + breath) * shape


def harp(freq, dur):
    """A plucked string (Karplus-Strong)."""
    n = int(dur * RATE)
    period = max(2, int(RATE / freq))
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = 0.5 * (buf[i % period] + buf[(i + 1) % period]) * 0.996
    return out * env(n, 0.002, 1.2)


def bodhran(strong):
    """The frame drum: a low, bending thump on the beat, a lighter tap off it."""
    dur = 0.35 if strong else 0.15
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    f0, f1 = (110, 62) if strong else (190, 140)
    f = f1 + (f0 - f1) * np.exp(-t / 0.03)
    s = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(n, 0.002, 0.16 if strong else 0.05)
    s += 0.15 * rng.uniform(-1, 1, n) * env(n, 0.001, 0.01)
    return s


def put(buf, at, sound, gain):
    i = int(at * RATE)
    j = min(len(buf), i + len(sound))
    if i < len(buf):
        buf[i:j] += sound[: j - i] * gain


def write_ogg(name, samples, quality=3):
    samples = samples / max(1e-6, np.max(np.abs(samples))) * 0.85
    pcm = (samples * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as d:
        wav = pathlib.Path(d) / "x.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", str(quality),
                        str(OUT / name)], check=True)
    print("wrote", OUT / name)


def music():
    tune = PART_A + PART_B
    eighths = sum(l for _, l in tune)
    assert eighths == 16 * 6, eighths
    dur = eighths * EIGHTH
    buf = np.zeros(int(dur * RATE) + RATE * 3)
    at = 0.0
    for deg, length in tune:
        put(buf, at, whistle(D_MAJOR[deg], length * EIGHTH * 0.97), 0.34)
        at += length * EIGHTH
    for bar, root in enumerate(CHORDS):
        for beat in range(2):
            t0 = (bar * 6 + beat * 3) * EIGHTH
            put(buf, t0, harp(root, 1.6), 0.22)
            put(buf, t0 + EIGHTH * 0.5, harp(root * THIRDS[root], 1.2), 0.12)
            put(buf, t0 + EIGHTH, harp(root * 1.5, 1.2), 0.12)
    for e in range(eighths):
        strong = e % 3 == 0
        put(buf, e * EIGHTH, bodhran(strong), 0.32 if e % 6 == 0 else (0.22 if strong else 0.1))
    n = int(dur * RATE)
    tail = buf[n:]
    buf[: len(tail)] += tail
    write_ogg("menu_music.ogg", buf[:n])


if __name__ == "__main__":
    music()

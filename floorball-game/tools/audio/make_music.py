#!/usr/bin/env python3
"""Make the menus' music: assets/audio/menu_music.ogg, a loop written for the game and synthesised here.

A sports-hall warm-up track: four-on-the-floor kick, hand claps on two and four as a floorball crowd claps, a
plucked synth bass, and a bright lead on a minor pentatonic hook, 124 beats a minute, 16 bars, looping cleanly.

Usage: python3 tools/audio/make_music.py   (needs numpy and ffmpeg with libvorbis)
"""
import pathlib
import subprocess
import tempfile
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
RATE = 44100
BPM = 124
BEAT = 60.0 / BPM
BARS = 16
N = int(BARS * 4 * BEAT * RATE)
rng = np.random.default_rng(26)


def env(n, a, d):
    t = np.arange(n) / RATE
    return np.minimum(1.0, t / a) * np.exp(-t / d)


def add(buf, at, s):
    i = int(at * RATE) % N
    end = min(N, i + len(s))
    buf[i:end] += s[: end - i]
    if i + len(s) > N:
        buf[: i + len(s) - N] += s[end - i:]


def kick():
    n = int(0.35 * RATE)
    t = np.arange(n) / RATE
    f = 50 + 90 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(n, 0.002, 0.12) * 0.9


def clap():
    n = int(0.2 * RATE)
    s = rng.uniform(-1, 1, n)
    s = np.convolve(s, np.ones(6) / 6, "same")
    e = np.zeros(n)
    for k in range(3):
        o = int(k * 0.011 * RATE)
        e[o:] += env(n - o, 0.001, 0.02 if k < 2 else 0.07)
    return s * e * 0.35


def hat():
    n = int(0.06 * RATE)
    s = rng.uniform(-1, 1, n)
    s = s - np.convolve(s, np.ones(4) / 4, "same")
    return s * env(n, 0.001, 0.015) * 0.18


def pluck(freq, dur, bright=1.0):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    s = np.sign(np.sin(2 * np.pi * freq * t)) * 0.4 + np.sin(2 * np.pi * freq * t) * 0.6
    s = np.convolve(s, np.ones(int(8 / bright)) / int(8 / bright), "same")
    return s * env(n, 0.003, dur * 0.45)


def lead(freq, dur):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    vib = np.sin(2 * np.pi * 5.5 * t) * 0.003
    s = np.sin(2 * np.pi * freq * (1 + vib) * t) + 0.35 * np.sin(4 * np.pi * freq * t) + 0.15 * np.sin(6 * np.pi * freq * t)
    return s * env(n, 0.01, dur * 0.7) * 0.18


def main():
    buf = np.zeros(N)
    A = 110.0
    semis = lambda s: A * 2 ** (s / 12)
    bassline = [0, 0, 7, 5, 3, 3, 5, 7]          # A minor: A, E, D, C ...
    chords = [0, 0, -4, -2] * 4                   # Am Am F G
    for bar in range(BARS):
        root = chords[bar]
        for b in range(4):
            at = (bar * 4 + b) * BEAT
            add(buf, at, kick())
            if b in (1, 3):
                add(buf, at, clap())
            add(buf, at + BEAT / 2, hat())
            for e in range(2):
                add(buf, at + e * BEAT / 2, pluck(semis(root + bassline[(b * 2 + e) % 8] - 12) / 2, BEAT / 2, 1.0) * 0.5)
        if bar >= 4:
            hook = [12, 15, 17, 19, 17, 15, 12, 10] if bar % 2 == 0 else [12, 15, 19, 22, 19, 17, 15, 12]
            for k, s in enumerate(hook):
                add(buf, bar * 4 * BEAT + k * BEAT / 2, lead(semis(root + s), BEAT * 0.48))
    buf /= np.max(np.abs(buf)) * 1.15
    out = ROOT / "assets" / "audio" / "menu_music.ogg"
    with tempfile.TemporaryDirectory() as d:
        w = pathlib.Path(d) / "m.wav"
        with wave.open(str(w), "wb") as f:
            f.setnchannels(1)
            f.setsampwidth(2)
            f.setframerate(RATE)
            f.writeframes((buf * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(w), "-c:a", "libvorbis", "-q:a", "3", str(out)], check=True)
    print(out, out.stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()

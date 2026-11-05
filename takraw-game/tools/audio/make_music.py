#!/usr/bin/env python3
"""Make the match drums (assets/audio/drums_loop.ogg) and, with --menu, the game's own menu music (menu_music.ogg).
The menus play a recorded piece since 0.8.0 (docs/SOUNDS.md); --menu puts this one back.

The music is a loop in the spirit of a Thai piphat or Malay gamelan ensemble, all synthesised: a ranat (wooden
xylophone) melody on a five-note scale over a gong cycle, small kong wong gong chimes, ching cymbals on the beat and
a klong drum. The drums are the crowd's: the steady klong and thon beat a takraw crowd plays through a match.

Usage: python3 tools/audio/make_music.py [--menu]   (needs numpy and ffmpeg with libvorbis)
"""
import pathlib
import subprocess
import sys
import tempfile
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio"
RATE = 44100
BPM = 112
BEAT = 60.0 / BPM
rng = np.random.default_rng(7)

# A Thai-style seven-tone scale played pentatonically: C D E G A, over two octaves.
SCALE = [261.6, 293.7, 329.6, 392.0, 440.0, 523.3, 587.3, 659.3, 784.0, 880.0]


def env(n, attack, decay):
    t = np.arange(n) / RATE
    return np.minimum(1.0, t / attack) * np.exp(-t / decay)


def ranat(freq, dur):
    """A struck wooden bar: a strong fundamental, an inharmonic overtone at ~3.9x, a quick decay."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    s = np.sin(2 * np.pi * freq * t) * env(n, 0.002, 0.22)
    s += 0.35 * np.sin(2 * np.pi * freq * 3.93 * t) * env(n, 0.001, 0.05)
    s += 0.15 * np.sin(2 * np.pi * freq * 2.0 * t) * env(n, 0.002, 0.12)
    return s


def gong(freq, dur, decay=1.6):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    s = np.zeros(n)
    for k, a in [(1.0, 1.0), (2.01, 0.45), (2.76, 0.25), (5.4, 0.08)]:
        s += a * np.sin(2 * np.pi * freq * k * t + 0.3 * np.sin(2 * np.pi * 3.1 * t))
    return s * env(n, 0.01, decay)


def ching(dur=0.4):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    s = np.sin(2 * np.pi * 3520 * t) + 0.6 * np.sin(2 * np.pi * 5230 * t) + 0.4 * rng.uniform(-1, 1, n)
    return s * env(n, 0.001, 0.09) * 0.25


def drum(freq0, freq1, dur, decay, noise=0.2):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    f = freq1 + (freq0 - freq1) * np.exp(-t / 0.05)
    phase = 2 * np.pi * np.cumsum(f) / RATE
    s = np.sin(phase) * env(n, 0.002, decay)
    s += noise * rng.uniform(-1, 1, n) * env(n, 0.001, 0.02)
    return s


def put(buf, at, sound, gain):
    i = int(at * RATE)
    j = min(len(buf), i + len(sound))
    if i < len(buf):
        buf[i:j] += sound[: j - i] * gain


def write_ogg(name, samples, quality=4):
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
    bars = 8
    dur = bars * 4 * BEAT
    buf = np.zeros(int(dur * RATE) + RATE * 3)
    # The melody: two phrases of eighth notes, answered.
    phrase_a = [4, 5, 7, 5, 4, 3, 4, 2, 3, 4, 5, 4, 3, 2, 0, 2]
    phrase_b = [5, 7, 8, 7, 5, 4, 5, 7, 4, 3, 2, 3, 4, 2, 1, 0]
    melody = phrase_a + phrase_b + phrase_a + [5, 7, 8, 9, 8, 7, 5, 4, 3, 4, 2, 1, 2, 1, 0, 0]
    for i, deg in enumerate(melody):
        at = i * BEAT / 2
        put(buf, at, ranat(SCALE[deg], 0.6), 0.32)
        if i % 4 == 2:
            put(buf, at, ranat(SCALE[deg] * 2, 0.4), 0.08)
    # Kong wong: the skeleton melody on the beat, an octave down.
    for b in range(bars * 4):
        deg = melody[b * 2] if b * 2 < len(melody) else 0
        put(buf, b * BEAT, gong(SCALE[deg] / 2, 1.2, 0.5), 0.12)
    # The big gong at each four-bar cycle, the ching on every beat (open on 2 and 4).
    for c in range(0, bars, 4):
        put(buf, c * 4 * BEAT, gong(98.0, 3.0), 0.35)
    for b in range(bars * 4):
        put(buf, b * BEAT, ching(0.5 if b % 2 else 0.25), 0.5 if b % 2 else 0.3)
    # Klong: low on 1, slaps on the off-beats.
    for b in range(bars * 4):
        put(buf, b * BEAT, drum(140, 70, 0.5, 0.18), 0.4 if b % 4 == 0 else 0.22)
        put(buf, b * BEAT + BEAT * 0.75, drum(330, 220, 0.2, 0.05, 0.4), 0.14)
    # Fold the tail back onto the start so the loop is seamless.
    n = int(dur * RATE)
    tail = buf[n:]
    buf[: len(tail)] += tail
    write_ogg("menu_music.ogg", buf[:n])


def drums():
    bars = 2
    dur = bars * 4 * BEAT
    buf = np.zeros(int(dur * RATE) + RATE)
    for b in range(bars * 4):
        put(buf, b * BEAT, drum(120, 60, 0.6, 0.22, 0.25), 0.6)
        put(buf, b * BEAT + BEAT / 2, drum(260, 180, 0.25, 0.06, 0.5), 0.3)
        if b % 2:
            put(buf, b * BEAT + BEAT * 0.75, drum(260, 180, 0.25, 0.06, 0.5), 0.22)
        put(buf, b * BEAT, ching(0.3), 0.25)
    n = int(dur * RATE)
    tail = buf[n:]
    buf[: len(tail)] += tail
    write_ogg("drums_loop.ogg", buf[:n], 3)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    if "--menu" in sys.argv:
        music()
    drums()

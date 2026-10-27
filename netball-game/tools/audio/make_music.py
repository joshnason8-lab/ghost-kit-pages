#!/usr/bin/env python3
"""Make the menus' music: assets/audio/menu_music.ogg, a seamless loop.

Bright and quick, after the music netball's crowds bring to a court across southern Africa and the Pacific: an
mbira-like plucked ostinato interlocking in two parts on a major pentatonic scale, a marimba bass, a shaker on the
off-beats, hand claps on two and four and a soft kick. All synthesised: no samples, nothing licensed.

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
BPM = 116
BEAT = 60.0 / BPM
BARS = 16
rng = np.random.default_rng(11)

# G major pentatonic: G A B D E, over three octaves.
SCALE = [196.0, 220.0, 246.9, 293.7, 329.6, 392.0, 440.0, 493.9, 587.3, 659.3, 784.0, 880.0]


def env(n, attack, decay):
    t = np.arange(n) / RATE
    return np.minimum(1.0, t / attack) * np.exp(-t / decay)


def pluck(freq, dur, bright=1.0):
    """An mbira tine: a bright attack with a buzz, a ringing fundamental."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    s = np.sin(2 * np.pi * freq * t) * env(n, 0.002, 0.35)
    s += 0.28 * bright * np.sin(2 * np.pi * freq * 5.4 * t) * env(n, 0.001, 0.03)
    s += 0.12 * np.sin(2 * np.pi * freq * 2.01 * t) * env(n, 0.002, 0.2)
    return s


def marimba(freq, dur):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    return (np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 4.0 * t) * env(n, 0.001, 0.04)) * env(n, 0.003, 0.3)


def noise(dur, decay, smooth=0.0):
    n = int(dur * RATE)
    w = rng.uniform(-1, 1, n)
    if smooth > 0:
        w = np.convolve(w, np.ones(int(smooth)) / smooth, mode="same")
    return w * env(n, 0.001, decay)


def kick(dur=0.3):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    f = 110 * np.exp(-t * 18) + 45
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(n, 0.001, 0.12)


def add(buf, at, s, vol):
    i = int(at * RATE) % len(buf)
    end = i + len(s)
    if end <= len(buf):
        buf[i:end] += s * vol
    else:
        k = len(buf) - i
        buf[i:] += s[:k] * vol
        buf[: end - len(buf)] += s[k:] * vol   # wraps round: the loop is seamless


def main() -> None:
    total = BARS * 4 * BEAT
    buf = np.zeros(int(total * RATE))
    # Two interlocking mbira lines (the "kushaura" lead and the "kutsinhira" answer an eighth later).
    lead = [4, 6, 5, 7, 6, 4, 5, 3]
    answer = [2, 3, 1, 2, 4, 3, 2, 0]
    chords = [0, 0, 3, 3, 4, 4, 1, 1]   # a bar each, over the bass
    for bar in range(BARS):
        shift = chords[bar % 8]
        for e in range(8):
            t = (bar * 4 + e * 0.5) * BEAT
            add(buf, t, pluck(SCALE[(lead[e] + shift) % 12], 0.7), 0.22)
            add(buf, t + 0.25 * BEAT, pluck(SCALE[(answer[e] + shift) % 12 + 0] * 0.5, 0.6, 0.6), 0.16)
        # Marimba bass on one and the and of two.
        root = SCALE[shift % 5] * 0.5
        add(buf, bar * 4 * BEAT, marimba(root, 0.6), 0.3)
        add(buf, (bar * 4 + 1.5) * BEAT, marimba(root * 1.5, 0.5), 0.22)
        add(buf, (bar * 4 + 3) * BEAT, marimba(root, 0.5), 0.24)
        for b in range(4):
            t = (bar * 4 + b) * BEAT
            if bar >= 2:
                add(buf, t, kick(), 0.35 if b in (0, 2) else 0.18)
            add(buf, t + 0.5 * BEAT, noise(0.08, 0.025, 2), 0.09)          # shaker
            add(buf, t + 0.25 * BEAT, noise(0.05, 0.015, 2), 0.04)
            add(buf, t + 0.75 * BEAT, noise(0.05, 0.015, 2), 0.04)
            if b in (1, 3) and bar >= 4:
                add(buf, t, noise(0.12, 0.04, 4), 0.16)                  # claps
    buf /= np.max(np.abs(buf)) * 1.15
    pcm = (buf * 32767).astype(np.int16)
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as d:
        wav = pathlib.Path(d) / "m.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "3",
                        str(OUT / "menu_music.ogg")], check=True)
    print(OUT / "menu_music.ogg", round(total, 1), "s")


if __name__ == "__main__":
    main()

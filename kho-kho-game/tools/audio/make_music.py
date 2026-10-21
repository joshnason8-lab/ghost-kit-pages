#!/usr/bin/env python3
"""Make the menus' music and the crowd's drums: assets/audio/menu_music.ogg and drums_loop.ogg.

The music is a loop in the spirit of a village match's band: a bansuri (bamboo flute) melody in raag Bhupali (the
five notes Sa Re Ga Pa Dha) over a harmonium's drone on Sa and Pa, with the dhol and the dholki playing keherwa,
the eight-beat cycle of folk and film songs (dha ge na ti | na ka dhi na). The drums are the crowd's: a dhol and a
thali (a brass plate) beating time, louder as the chase builds. All synthesised.

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
BPM = 104
BEAT = 60.0 / BPM
rng = np.random.default_rng(7)

# Bhupali on Sa = D4: Sa Re Ga Pa Dha, over two octaves.
SA = 293.7
SCALE = [SA * r for r in (1.0, 9 / 8, 5 / 4, 3 / 2, 5 / 3, 2.0, 9 / 4, 5 / 2, 3.0, 10 / 3)]


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


def bansuri(freq, dur):
    """A bamboo flute: a breathy sine with a slow vibrato, a soft attack and a little second harmonic."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(1.0, t / 0.25)
    phase = 2 * np.pi * np.cumsum(freq * vib) / RATE
    s = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.05 * np.sin(3 * phase)
    breath = rng.uniform(-1, 1, n) * 0.06
    a = np.minimum(1.0, t / 0.06) * np.minimum(1.0, (dur - t) / 0.08).clip(0, 1)
    return (s + breath) * a


def harmonium(freq, dur):
    """A reed drone: odd and even partials, a slow swell."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    s = np.zeros(n)
    for k, amp in [(1, 1.0), (2, 0.6), (3, 0.4), (4, 0.25), (5, 0.15), (6, 0.1)]:
        s += amp * np.sign(np.sin(2 * np.pi * freq * k * t)) * 0.2 + amp * np.sin(2 * np.pi * freq * k * t)
    return s * np.minimum(1.0, t / 0.4) * np.minimum(1.0, (dur - t) / 0.4).clip(0, 1)


def thali(dur=0.3):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    s = np.sin(2 * np.pi * 2350 * t) + 0.7 * np.sin(2 * np.pi * 3810 * t) + 0.3 * rng.uniform(-1, 1, n)
    return s * env(n, 0.001, 0.07) * 0.3


def keherwa(buf, start, bars, gain=1.0):
    """Keherwa on the dhol (bass, dha) and dholki (treble): dha ge na ti | na ka dhi na, eighth notes."""
    bols = ["dha", "ge", "na", "ti", "na", "ka", "dhi", "na"]
    for bar in range(bars):
        for i, bol in enumerate(bols):
            at = start + (bar * 8 + i) * BEAT / 2
            if bol in ("dha", "ge", "dhi"):
                put(buf, at, drum(110, 55, 0.5, 0.2, 0.2), (0.5 if bol == "dha" else 0.3) * gain)
            if bol in ("dha", "na", "ti", "dhi", "ka"):
                put(buf, at, drum(420, 300, 0.2, 0.05, 0.45), (0.22 if bol != "ka" else 0.12) * gain)


def music():
    bars = 8
    dur = bars * 4 * BEAT
    buf = np.zeros(int(dur * RATE) + RATE * 3)
    # The melody: the raag's phrases, answered (degrees of SCALE; -1 holds the note before).
    a = [0, 1, 2, -1, 3, 2, 1, 0, 2, 3, 4, -1, 3, 2, 1, 2]
    b = [5, -1, 4, 3, 4, 5, 6, 5, 4, 3, 2, 3, 2, 1, 0, -1]
    melody = a + b + a + [3, 4, 5, 6, 7, 6, 5, 4, 3, 2, 1, 2, 1, 0, -1, -1]
    i = 0
    while i < len(melody):
        deg = melody[i]
        length = 1
        while i + length < len(melody) and melody[i + length] == -1:
            length += 1
        if deg >= 0:
            put(buf, i * BEAT / 2, bansuri(SCALE[deg] * 2, length * BEAT / 2 + 0.05), 0.3)
        i += length
    # The harmonium's drone, Sa and Pa, through each four-bar cycle.
    for c in range(0, bars, 4):
        put(buf, c * 4 * BEAT, harmonium(SA / 2, 4 * 4 * BEAT + 0.3), 0.07)
        put(buf, c * 4 * BEAT, harmonium(SA * 3 / 4, 4 * 4 * BEAT + 0.3), 0.04)
    keherwa(buf, 0.0, bars)
    for bt in range(bars * 4):
        if bt % 2 == 1:
            put(buf, bt * BEAT, thali(0.25), 0.18)
    # Fold the tail back onto the start so the loop is seamless.
    n = int(dur * RATE)
    tail = buf[n:]
    buf[: len(tail)] += tail
    write_ogg("menu_music.ogg", buf[:n])


def drums():
    bars = 2
    dur = bars * 4 * BEAT
    buf = np.zeros(int(dur * RATE) + RATE)
    keherwa(buf, 0.0, bars * 1, 1.0)
    for bt in range(bars * 4):
        put(buf, bt * BEAT, thali(0.3), 0.3)
    n = int(dur * RATE)
    tail = buf[n:]
    buf[: len(tail)] += tail
    write_ogg("drums_loop.ogg", buf[:n], 3)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    music()
    drums()

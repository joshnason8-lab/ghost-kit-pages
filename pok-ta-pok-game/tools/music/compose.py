#!/usr/bin/env python3
"""The menus' music: an original piece in the manner of the flute-and-drum music of north-west Mexico and the old
Mesoamerican instruments: a cane flute (carrizo) on a five-note scale, a frame drum (tambor) keeping a steady pulse,
a two-tongued slit drum (teponaztli) and seed rattles (ayoyotes). Not a transcription of any traditional or sacred
melody: the tune is the game's own. Everything is synthesised here, so there is nothing to license.

  python3 tools/music/compose.py            -> assets/audio/menu_music.ogg (a seamless loop; needs ffmpeg)
"""
import pathlib
import subprocess
import sys
import tempfile
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
SR = 32000
BPM = 92.0
BEAT = 60.0 / BPM
BARS = 32
LEN = int(round(BARS * 4 * BEAT * SR))
rng = np.random.default_rng(7)
out = np.zeros(LEN + SR * 4)


def put(sig, t, gain=1.0):
    i = max(0, int(round(t * SR)))
    n = min(len(sig), len(out) - i)
    if n > 0:
        out[i:i + n] += sig[:n] * gain


def env(n, a, d):
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-t / d)
    return e


def drum(accent=1.0):
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    f = 68.0 + 50.0 * np.exp(-t / 0.03)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t / 0.22) + 0.35 * np.sin(ph * 1.6) * np.exp(-t / 0.08)
    slap = rng.standard_normal(n) * np.exp(-t / 0.012) * 0.35
    return (body + slap) * accent


def tepo(freq, accent=1.0):
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.16) + 0.4 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t / 0.035)
    s += rng.standard_normal(n) * np.exp(-t / 0.004) * 0.3
    return s * accent * 0.55


def rattle(length=0.12, accent=1.0):
    n = int(length * SR)
    t = np.arange(n) / SR
    nz = rng.standard_normal(n)
    # Seeds: many small clicks, bright.
    nz = np.diff(np.concatenate([[0.0], nz]))
    grains = (rng.random(n) < 0.08) * rng.standard_normal(n) * 2.0
    e = np.minimum(1.0, t / 0.01) * np.exp(-t / (length * 0.45))
    return (nz * 0.25 + grains * 0.4) * e * accent * 0.35


def flute(freq, dur, accent=1.0, slide=0.0):
    n = int((dur + 0.25) * SR)
    t = np.arange(n) / SR
    vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(1.0, t / 0.35)
    bend = 1.0 + slide * np.exp(-t / 0.06)
    f = freq * vib * bend
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.28 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph) + 0.05 * np.sin(4 * ph)
    breath = rng.standard_normal(n)
    breath = np.convolve(breath, np.ones(6) / 6, mode="same") * 0.12
    a = np.minimum(1.0, t / 0.05)
    r = np.clip((dur + 0.25 - t) / 0.25, 0.0, 1.0)
    shape = a * r * (0.85 + 0.15 * np.exp(-t / 0.15))
    return (tone + breath * (0.6 + 0.4 * np.exp(-t / 0.1))) * shape * accent * 0.32


# D minor pentatonic, the flute's range.
NOTES = {"D4": 293.66, "F4": 349.23, "G4": 392.0, "A4": 440.0, "C5": 523.25, "D5": 587.33, "F5": 698.46, "G5": 783.99,
         "A5": 880.0, "C4": 261.63, "A3": 220.0}
# Phrases: (note, beats). Short motifs repeated with turns, as the flute-and-drum players do.
A = [("A4", 1), ("C5", 0.5), ("A4", 0.5), ("G4", 1), ("F4", 1), ("G4", 1.5), ("A4", 0.5), ("D4", 2),
     ("A4", 1), ("C5", 0.5), ("D5", 0.5), ("C5", 1), ("A4", 1), ("G4", 1), ("F4", 1), ("G4", 2)]
A2 = [("A4", 1), ("C5", 0.5), ("A4", 0.5), ("G4", 1), ("F4", 1), ("G4", 1.5), ("A4", 0.5), ("D4", 2),
      ("F4", 1), ("G4", 0.5), ("A4", 0.5), ("C5", 1), ("A4", 1), ("G4", 0.5), ("F4", 0.5), ("D4", 3)]
B = [("D5", 1.5), ("C5", 0.5), ("D5", 1), ("F5", 1), ("D5", 1), ("C5", 1), ("A4", 2),
     ("C5", 1), ("D5", 0.5), ("C5", 0.5), ("A4", 1), ("G4", 1), ("A4", 1.5), ("G4", 0.5), ("F4", 2)]
B2 = [("D5", 1.5), ("F5", 0.5), ("G5", 1), ("F5", 1), ("D5", 1), ("C5", 1), ("A4", 2),
      ("G4", 1), ("A4", 0.5), ("C5", 0.5), ("A4", 1), ("G4", 1), ("F4", 1), ("G4", 1), ("D4", 2)]


def play(phrase, bar, gain=1.0):
    t = bar * 4 * BEAT
    for k, (n, b) in enumerate(phrase):
        slide = -0.04 if k == 0 or b >= 1.5 else 0.0
        put(flute(NOTES[n], b * BEAT * 0.94, 1.0 if b >= 1 else 0.85, slide), t, gain)
        t += b * BEAT


# The form: drum and rattles alone; the flute's theme; the slit drum joins; the high answer; a break; the theme again.
for bar in range(BARS):
    t0 = bar * 4 * BEAT
    brk = 20 <= bar < 22
    for b8 in range(8):
        t = t0 + b8 * BEAT * 0.5
        if not brk or b8 % 4 == 0:
            acc = 1.0 if b8 % 2 == 0 else 0.55
            if b8 in (0, 3, 6):
                acc *= 1.15
            put(drum(acc), t + rng.normal(0, 0.003), 0.4)
        if bar >= 2 and not brk:
            put(rattle(0.1 if b8 % 2 else 0.16, 0.9 if b8 % 2 == 0 else 0.6), t + 0.01 + rng.normal(0, 0.004), 1.0)
    if bar >= 6 and not brk:
        # Teponaztli: its two tongues, a fifth apart, on a figure of three against the drum's four.
        for k, (beat, f) in enumerate([(0, 146.8), (1.5, 220.0), (3, 146.8)]):
            put(tepo(f, 1.0 if k == 0 else 0.75), t0 + beat * BEAT, 0.9)
    if brk:
        for k, beat in enumerate([0, 0.75, 1.5, 2.5, 3.0]):
            put(tepo(220.0 if k % 2 else 146.8, 0.9), t0 + beat * BEAT, 0.9)

for bar, ph in [(4, A), (8, A2), (12, B), (16, B2), (22, A), (26, A2)]:
    play(ph, bar)



# Close the loop: what rings past the end comes back in at the start.
tail = out[LEN:]
out[:len(tail)] += tail
song = out[:LEN]

# A little room: a short decaying noise tail, by FFT convolution.
ir_n = int(1.2 * SR)
ir_t = np.arange(ir_n) / SR
ir = rng.standard_normal(ir_n) * np.exp(-ir_t / 0.32) * 0.05
ir[0] = 1.0
L = 1 << int(np.ceil(np.log2(LEN + ir_n)))
wet = np.fft.irfft(np.fft.rfft(np.concatenate([song, song[:ir_n]]), L) * np.fft.rfft(ir, L), L)[:LEN + ir_n]
mix = wet[:LEN].copy()
mix[:ir_n] += wet[LEN:LEN + ir_n] - wet[:ir_n] * 0.0   # the tail of the loop's end spills into its start
mix = mix / np.max(np.abs(mix)) * 0.85

dst = ROOT / "assets" / "audio" / "menu_music.ogg"
with tempfile.TemporaryDirectory() as d:
    w = pathlib.Path(d) / "m.wav"
    with wave.open(str(w), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes((mix * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(w), "-c:a", "libvorbis", "-q:a", "3", str(dst)], check=True)
print("wrote %s: %.1f s, %d KB" % (dst.relative_to(ROOT), LEN / SR, dst.stat().st_size // 1024))

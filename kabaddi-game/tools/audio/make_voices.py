#!/usr/bin/env python3
"""Make the raider's chant and the players' shouts in assets/audio/.

Placeholders until real recordings arrive: drop a recording with the same name over any of
these and the game uses it instead. The best replacement is a real raider chanting
"kabaddi, kabaddi" and real shouts from a club session.

Voices are the MBROLA Indian diphone voices (in1 male, in2 female) driven by espeak-ng with
Hindi text, which sound far more natural than espeak's own formant voice. Each line is
rendered at a few pitches and speeds, then given a little room, a gentle compressor and
(for shouts) some grit.

Needs: python3 with numpy and scipy, espeak-ng with mbrola, mbrola-in1, ffmpeg.
    apt-get install espeak-ng mbrola mbrola-in1 mbrola-in2
    python3 tools/audio/make_voices.py
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
rng = np.random.default_rng(5)


def say(text, voice="mb-in1", speed=170, pitch=45, amp=120, gap=0):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    cmd = ["espeak-ng", "-v", voice, "-s", str(speed), "-p", str(pitch), "-a", str(amp), "-g", str(gap), "-w", path, text]
    subprocess.run(cmd, check=True, capture_output=True)
    with wave.open(path) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
    os.unlink(path)
    if sr != RATE:
        x = signal.resample_poly(x, RATE, sr)
    return trim(x)


def trim(x, thresh=0.01):
    idx = np.where(np.abs(x) > thresh)[0]
    if len(idx) == 0:
        return x
    a = max(0, idx[0] - int(0.01 * RATE))
    b = min(len(x), idx[-1] + int(0.03 * RATE))
    return x[a:b]


def shift(x, semitones):
    """Pitch and speed together (like a tape), for a different-sounding person."""
    k = 2 ** (semitones / 12.0)
    n = int(len(x) / k)
    return signal.resample(x, n)


def room(x, size=0.18, wet=0.12):
    n = int(size * RATE)
    t = np.arange(n) / RATE
    ir = rng.standard_normal(n) * np.exp(-t / (size / 5))
    ir[0] = 0
    ir = signal.lfilter(*signal.butter(2, 3500 / (RATE / 2), "low"), ir)
    ir /= np.sum(np.abs(ir)) + 1e-9
    y = np.convolve(x, ir)[: len(x) + n // 2]
    dry = np.concatenate([x, np.zeros(len(y) - len(x))])
    return dry * (1 - wet) + y * wet * 6


def compress(x, drive=1.6):
    return np.tanh(x * drive) / np.tanh(drive)


def tone(x):
    b, a = signal.butter(2, 90 / (RATE / 2), "high")
    x = signal.lfilter(b, a, x)
    # A little presence, so the voice cuts through the crowd.
    b, a = signal.butter(2, [1800 / (RATE / 2), 4200 / (RATE / 2)], "band")
    return x + signal.lfilter(b, a, x) * 0.35


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def fade(x, a=0.005, r=0.04):
    env = np.ones(len(x))
    na, nr = int(a * RATE), int(r * RATE)
    env[:na] = np.linspace(0, 1, na)
    env[-nr:] *= np.linspace(1, 0, nr)
    return x * env


def save(name, x, q=4):
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
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), path], check=True)
    os.unlink(tmp)
    print("wrote", path, "%.2f s" % (len(x) / RATE))


def finish(x, grit=1.4, wet=0.1):
    return norm(fade(room(compress(tone(norm(x)), grit), wet=wet)), 0.92)


# ---------------------------------------------------------------- the cant

def chant_word(variant):
    """One "kabaddi", quick and low, as a raider says it on one breath."""
    p = [(205, 38, 0.0), (215, 44, -0.6)][variant]
    x = say("कबड्डी", "mb-in1", speed=p[0], pitch=p[1])
    x = shift(x, p[2])
    return finish(x, 1.5, 0.08)


def chant_run():
    """The cant as one run: kabaddi, kabaddi, kabaddi..., getting a little breathless."""
    words = []
    for i in range(7):
        w = say("कबड्डी", "mb-in1", speed=200 + i * 4, pitch=40 + (i % 2) * 4)
        w = shift(w, -0.3 * (i % 3))
        words.append(w * (1.0 - i * 0.04))
        words.append(np.zeros(int(0.03 * RATE)))
    return finish(np.concatenate(words), 1.5, 0.08)


def crowd_chant():
    """A stand chanting "kabaddi! kabaddi!" with claps on the beat."""
    beat = 0.62
    bars = 6
    n = int((beat * 2 * bars + 1.0) * RATE)
    out = np.zeros(n)
    for v in range(18):
        voice = "mb-in1" if v % 3 else "mb-in2"
        w = say("कबड्डी", voice, speed=int(rng.uniform(170, 200)), pitch=int(rng.uniform(30, 70)))
        w = shift(w, rng.uniform(-2.5, 2.5)) * rng.uniform(0.4, 1.0)
        for b in range(bars):
            start = int((0.05 + b * 2 * beat + rng.uniform(-0.03, 0.05)) * RATE)
            end = min(n, start + len(w))
            out[start:end] += w[: end - start]
    # Claps on the off-beat.
    for b in range(bars * 2):
        t0 = int((0.05 + b * beat + beat * 0.5) * RATE)
        for c in range(25):
            o = t0 + int(rng.uniform(-0.02, 0.02) * RATE)
            k = int(0.03 * RATE)
            burst = rng.standard_normal(k) * np.exp(-np.arange(k) / (0.004 * RATE)) * rng.uniform(0.1, 0.25)
            out[o:o + k] += burst[: max(0, min(k, n - o))]
    b, a = signal.butter(4, 3500 / (RATE / 2), "low")
    out = signal.lfilter(b, a, out)
    return norm(fade(room(out, 0.6, 0.35), 0.05, 0.6), 0.85)


# ---------------------------------------------------------------- shouts

SHOUTS = {
    "yell_pakad": ("पकड़!", "mb-in1", 190, 70),
    "yell_aaja": ("आजा!", "mb-in1", 170, 62),
    "yell_haan": ("हाँ!", "mb-in1", 180, 75),
    "yell_shabash": ("शाबाश!", "mb-in1", 175, 72),
    "yell_chal": ("चल!", "mb-in1", 185, 68),
    "yell_touch": ("टच था!", "mb-in1", 185, 70),
    "yell_nahi": ("नहीं!", "mb-in1", 175, 66),
}


def shout(text, voice, speed, pitch):
    x = say(text, voice, speed=speed, pitch=pitch, amp=180)
    x = shift(x, 1.2)          # a raised, effortful voice
    return finish(x, 2.4, 0.14)


def main():
    if subprocess.run(["espeak-ng", "--voices=mb"], capture_output=True, text=True).stdout.find("mb-in1") < 0:
        sys.exit("needs the MBROLA Indian voices: apt-get install mbrola mbrola-in1 mbrola-in2")
    for i in range(2):
        save("chant_word_%d" % (i + 1), chant_word(i))
    save("chant_raider", chant_run())
    save("crowd_chant", crowd_chant(), 3)
    for name, (text, voice, speed, pitch) in SHOUTS.items():
        save(name, shout(text, voice, speed, pitch))


if __name__ == "__main__":
    main()

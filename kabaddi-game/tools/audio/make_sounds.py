#!/usr/bin/env python3
"""Make the crowd and player sounds in assets/audio/.

Placeholders until real recordings arrive: drop a recording with the same name over any of
these and the game uses it instead.

Crowd sounds are built from many synthetic voices (espeak-ng with varied voices, pitch and
speed) layered with random offsets, filtered and mixed with a noise bed, which reads as a
stadium murmur from a distance. Player grunts and gasps use a simple source-filter voice: a
jittered glottal pulse train through vowel formant resonators, plus breath noise.

Needs: python3 with numpy and scipy, espeak-ng, ffmpeg.
    python3 tools/audio/make_sounds.py            # writes assets/audio/*.ogg
"""
import os
import random
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

RATE = 22050
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "audio"))
rng = np.random.default_rng(11)
random.seed(11)

VARIANTS = ["m1", "m2", "m3", "m4", "m5", "m6", "m7", "f1", "f2", "f3", "f4", "f5"]
LANGS = ["hi", "mr", "ta", "te", "bn", "pa", "en-us"]
SYLLABLES = ["ka", "ba", "di", "ra", "jaa", "ho", "aa", "ye", "chal", "maar", "pakad", "bhai", "arre",
             "haan", "nahi", "shabash", "dekho", "jaldi", "wah", "le", "lo", "kya", "baat", "hai"]


# ---------------------------------------------------------------- helpers

def espeak(text, voice, pitch=50, speed=160, amp=100):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    subprocess.run(["espeak-ng", "-v", voice, "-p", str(pitch), "-s", str(speed), "-a", str(amp), "-w", path, text],
                   check=True, capture_output=True)
    with wave.open(path) as w:
        sr = w.getframerate()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
    os.unlink(path)
    if sr != RATE:
        data = signal.resample_poly(data, RATE, sr)
    return data


def voice_name():
    return "%s+%s" % (random.choice(LANGS), random.choice(VARIANTS))


def lowpass(x, hz, order=4):
    b, a = signal.butter(order, hz / (RATE / 2), "low")
    return signal.lfilter(b, a, x)


def highpass(x, hz, order=2):
    b, a = signal.butter(order, hz / (RATE / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (RATE / 2), hi / (RATE / 2)], "band")
    return signal.lfilter(b, a, x)


def pink(n):
    white = rng.standard_normal(n)
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    return signal.lfilter(b, a, white)


def add_at(buf, clip, start):
    if start >= len(buf):
        return
    end = min(len(buf), start + len(clip))
    buf[start:end] += clip[: end - start]


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def fade(x, a=0.01, r=0.05):
    n = len(x)
    env = np.ones(n)
    na, nr = int(a * RATE), int(r * RATE)
    if na:
        env[:na] = np.linspace(0, 1, na)
    if nr:
        env[-nr:] *= np.linspace(1, 0, nr)
    return x * env


def loopable(x, cross=0.6):
    """Crossfade the tail into the head so the clip loops without a click."""
    n = int(cross * RATE)
    w = np.linspace(0, 1, n)
    head = x[:n] * w + x[-n:] * (1 - w)
    return np.concatenate([head, x[n:-n]])


def save(name, x, quality=3):
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
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(quality), path],
                   check=True)
    os.unlink(tmp)
    print("wrote", path, "%.1f s" % (len(x) / RATE), "%d KB" % (os.path.getsize(path) // 1024))


# ---------------------------------------------------------------- crowd

def babble(dur, voices=70, words=(3, 9), speed=(140, 210), pitch=(25, 75)):
    """Many people talking at once, at a distance."""
    n = int(dur * RATE)
    out = np.zeros(n)
    for _ in range(voices):
        text = " ".join(random.choice(SYLLABLES) for _ in range(random.randint(*words)))
        clip = espeak(text, voice_name(), random.randint(*pitch), random.randint(*speed), random.randint(40, 100))
        clip *= rng.uniform(0.25, 1.0)
        # Repeat each talker through the clip with gaps.
        t = int(rng.uniform(-0.5, 1.0) * len(clip))
        while t < n:
            add_at(out, clip, max(0, t))
            t += len(clip) + int(rng.uniform(0.1, 1.5) * RATE)
    return out


def crowd_loop():
    dur = 14.0
    x = babble(dur + 0.6, voices=90)
    x = lowpass(x, 2600)
    x = norm(x, 0.6)
    bed = lowpass(pink(len(x)), 900)
    bed = norm(bed, 0.25)
    # Slow swells, the way a big crowd breathes.
    t = np.arange(len(x)) / RATE
    swell = 0.8 + 0.2 * np.sin(2 * np.pi * t / (dur + 0.6) * 3)
    y = (x + bed) * swell
    return norm(loopable(y), 0.75)


def vowel_crowd(dur, text, voices, pitch, speed, contour):
    n = int(dur * RATE)
    out = np.zeros(n)
    for _ in range(voices):
        clip = espeak(text, voice_name(), random.randint(*pitch), random.randint(*speed), random.randint(60, 120))
        clip *= rng.uniform(0.3, 1.0)
        add_at(out, clip, int(rng.uniform(0.0, 0.25) * RATE))
    t = np.arange(n) / RATE
    env = contour(t)
    noise = lowpass(pink(n), 1800) * 0.35
    return (lowpass(out, 3200) / max(1e-6, np.max(np.abs(out))) + norm(noise, 0.3)) * env


def crowd_cheer():
    dur = 3.4
    env = lambda t: np.clip(t / 0.25, 0, 1) * np.exp(-np.maximum(0, t - 0.6) * 1.1)
    x = vowel_crowd(dur, "aaaaaaaaaaay", 80, (45, 95), (60, 90), env)
    x += vowel_crowd(dur, "yeeeeeeeeeah hooo", 40, (50, 99), (70, 110), env) * 0.7
    return norm(fade(x, 0.02, 0.4), 0.9)


def crowd_ooh():
    dur = 2.0
    env = lambda t: np.sin(np.clip(t / dur, 0, 1) * np.pi) ** 0.7
    return norm(fade(vowel_crowd(dur, "oooooooooh", 70, (30, 70), (60, 90), env), 0.05, 0.3), 0.8)


def crowd_groan():
    dur = 2.0
    env = lambda t: np.clip(t / 0.15, 0, 1) * np.exp(-t * 1.0)
    return norm(fade(vowel_crowd(dur, "aaawwwww", 70, (10, 40), (55, 80), env), 0.03, 0.3), 0.8)


def one_clap(bright=1.0):
    n = int(0.06 * RATE)
    burst = rng.standard_normal(n)
    t = np.arange(n) / RATE
    # A few micro-transients, then a short room tail.
    env = np.zeros(n)
    for k in range(rng.integers(2, 4)):
        t0 = k * rng.uniform(0.002, 0.006)
        env += np.exp(-np.maximum(0, t - t0) * 260) * (t >= t0)
    c = bandpass(burst * env, 700 * bright, 3200 * bright)
    return c / (np.max(np.abs(c)) or 1)


def applause():
    dur = 3.5
    n = int(dur * RATE)
    out = np.zeros(n)
    t_env = lambda t: np.clip(t / 0.3, 0, 1) * np.exp(-np.maximum(0, t - 1.4) * 1.3)
    for _ in range(140):
        rate = rng.uniform(3.5, 6.0)
        t = rng.uniform(0, 0.3)
        b = rng.uniform(0.8, 1.3)
        g = rng.uniform(0.2, 1.0)
        while t < dur:
            add_at(out, one_clap(b) * g * t_env(t), int(t * RATE))
            t += 1.0 / rate * rng.uniform(0.9, 1.1)
    return norm(fade(lowpass(out, 6000), 0.01, 0.3), 0.8)


def hand_slap():
    """Two hands meeting: a high five."""
    x = one_clap(0.8) * 0.9 + one_clap(1.1) * 0.3
    return norm(np.concatenate([x, np.zeros(int(0.05 * RATE))]), 0.9)


# ---------------------------------------------------------------- player voices

FORMANTS = {
    "uh": [(640, 80), (1190, 90), (2390, 120)],
    "oo": [(350, 70), (900, 90), (2300, 130)],
    "aa": [(750, 90), (1250, 100), (2550, 140)],
    "eh": [(530, 80), (1850, 110), (2500, 140)],
    "hm": [(300, 60), (1000, 120), (2300, 160)],
}


def glottal(f0_curve):
    """Glottal pulse train following an f0 curve (Hz per sample), with jitter and shimmer."""
    n = len(f0_curve)
    out = np.zeros(n)
    phase = 0.0
    period_jit = 1.0
    for i in range(n):
        phase += f0_curve[i] * period_jit / RATE
        if phase >= 1.0:
            phase -= 1.0
            period_jit = 1.0 + rng.normal(0, 0.025)
        # Rosenberg-like pulse: open phase rises, closes sharply.
        p = phase
        out[i] = (0.5 - 0.5 * np.cos(np.pi * p / 0.6)) if p < 0.6 else np.cos(np.pi * (p - 0.6) / 0.8) if p < 1.0 else 0
    return np.diff(out, prepend=0) * (1 + rng.normal(0, 0.05, n))


def formant_filter(x, vowel, shift=1.0):
    y = np.zeros_like(x)
    for (f, bw), g in zip(FORMANTS[vowel], (1.0, 0.6, 0.3)):
        f *= shift
        r = np.exp(-np.pi * bw / RATE)
        theta = 2 * np.pi * f / RATE
        a = [1, -2 * r * np.cos(theta), r * r]
        y += signal.lfilter([1 - r], a, x) * g
    return y


def voice(dur, f0_start, f0_end, vowel, attack=0.015, release=0.08, breath=0.25, shift=1.0, rough=0.0):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    f0 = np.linspace(f0_start, f0_end, n) * (1 + rough * np.sin(2 * np.pi * 37 * t))
    src = glottal(f0)
    v = formant_filter(src, vowel, shift)
    v = v / (np.max(np.abs(v)) or 1)
    noise = bandpass(rng.standard_normal(n), 400, 5000)
    noise = noise / (np.max(np.abs(noise)) or 1)
    env = np.clip(t / attack, 0, 1) * np.clip((dur - t) / release, 0, 1)
    # Breath leads in and trails out around the voiced part.
    benv = np.exp(-((t - 0.0) / 0.04) ** 2) + np.exp(-((t - dur) / 0.09) ** 2) * 0.8 + 0.25
    return (v * env + noise * breath * benv * np.clip((dur - t) / release, 0, 1)) * 0.9


def grunt(i):
    """Effort: a dive, a lunge, pushing in a hold."""
    p = [(0.22, 125, 95, "uh", 0.3), (0.28, 140, 100, "hm", 0.25), (0.18, 150, 110, "aa", 0.35),
         (0.32, 115, 85, "uh", 0.2), (0.26, 165, 120, "eh", 0.3)][i]
    x = voice(p[0], p[1], p[2], p[3], attack=0.008, release=0.1, breath=p[4], shift=rng.uniform(0.92, 1.08), rough=0.04)
    return norm(fade(x, 0.002, 0.03), 0.85)


def oof(i):
    """The wind knocked out: landing hard, being tackled."""
    p = [(0.2, 175, 105, "oo"), (0.24, 160, 95, "uh"), (0.17, 190, 120, "oo")][i]
    x = voice(p[0], p[1], p[2], p[3], attack=0.004, release=0.09, breath=0.45, shift=rng.uniform(0.95, 1.05), rough=0.06)
    # A sharp push of air at the start.
    n = int(0.03 * RATE)
    x[:n] += bandpass(rng.standard_normal(n), 800, 4000) * np.linspace(1, 0, n) * 0.6
    return norm(fade(x, 0.001, 0.03), 0.85)


def exhale(i):
    """Breathing out hard after a raid."""
    dur = [0.55, 0.7][i]
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    x = bandpass(rng.standard_normal(n), 500, 3500)
    x = formant_filter(x, "aa" if i == 0 else "uh") * 0.5 + x * 0.2
    env = np.clip(t / 0.05, 0, 1) * np.exp(-t * 4.0)
    return norm(fade(x * env, 0.01, 0.1), 0.6)


def hup(i):
    """A short sharp call on a jump or a kick."""
    p = [(0.12, 210, 170, "uh"), (0.14, 190, 150, "aa")][i]
    x = voice(p[0], p[1], p[2], p[3], attack=0.004, release=0.05, breath=0.3)
    return norm(fade(x, 0.001, 0.02), 0.85)


def main():
    for tool in ("espeak-ng", "ffmpeg"):
        if subprocess.run(["which", tool], capture_output=True).returncode:
            sys.exit("needs %s" % tool)
    save("crowd_loop", crowd_loop(), 2)
    save("crowd_cheer", crowd_cheer())
    save("crowd_ooh", crowd_ooh())
    save("crowd_groan", crowd_groan())
    save("applause", applause())
    save("clap", hand_slap())
    for i in range(5):
        save("grunt_%d" % (i + 1), grunt(i))
    for i in range(3):
        save("oof_%d" % (i + 1), oof(i))
    for i in range(2):
        save("exhale_%d" % (i + 1), exhale(i))
        save("hup_%d" % (i + 1), hup(i))


if __name__ == "__main__":
    main()

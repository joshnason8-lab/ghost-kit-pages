#!/usr/bin/env python3
"""The raider's cant ("kabaddi, kabaddi...") in a natural voice: assets/audio/chant_word_1..2, chant_raider and
crowd_chant. They replace make_voices.py's MBROLA cant, which the owner found awkward (2026-11).

The voice is Piper's Telugu "venkatesh" (rhasspy/piper-voices, medium; trained by PravalX on AI4Bharat's
IndicVoices-R, CC BY 4.0). "కబడ్డీ" is the word as it is said across India. The single words the game plays at each
cant tap are said quickly with a comma after them (mid-cant, not falling as at a sentence's end); cut out of a run
instead, a cut fell inside a word ("come on, Dick"). With faster-whisper installed (pip install faster-whisper), each is
checked by speech recognition and only a take heard as "kabaddi" is kept.

Needs: pip install piper-tts numpy scipy; ffmpeg; the voice's two files in VOICE_DIR (downloaded if missing):
    https://huggingface.co/rhasspy/piper-voices/resolve/main/te/te_IN/venkatesh/medium/te_IN-venkatesh-medium.onnx(.json)
    python3 tools/audio/make_chant.py [voice_dir]
"""
import os
import subprocess
import sys
import tempfile
import urllib.request
import wave

import numpy as np
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_voices as mv   # noqa: E402  (room, compress, tone, norm, fade, save; its RATE is 22050, Piper's too)

VOICE = "te_IN-venkatesh-medium"
URL = "https://huggingface.co/rhasspy/piper-voices/resolve/main/te/te_IN/venkatesh/medium/"
WORD = "కబడ్డీ"
rng = np.random.default_rng(11)


def voice_path(d):
    os.makedirs(d, exist_ok=True)
    for ext in (".onnx", ".onnx.json"):
        p = os.path.join(d, VOICE + ext)
        if not os.path.exists(p):
            urllib.request.urlretrieve(URL + VOICE + ext, p)
    return os.path.join(d, VOICE + ".onnx")


def piper(model, text, length=0.7, noise=0.667, noise_w=0.8):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        out = f.name
    subprocess.run([sys.executable, "-m", "piper", "-m", model, "--length-scale", str(length), "--noise-scale", str(noise),
                    "--noise-w-scale", str(noise_w), "-f", out], input=text.encode("utf-8"), check=True,
                   capture_output=True)
    with wave.open(out) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
        assert w.getframerate() == mv.RATE
    os.unlink(out)
    return x


def trim(x, floor=0.02):
    a = np.abs(x)
    on = np.where(a > floor * a.max())[0]
    return x[max(0, on[0] - int(0.01 * mv.RATE)):on[-1] + int(0.02 * mv.RATE)] if len(on) else x


_asr = None


def heard(x):
    """What speech recognition hears in x (faster-whisper "small", English), or None without it."""
    global _asr
    try:
        from faster_whisper import WhisperModel
        from scipy.signal import resample_poly
    except ImportError:
        return None
    if _asr is None:
        _asr = WhisperModel("small", device="cpu", compute_type="int8")
    a = resample_poly(x, 16000, mv.RATE).astype(np.float32)
    a = np.concatenate([np.zeros(4000, np.float32), a, np.zeros(12000, np.float32)])
    segs, _ = _asr.transcribe(a, language="en")
    return " ".join(sg.text for sg in segs)


def ok(h):
    import re
    return re.search(r"\bkabb?add?i\b", h.lower()) is not None


def single(model, length, post=None):
    """One "kabaddi" said quickly, mid-cant (a comma after it: no fall as at a sentence's end). Piper's takes vary, so
    with speech recognition at hand the first it hears as "kabaddi" is kept (a few came out "cup of tea")."""
    best = None
    for _ in range(12):
        x = trim(piper(model, WORD + ",", length=length, noise=0.5))
        if post:
            x = post(x)
        h = heard(x)   # as it will sound in the game
        if h is None:
            return x
        print("  take:", h.strip())
        if ok(h):
            return x
        best = x
    return best


def finish(x, wet=0.06):
    return mv.norm(mv.fade(mv.room(mv.compress(mv.tone(mv.norm(x)), 1.3), wet=wet), 0.004, 0.03), 0.92)


def main():
    model = voice_path(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, ".piper"))
    # The two single words the game plays at each cant tap: one quicker, one a shade lower.
    mv.save("chant_word_1", single(model, 0.65, finish))
    mv.save("chant_word_2", single(model, 0.75, lambda x: finish(mv.shift(x, -0.5))))
    # The cant as one run, a little quicker and more breathless as it goes.
    run2 = piper(model, " ".join([WORD] * 7), length=0.68, noise_w=0.9)
    mv.save("chant_raider", finish(run2))
    # A stand chanting it, made again until it is heard as "kabaddi" (a mix of voices can blur into other words).
    for attempt in range(6):
        mix = crowd(model)
        h = heard(mix)
        print("  crowd:", h)
        if h is None or ok(h):
            break
    mv.save("crowd_chant", mix, 3)


def crowd(model):
    """A stand chanting it: one word said again and again, each voice at its own pitch and a moment early or late,
    with claps on the off-beat."""
    beat, bars = 0.62, 6
    n = int((beat * 2 * bars + 1.0) * mv.RATE)
    out = np.zeros(n)
    for v in range(16):
        w = single(model, rng.uniform(0.75, 0.95))
        w = mv.shift(w, rng.uniform(-3.0, 2.0)) * rng.uniform(0.4, 1.0)
        for b in range(bars):
            s = int((0.05 + b * 2 * beat + rng.uniform(-0.03, 0.05)) * mv.RATE)
            e = min(n, s + len(w))
            out[s:e] += w[:e - s]
    for b in range(bars * 2):
        t0 = int((0.05 + b * beat + beat * 0.5) * mv.RATE)
        for c in range(25):
            o = t0 + int(rng.uniform(-0.02, 0.02) * mv.RATE)
            k = int(0.03 * mv.RATE)
            burst = rng.standard_normal(k) * np.exp(-np.arange(k) / (0.004 * mv.RATE)) * rng.uniform(0.1, 0.25)
            out[o:o + k] += burst[:max(0, min(k, n - o))]
    b, a = signal.butter(4, 3500 / (mv.RATE / 2), "low")
    out = signal.lfilter(b, a, out)
    return mv.norm(mv.fade(mv.room(out, 0.6, 0.35), 0.05, 0.6), 0.85)


if __name__ == "__main__":
    main()

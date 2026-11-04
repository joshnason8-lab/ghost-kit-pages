#!/usr/bin/env python3
"""The richer sounds Medium and High play (assets/audio/hd/): the venues' beds as long stereo loops (a minute and
more, so the crowd does not repeat every 16 seconds), and more takes of the crowd's cheers, applause, "ooh" and groan
(each reaction picks one at random). Low keeps the set in assets/audio/ (tools/audio/make_sounds.py) unchanged.

The downloads are not kept in the repository. Fetch each source named in SOURCES into its own folder under SRC (the
folder names are the keys below; unzip the cheering pack into oga_cheer/x/), then run from netball-game/:

    python3 -I tools/audio/make_sounds_hd.py SRC

Needs numpy and ffmpeg with libvorbis. Stereo Ogg Vorbis at 44.1 kHz. Each take is set to the loudness of the Low
sound it stands beside (the loudest 100 ms above 120 Hz, as make_sounds.py measures it), each bed to the Low bed's
average level, so the mix is as it was, only richer. Credits: docs/SOUNDS.md and the Licences screen.
"""
import pathlib
import subprocess
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio" / "hd"
LOW = ROOT / "assets" / "audio"
RATE = 44100
rng = np.random.default_rng(11)

# Download folder -> where it came from (authors and licences in docs/SOUNDS.md).
SOURCES = {
    "oga_cheer": "https://opengameart.org/content/free-crowd-cheering-sounds (Gregor Quendel, CC-BY 4.0; the MP3 zip)",
    "oga_gq_amb": "https://opengameart.org/content/free-general-ambience-sounds (Gregor Quendel, CC-BY-SA 4.0): "
                  "crowd_-_applause_-_clapping.mp3, crowd_-_school_excursion.mp3, "
                  "city_ambience_-_park_-_spring_-_with_birds_cars_and_planes.mp3",
    "oga_hallapplause": "https://opengameart.org/content/applause-in-a-large-hall-or-church (eXpl0it3r, CC0): "
                        "applause-clapping-church-crowd-immersive.wav",
    "oga_applause": "https://opengameart.org/content/applause (leezh, from Yo Frankie!; CC-BY 3.0): applause.wav",
}

SRC = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(".")
CHEER = "oga_cheer/x/Gregor Quendel - Free Crowd Cheering Sounds - MP3/Gregor Quendel - Crowd Cheering Sounds - %s.mp3"
FULL = CHEER % "11 - Full recording"
GQ = "oga_gq_amb/"


def load(rel, start=0.0, dur=None, base=None):
    cmd = ["ffmpeg", "-v", "error", "-ss", str(start)]
    if dur:
        cmd += ["-t", str(dur)]
    cmd += ["-i", str((base or SRC) / rel), "-ac", "2", "-ar", str(RATE), "-f", "f32le", "-"]
    x = np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, dtype=np.float32).astype(np.float64)
    return x.reshape(-1, 2)


def write(name, x, q=4):
    x = np.clip(x, -1.0, 1.0).astype(np.float32)
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "2", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), "-map_metadata", "-1", str(OUT / (name + ".ogg"))],
                   input=x.tobytes(), check=True)
    print("%-22s %6.2f s  %8d bytes  %5.1f dB loud, %5.1f dB rms" % (name, x.shape[0] / RATE, (OUT / (name + ".ogg")).stat().st_size,
                                                                     loud(x), rms_db(x)))


def mono(x):
    return x.mean(axis=1) if x.ndim == 2 else x


def filt(x, fc, high):
    """A gentle first-order filter, applied in the frequency domain (both channels)."""
    n = x.shape[0]
    f = np.fft.rfftfreq(n, 1.0 / RATE)
    h = (1j * f / fc) / (1 + 1j * f / fc) if high else 1.0 / (1 + 1j * f / fc)
    return np.fft.irfft(np.fft.rfft(x, axis=0) * h[:, None], n, axis=0)


def hp(x, fc):
    return filt(x, fc, True)


def lp(x, fc):
    return filt(filt(x, fc, False), fc, False)


def loud(x):
    """The loudest 100 ms (RMS above 120 Hz), in dBFS, as make_sounds.py measures it."""
    y = hp(mono(x)[:, None], 120.0)[:, 0]
    n = int(0.1 * RATE)
    c = np.cumsum(np.concatenate([[0.0], y ** 2]))
    r = np.sqrt(np.max(c[n:] - c[:-n]) / n) if y.size > n else np.sqrt(np.mean(y ** 2))
    return 20 * np.log10(r + 1e-12)


def rms_db(x):
    return 20 * np.log10(np.sqrt(np.mean(mono(x) ** 2)) + 1e-12)


def level(x, target_db, ceiling=0.89):
    x = x * 10 ** ((target_db - loud(x)) / 20)
    k = ceiling * 0.8
    a = np.abs(x)
    return np.where(a > k, np.sign(x) * (k + (ceiling - k) * np.tanh((a - k) / (ceiling - k))), x)


def rms_level(x, target_db):
    return x * 10 ** ((target_db - rms_db(x)) / 20)


def fade(x, fin=0.05, fout=1.5):
    x = x.copy()
    a, b = int(fin * RATE), int(fout * RATE)
    if a:
        x[:a] *= np.linspace(0, 1, a)[:, None]
    if b:
        x[-b:] *= (np.linspace(1, 0, b) ** 2)[:, None]
    return x


def ride(x, window=4.0, amount=0.7):
    """Evens out a bed's level: a slow gain that pulls each few seconds toward the average (amount 0-1)."""
    n = int(window * RATE)
    p = mono(x) ** 2
    c = np.cumsum(np.concatenate([np.zeros(n // 2 + 1), p, np.zeros(n - n // 2)]))
    env = np.sqrt((c[n:n + p.size] - c[:p.size]) / n + 1e-9)
    g = (np.sqrt(np.mean(p)) / env) ** amount
    return x * np.clip(g, 0.3, 3.0)[:, None]


def join(parts, xfade=2.5):
    """Segments end to end, each cross-faded (equal power) into the next."""
    n = int(xfade * RATE)
    out = parts[0]
    for p in parts[1:]:
        w = np.linspace(0, 1, n)[:, None]
        mid = out[-n:] * np.sqrt(1 - w) + p[:n] * np.sqrt(w)
        out = np.concatenate([out[:-n], mid, p[n:]])
    return out


def loop(x, xfade=2.5):
    """A seamless loop: the tail cross-faded (equal power) into the head."""
    n = int(xfade * RATE)
    body = x[:-n].copy()
    w = np.linspace(0, 1, n)[:, None]
    body[:n] = body[:n] * np.sqrt(w) + x[-n:] * np.sqrt(1 - w)
    return body


def reverb(x, t60, mix_=0.35, pre=0.015):
    """A room, a different decaying noise for each ear (so the hall is wide)."""
    n = int(t60 * RATE)
    t = np.arange(n) / RATE
    out = np.empty((x.shape[0], 2))
    for c in range(2):
        ir = rng.standard_normal(n) * np.exp(-6.9 * t / t60)
        ir = lp(ir[:, None], 3500)[:, 0]
        ir /= np.sqrt(np.sum(ir ** 2))
        ir = np.concatenate([np.zeros(int(pre * RATE)), ir])
        m = x.shape[0] + ir.size
        wet = np.fft.irfft(np.fft.rfft(x[:, c], m) * np.fft.rfft(ir, m), m)[: x.shape[0]]
        out[:, c] = x[:, c] * (1 - mix_) + wet * mix_ * 3.0
    return out


def shift(x, semitones):
    """Pitch and speed together (a bigger or smaller crowd), by resampling."""
    r = 2 ** (semitones / 12.0)
    idx = np.arange(0, x.shape[0] - 1, r)
    return np.stack([np.interp(idx, np.arange(x.shape[0]), x[:, c]) for c in range(2)], axis=1)


def mixed(*parts):
    """(signal, gain_db, delay_s, pan -1..1) ... summed."""
    n = max(int(d * RATE) + s.shape[0] for s, g, d, p in parts)
    y = np.zeros((n, 2))
    for s, g, d, p in parts:
        o = int(d * RATE)
        pan = np.array([np.sqrt((1 - p) / 2), np.sqrt((1 + p) / 2)]) * np.sqrt(2)
        y[o:o + s.shape[0]] += s * 10 ** (g / 20) * pan
    return y


def main():
    lo = {k: load(k + ".ogg", base=LOW) for k in ["amb_arena", "crowd_cheer", "crowd_cheer_small", "applause",
                                                    "applause_hall", "crowd_ooh", "crowd_groan"]}
    bed_db = rms_db(lo["amb_arena"])   # the Low beds are all set to this level (-21 dBFS)
    # The arena's crowd: three stretches of a big crowd between cheers, evened out and joined into a 70 s loop.
    arena = join([ride(rms_level(load(CHEER % "10 - Ambience", 4.0, 27.0), -20)),
                  ride(rms_level(load(FULL, 150.5, 28.0), -20)),
                  ride(rms_level(load(FULL, 20.5, 17.5), -20))])
    write("amb_arena_long", rms_level(loop(ride(arena, 6.0, 0.5)), bed_db))
    # A sports hall's small crowd: the school party in full (48 s), dulled and echoing.
    hall = load(GQ + "crowd_-_school_excursion.mp3", 2.0, 48.5)
    hall = reverb(lp(hall, 5000) * 0.6, 1.6, 0.4)
    write("amb_hall_long", rms_level(loop(ride(hall, 5.0, 0.5)), bed_db))
    # A park court: two minutes of the park (birds, distant traffic, a plane) with a few people at a distance.
    park = load(GQ + "city_ambience_-_park_-_spring_-_with_birds_cars_and_planes.mp3", 98.0, 124.0)
    people = join([load(GQ + "crowd_-_school_excursion.mp3", s, 44.0) for s in (3.0, 6.0, 4.0)])
    people = lp(people[: park.shape[0]], 1800)
    write("amb_outdoor_long", rms_level(loop(rms_level(park, -24.0) + rms_level(people, -33.0)), bed_db))
    # More cheers: the arena's big crowd (the stretches round each peak), a smaller crowd's for the hall and park.
    cheer = loud(lo["crowd_cheer"])
    for i, (rel, s) in enumerate([(CHEER % "03 - Strong cheering - I", 3.0), (CHEER % "02 - Strong cheering and soft rhythmic cheering", 2.4),
                                  (FULL, 64.5), (FULL, 107.8)]):
        write("crowd_cheer_%d" % (i + 2), level(fade(load(rel, s, 8.0), 0.06, 2.5), cheer))
    small = loud(lo["crowd_cheer_small"])
    for i, (rel, s) in enumerate([(CHEER % "05 - Soft cheering - I", 6.6), (CHEER % "07 - Soft cheering and chatter", 7.6),
                                  (CHEER % "07 - Soft cheering and chatter", 18.2)]):
        write("crowd_cheer_small_%d" % (i + 2), level(fade(load(rel, s, 8.0), 0.08, 2.5), small))
    # Applause: other stretches of the arena's and the hall's recordings, and a third crowd.
    app = loud(lo["applause"])
    write("applause_2", level(fade(load(GQ + "crowd_-_applause_-_clapping.mp3", 12.0, 7.0), 0.15, 2.0), app))
    write("applause_3", level(fade(load(GQ + "crowd_-_applause_-_clapping.mp3", 25.0, 7.0), 0.15, 2.0), app))
    write("applause_4", level(fade(load("oga_applause/applause.wav", 0.0, 6.8), 0.1, 2.0), app))
    hall_app = loud(lo["applause_hall"])
    for i, s in enumerate([12.0, 24.0]):
        write("applause_hall_%d" % (i + 2), level(fade(load("oga_hallapplause/applause-clapping-church-crowd-immersive.wav", s, 6.5), 0.2, 2.0), hall_app))
    # The crowd's "ooh" and groan, two more each: the game's own, re-voiced as a different crowd (pitched apart and
    # layered across the stand).
    for k in ["crowd_ooh", "crowd_groan"]:
        x = lo[k]
        target = loud(x)
        a = mixed((shift(x, -1.5), 0, 0.0, -0.5), (shift(x, 1.0), -4, 0.07, 0.6), (shift(x, -3.0), -7, 0.12, 0.1))
        b = mixed((shift(x, 2.0), 0, 0.0, 0.4), (shift(x, -1.0), -3, 0.05, -0.6), (shift(x, 0.5), -6, 0.15, 0.0))
        write(k + "_2", level(fade(a, 0.01, 0.4), target))
        write(k + "_3", level(fade(b, 0.01, 0.4), target))


if __name__ == "__main__":
    main()

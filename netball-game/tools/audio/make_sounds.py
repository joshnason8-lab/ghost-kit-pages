#!/usr/bin/env python3
"""Make the game's recorded sounds: trims, layers, levels and loops the CC0 / CC-BY / CC-BY-SA recordings listed in
docs/SOUNDS.md, makes the whistle and the shoe squeaks, and writes them to assets/audio/ as mono Ogg Vorbis.

The downloads are not kept in the repository. Fetch each pack named in SOURCES into its own folder under SRC (the
folder names are the keys below), unpack the zips in place (into x/), then run:

    python3 -I tools/audio/make_sounds.py SRC

Needs numpy and ffmpeg with libvorbis. Levels: every one-shot is set to a loudness (the loudest 100 ms, above
120 Hz) so the set sounds even; the ones the home screen's match already played (whistle, ring, net, applause, click)
are matched to the synthesised sounds they replace, so the home screen is no louder than it was.
"""
import pathlib
import subprocess
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio"
RATE = 22050
rng = np.random.default_rng(7)

# Download folder -> where it came from (see docs/SOUNDS.md for authors and licences).
SOURCES = {
    "kenney_impact": "https://kenney.nl/assets/impact-sounds",
    "kenney_ui": "https://kenney.nl/assets/ui-audio",
    "kenney_rpg": "https://kenney.nl/assets/rpg-audio",
    "oga_steps": "https://opengameart.org/content/footsteps-on-different-surfaces",
    "oga_cheer": "https://opengameart.org/content/free-crowd-cheering-sounds",
    "oga_gq_amb": "https://opengameart.org/content/free-general-ambience-sounds",
    "oga_hallapplause": "https://opengameart.org/content/applause-in-a-large-hall-or-church",
    "oga_welldone": "https://opengameart.org/content/well-done",
}

SRC = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(".")
CHEER = "oga_cheer/x/Gregor Quendel - Free Crowd Cheering Sounds - MP3/Gregor Quendel - Crowd Cheering Sounds - %s.mp3"


# ---------------------------------------------------------------- basics

def load(rel, start=0.0, dur=None):
    cmd = ["ffmpeg", "-v", "error", "-ss", str(start)]
    if dur:
        cmd += ["-t", str(dur)]
    cmd += ["-i", str(SRC / rel), "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"]
    return np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, dtype=np.float32).astype(np.float64)


def write(name, x, q=3):
    x = np.clip(x, -1.0, 1.0).astype(np.float32)
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), "-map_metadata", "-1", str(OUT / (name + ".ogg"))],
                   input=x.tobytes(), check=True)
    print("%-20s %5.2f s  %6d bytes  %5.1f dB" % (name, x.size / RATE, (OUT / (name + ".ogg")).stat().st_size, loud(x)))


def onepole(x, fc, high):
    a = np.exp(-2.0 * np.pi * fc / RATE)
    y = np.empty_like(x)
    s = 0.0
    for i, v in enumerate(x):
        s = (1 - a) * v + a * s
        y[i] = s
    return x - y if high else y


def hp(x, fc):
    return onepole(x, fc, True)


def lp(x, fc):
    return onepole(onepole(x, fc, False), fc, False)


def fade(x, fin=0.005, fout=0.05):
    x = x.copy()
    a, b = int(fin * RATE), int(fout * RATE)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b) ** 2
    return x


def trim(x, thresh=0.01, pre=0.004):
    idx = np.nonzero(np.abs(x) > thresh * np.max(np.abs(x)))[0]
    if idx.size == 0:
        return x
    a = max(0, idx[0] - int(pre * RATE))
    return x[a:idx[-1] + 1]


def mix(*parts):
    """(signal, gain_db, delay_s) ... summed."""
    n = max(int(d * RATE) + s.size for s, g, d in parts)
    y = np.zeros(n)
    for s, g, d in parts:
        o = int(d * RATE)
        y[o:o + s.size] += s * 10 ** (g / 20)
    return y


def reverb(x, t60, mix_=0.25, pre=0.012):
    """A room: decaying noise as the impulse response (dark, so it reads as a hall rather than a spring)."""
    n = int(t60 * RATE)
    t = np.arange(n) / RATE
    ir = rng.standard_normal(n) * np.exp(-6.9 * t / t60)
    ir = lp(ir, 3500)
    ir /= np.sqrt(np.sum(ir ** 2))
    ir = np.concatenate([np.zeros(int(pre * RATE)), ir])
    m = x.size + ir.size
    wet = np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(ir, m), m)
    dry = np.concatenate([x, np.zeros(ir.size)])
    return dry * (1 - mix_) + wet * mix_ * 3.0


def loud(x):
    """The loudest 100 ms (RMS above 120 Hz), in dBFS."""
    y = hp(x, 120.0)
    n = int(0.1 * RATE)
    if y.size <= n:
        r = np.sqrt(np.mean(y ** 2))
    else:
        c = np.cumsum(np.concatenate([[0.0], y ** 2]))
        r = np.sqrt(np.max(c[n:] - c[:-n]) / n)
    return 20 * np.log10(r + 1e-12)


def level(x, target_db, ceiling=0.89):
    """To a loudness, then a soft limit so no peak passes the ceiling."""
    x = x * 10 ** ((target_db - loud(x)) / 20)
    pk = np.max(np.abs(x))
    if pk > ceiling:
        over = np.abs(x) > ceiling * 0.8
        k = ceiling * 0.8
        x = np.where(over, np.sign(x) * (k + (ceiling - k) * np.tanh((np.abs(x) - k) / (ceiling - k))), x)
    return x


def loop(x, xfade=1.5):
    """A seamless loop: the tail cross-faded (equal power) into the head."""
    n = int(xfade * RATE)
    body = x[:-n].copy()
    w = np.linspace(0, 1, n)
    body[:n] = body[:n] * np.sqrt(w) + x[-n:] * np.sqrt(1 - w)
    return body


def rms_level(x, target_db):
    return x * 10 ** ((target_db - 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)) / 20)


# ---------------------------------------------------------------- the synthesised sounds being replaced (as sfx.gd)

def old_whistle(dur=0.5):
    t = np.arange(int(dur * RATE)) / RATE
    phase = np.cumsum(2 * np.pi * (2900 + np.sin(2 * np.pi * 34 * t) * 180) / RATE)
    env = np.minimum(1, t / 0.02) * np.clip((dur - t) / 0.08, 0, 1)
    return np.sin(phase) * (0.65 + 0.35 * np.sin(2 * np.pi * 34 * t)) * env * 0.45


def old_rim():
    t = np.arange(int(0.6 * RATE)) / RATE
    ring = np.sin(2 * np.pi * 1180 * t) * 0.4 + np.sin(2 * np.pi * 2630 * t) * 0.25 + np.sin(2 * np.pi * 3910 * t) * 0.12
    return (ring * np.exp(-t * 7) + np.sin(2 * np.pi * 140 * t) * np.exp(-t * 30) * 0.5) * 0.7


def smooth_noise(n, k):
    out = np.empty(n)
    s = 0.0
    r = rng.uniform(-1, 1, n)
    for i in range(n):
        s += (r[i] - s) * k
        out[i] = s
    return out


def old_net():
    n = int(0.45 * RATE)
    t = np.arange(n) / RATE
    return smooth_noise(n, 0.5) * np.exp(-t * 9) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t)) * 0.6


def old_slap():
    n = int(0.16 * RATE)
    t = np.arange(n) / RATE
    return (smooth_noise(n, 0.55) * np.exp(-t * 60) * 0.8 + np.sin(2 * np.pi * (220 - 100 * t / 0.16) * t) * np.exp(-t * 40) * 0.6) * 0.8


def old_click():
    dur = 0.035
    t = np.arange(int(dur * RATE)) / RATE
    return np.sin(2 * np.pi * 1500 * t) * 0.5 * np.minimum(1, t / 0.001) * np.clip((dur - t) / 0.03, 0, 1)


# ---------------------------------------------------------------- made for the game

def whistle(dur, blast=1.0):
    """An umpire's pea whistle: a bright tone near 3 kHz warbled by the pea (an uneven 35-45 Hz flutter of pitch and
    level), its octave, breath noise around it, a quick chirp up at the start."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    flutter_rate = 38 + smooth_noise(n, 0.0005) * 40
    fl = np.sin(np.cumsum(2 * np.pi * flutter_rate / RATE))
    f = 3050 * (0.93 + 0.07 * np.minimum(1, t / 0.03)) + fl * 210 + smooth_noise(n, 0.002) * 300
    ph = np.cumsum(2 * np.pi * f / RATE)
    tone = np.sin(ph) + 0.18 * np.sin(2 * ph + 0.4) + 0.05 * np.sin(3 * ph)
    am = 0.62 + 0.38 * (0.5 + 0.5 * fl)
    breath = hp(lp(rng.standard_normal(n), 4200), 1800) * 0.25
    env = np.minimum(1, t / 0.012) * np.clip((dur - t) / 0.07, 0, 1) ** 1.5
    env *= 1.0 + (blast - 1.0) * np.exp(-t / 0.15)   # a harder first puff on a long blast
    return reverb((tone * am + breath * (0.5 + 0.5 * am)) * env * 0.4, 0.5, 0.12)


def squeak(f0, dur):
    """A shoe on a sprung floor: rubber stick-slip, a rough tone gliding up, with its harmonics."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    f = f0 * (1 + 0.25 * t / dur + 0.04 * smooth_noise(n, 0.01))
    ph = np.cumsum(2 * np.pi * f / RATE)
    tone = np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph) + 0.1 * np.sin(4 * ph)
    rough = 0.65 + 0.35 * np.sign(np.sin(np.cumsum(2 * np.pi * (90 + 40 * smooth_noise(n, 0.02)) / RATE)))
    env = np.minimum(1, t / 0.012) * np.clip((dur - t) / 0.05, 0, 1) * (0.7 + 0.3 * np.sin(np.pi * t / dur))
    return reverb(tone * rough * env * 0.3, 0.6, 0.18)


# ---------------------------------------------------------------- the set

def main():
    k = "kenney_impact/x/Audio/"
    # The whistle: short (a call), long (a goal, the quarter's end); as loud as the synthesised one was.
    write("whistle", level(whistle(0.42), loud(old_whistle())))
    write("whistle_long", level(whistle(1.05, 1.15), loud(old_whistle(1.1))))
    # The ball into two hands: Kenney's medium punches, a dull slap.
    for i in range(3):
        write("catch_%d" % (i + 1), level(fade(trim(hp(load(k + "impactPunch_medium_%03d.ogg" % i), 110)), 0.002, 0.08), -15.0))
    # The ball on the floor: a deep soft thump with the slap of the panel on top; a sprung timber floor booms and
    # the hall answers; asphalt is drier and harder.
    for i, (a, b) in enumerate([(0, 1), (2, 0)]):
        body = trim(load(k + "impactSoft_heavy_%03d.ogg" % a))
        slap = trim(hp(load(k + "impactPunch_medium_%03d.ogg" % b), 200))
        write("bounce_floor_%d" % (i + 1), level(fade(reverb(mix((body, 0, 0), (slap, -9, 0.002)), 0.7, 0.14), 0.001, 0.12), -14.0))
        body = trim(load(k + "impactSoft_medium_%03d.ogg" % (a + 1)))
        write("bounce_court_%d" % (i + 1), level(fade(hp(mix((body, 0, 0), (slap, -3, 0.0)), 90), 0.001, 0.05), -14.0))
    # The ball off the ring: the steel ring's clang, the ball's thud, the net shaken.
    ring = trim(load(k + "impactMetal_medium_000.ogg"))
    thud = trim(load(k + "impactSoft_medium_002.ogg"))
    net = trim(hp(load("kenney_rpg/x/Audio/cloth3.ogg"), 500))
    write("rim", level(fade(mix((ring, 0, 0), (thud, -10, 0), (net, -8, 0.03)), 0.001, 0.1), loud(old_rim())))
    # Through the net: cord rustled.
    swish = hp(trim(load("kenney_rpg/x/Audio/cloth1.ogg")), 350)[: int(0.5 * RATE)]
    write("swish", level(fade(swish, 0.003, 0.2), loud(old_net())))
    # The interface's click.
    write("click", level(fade(trim(load("kenney_ui/x/Audio/click2.ogg")), 0.0, 0.01), loud(old_click()) - 2.0))
    # Steps: polished floor (with the odd squeak in it) and asphalt.
    for i, j in enumerate([0, 2, 4, 6]):
        write("step_floor_%d" % (i + 1), level(fade(trim(load("oga_steps/x/footsteps/tile/%d.ogg" % j)), 0.001, 0.03), -20.0))
    for i in range(4):
        write("step_court_%d" % (i + 1), level(fade(trim(load(k + "footstep_concrete_%03d.ogg" % i)), 0.001, 0.03), -20.0))
    # Shoe squeaks on a sprung floor (indoors only).
    for i, (f0, d) in enumerate([(2100, 0.16), (2500, 0.12), (1800, 0.2)]):
        write("squeak_%d" % (i + 1), level(squeak(f0, d), -18.0))
    # The crowd: a big crowd's cheer (the arena), a smaller one (the hall, the park); applause three ways.
    write("crowd_cheer", level(fade(load(CHEER % "04 - Strong cheering - II - Short", 3.2, 7.0), 0.06, 2.5), -13.0))
    write("crowd_cheer_small", level(fade(load(CHEER % "06 - Soft cheering - II", 1.2, 8.0), 0.08, 2.5), -15.0))
    old_app = -13.7   # the Kabaddi applause.ogg this replaces: its loudest 100 ms
    write("applause", level(fade(load("oga_gq_amb/applause.mp3", 1.2, 7.0), 0.15, 2.0), old_app))
    write("applause_hall", level(fade(load("oga_hallapplause/a.wav", 1.0, 6.5), 0.2, 2.0), old_app - 1.0))
    write("applause_small", level(fade(trim(load("oga_welldone/w.ogg")), 0.05, 0.8), old_app - 2.0))
    # Venue ambience, seamless loops: the arena's crowd; a sports hall's small crowd, echoing; a park court's few
    # spectators over birds and distant traffic.
    arena = loop(load(CHEER % "10 - Ambience", 12.5, 17.5))
    write("amb_arena", rms_level(arena, -21.0), q=2)
    hall = load("oga_gq_amb/school.mp3", 24.0, 19.0)
    hall = reverb(lp(hall, 5000) * 0.6, 1.6, 0.4)[: hall.size]
    write("amb_hall", rms_level(loop(hall), -21.0), q=2)
    park = load("oga_gq_amb/park.mp3", 118.0, 19.0)
    people = lp(load("oga_gq_amb/school.mp3", 4.0, 19.0), 1800)
    out = rms_level(park, -24.0) + rms_level(people, -33.0)
    write("amb_outdoor", rms_level(loop(out), -21.0), q=2)


if __name__ == "__main__":
    main()

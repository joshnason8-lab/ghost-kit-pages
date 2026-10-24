#!/usr/bin/env python3
"""The game's recorded sounds: fetch them from their sources (kenney.nl and opengameart.org, CC0 and CC-BY only),
trim, mix to mono, even out their loudness, make the loops seamless and write Ogg Vorbis to assets/audio/.
docs/SOUNDS.md is written from the same table, so every file has its source, author and licence.

  python3 tools/sound/process.py DOWNLOADS_DIR      (needs ffmpeg; the downloads are not committed)

DOWNLOADS_DIR holds the packs as fetched: kenney_impact-sounds/, kenney_interface-sounds/, kenney_rpg-audio/
(the zips unpacked) and oga/ (the OpenGameArt files, forest_birds.7z unpacked into oga/birds/).
"""
import json
import pathlib
import subprocess
import sys
import tempfile
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio"
KENNEY = ("Kenney (kenney.nl)", "CC0 1.0")
K_IMPACT = "https://kenney.nl/assets/impact-sounds"
K_UI = "https://kenney.nl/assets/interface-sounds"
K_RPG = "https://kenney.nl/assets/rpg-audio"
GQ_CREDIT = ("Gregor Quendel", "CC-BY 4.0")
GQ_URL = "https://opengameart.org/content/free-crowd-cheering-sounds"

# name: (source file in the downloads, what it is in the game, kind, options, (author, licence), url)
# kind: "shot" (a one-shot: trimmed, peak-normalised), "loop" (seamless, loudness-normalised).
SOUNDS = [
    # The ball off a hip: the body's thump under the synthesised slap of rubber on leather.
    ("hip_body_1", "kenney_impact-sounds/Audio/impactPunch_heavy_000.ogg", "the hip strike's body", "shot", {}, KENNEY, K_IMPACT),
    ("hip_body_2", "kenney_impact-sounds/Audio/impactPunch_heavy_002.ogg", "the hip strike's body", "shot", {}, KENNEY, K_IMPACT),
    ("hip_body_3", "kenney_impact-sounds/Audio/impactPunch_heavy_004.ogg", "the hip strike's body", "shot", {}, KENNEY, K_IMPACT),
    # The heavy ball on packed earth.
    ("thud_earth_1", "kenney_impact-sounds/Audio/impactSoft_heavy_000.ogg", "the ball down on earth", "shot", {"lowpass": 2500}, KENNEY, K_IMPACT),
    ("thud_earth_2", "kenney_impact-sounds/Audio/impactSoft_heavy_002.ogg", "the ball down on earth", "shot", {"lowpass": 2500}, KENNEY, K_IMPACT),
    ("thud_earth_3", "kenney_impact-sounds/Audio/impactSoft_heavy_004.ogg", "the ball down on earth", "shot", {"lowpass": 2500}, KENNEY, K_IMPACT),
    # Bare feet: on packed earth (soft), on plastered stone (harder, a little slap).
    ("step_earth_1", "kenney_rpg-audio/Audio/footstep00.ogg", "a bare foot on earth", "shot", {"lowpass": 3000}, KENNEY, K_RPG),
    ("step_earth_2", "kenney_rpg-audio/Audio/footstep02.ogg", "a bare foot on earth", "shot", {"lowpass": 3000}, KENNEY, K_RPG),
    ("step_earth_3", "kenney_rpg-audio/Audio/footstep04.ogg", "a bare foot on earth", "shot", {"lowpass": 3000}, KENNEY, K_RPG),
    ("step_earth_4", "kenney_rpg-audio/Audio/footstep06.ogg", "a bare foot on earth", "shot", {"lowpass": 3000}, KENNEY, K_RPG),
    ("step_stone_1", "kenney_impact-sounds/Audio/footstep_concrete_000.ogg", "a bare foot on stone", "shot", {"lowpass": 4000}, KENNEY, K_IMPACT),
    ("step_stone_2", "kenney_impact-sounds/Audio/footstep_concrete_001.ogg", "a bare foot on stone", "shot", {"lowpass": 4000}, KENNEY, K_IMPACT),
    ("step_stone_3", "kenney_impact-sounds/Audio/footstep_concrete_002.ogg", "a bare foot on stone", "shot", {"lowpass": 4000}, KENNEY, K_IMPACT),
    ("step_stone_4", "kenney_impact-sounds/Audio/footstep_concrete_003.ogg", "a bare foot on stone", "shot", {"lowpass": 4000}, KENNEY, K_IMPACT),
    # The menus.
    ("click", "kenney_interface-sounds/Audio/click_002.ogg", "a button pressed", "shot", {}, KENNEY, K_UI),
    ("ui_select", "kenney_interface-sounds/Audio/select_001.ogg", "a choice made (a chip, a team)", "shot", {}, KENNEY, K_UI),
    # The courts' surroundings.
    ("amb_crickets", "oga/crickets_1.mp3", "crickets: the village at dusk, the stone court by torchlight", "loop", {"fade": 1.5},
     ("Wolfgang_ (Ted Kerr)", "CC0 1.0"), "https://opengameart.org/content/crickets-ambient-noise-loopable"),
    ("amb_fire", "oga/fire.wav", "the torches' fire round the stone court at night", "loop", {"take": 14.0, "fade": 2.0},
     ("PagDev", "CC0 1.0"), "https://opengameart.org/content/fireplace-sound-loop"),
    ("crowd_loop", "oga/gq/Gregor Quendel - Free Crowd Cheering Sounds - MP3/Gregor Quendel - Crowd Cheering Sounds - 10 - Ambience.mp3", "the crowd's murmur round the court", "loop", {"take": 22.0, "lowpass": 3000, "fade": 2.0},
     GQ_CREDIT, GQ_URL),
    ("crowd_cheer", "oga/gq/Gregor Quendel - Free Crowd Cheering Sounds - MP3/Gregor Quendel - Crowd Cheering Sounds - 04 - Strong cheering - II - Short.mp3", "the crowd going up (a raya, the ring)", "shot",
     {"start": 0.0, "take": 6.0, "fadeout": 2.0, "lowpass": 5000}, GQ_CREDIT, GQ_URL),
    ("applause", "oga/gq/Gregor Quendel - Free Crowd Cheering Sounds - MP3/Gregor Quendel - Crowd Cheering Sounds - 05 - Soft cheering - I.mp3", "applause and soft cheering after a raya", "shot",
     {"start": 1.0, "take": 5.0, "fadeout": 1.5, "lowpass": 5000}, GQ_CREDIT, GQ_URL),
    ("dog_bark", "oga/dog_barking_mono.wav", "a dog in the village, far off", "shot", {"lowpass": 2500},
     ("Brandon Morris (submitted by HaelDB)", "CC0 1.0 (or OGA-BY 3.0)"), "https://opengameart.org/content/dog-barking-mono"),
]
for i, n in enumerate([1, 2, 3, 5, 7, 4]):
    SOUNDS.append(("bird_%d" % (i + 1), "oga/birds/Forest Birds/Forest Birds %d.wav" % n, "a bird in the forest round the stone court",
                   "shot", {}, ("pauliuw", "CC0 1.0"), "https://opengameart.org/content/forest-bird-sounds"))

# Medium and High: longer, stereo beds and more crowd reactions (Low keeps the ones above, unchanged).
JC_CREDIT = ("JC Sounds", "CC-BY 4.0")
JC_URL = "https://opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1"
SOUNDS += [
    ("amb_village_hq", "oga/jc/Nature Ambient Pack Vol 1 - mp3/Weather/AMB_Nature Pack Vol 1_Weather_Summer Evening.mp3", "the village at dusk (Medium, High)", "loop",
     {"take": 60.0, "fade": 3.0, "stereo": True}, JC_CREDIT, JC_URL),
    ("amb_forest_hq", "oga/jc/Nature Ambient Pack Vol 1 - mp3/Forest Enviroments/AMB_Nature Pack Vol 1_Forest Enviroments_Rainforest Canopy.mp3", "the forest round the stone court by day (Medium, High)", "loop",
     {"take": 60.0, "fade": 3.0, "stereo": True}, JC_CREDIT, JC_URL),
    ("amb_night_hq", "oga/jc/Nature Ambient Pack Vol 1 - mp3/Forest Enviroments/AMB_Nature Pack Vol 1_Forest Enviroments_Forest Night.mp3", "the forest at night round the torch-lit court (Medium, High)", "loop",
     {"take": 60.0, "fade": 3.0, "stereo": True}, JC_CREDIT, JC_URL),
    ("amb_torch_hq", "oga/jc/Nature Ambient Pack Vol 1 - mp3/Fire & Elemental/AMB_Nature Pack Vol 1_ Fire & Elemental_Torch Flame.mp3", "the torches' flames (Medium, High)", "loop",
     {"take": 40.0, "fade": 2.0, "stereo": True}, JC_CREDIT, JC_URL),
    ("crowd_loop_hq", "oga/gq/Gregor Quendel - Free Crowd Cheering Sounds - MP3/Gregor Quendel - Crowd Cheering Sounds - 07 - Soft cheering and chatter.mp3", "the crowd round the court, longer, with its chatter (Medium, High)", "loop",
     {"take": 36.0, "lowpass": 3500, "fade": 3.0, "stereo": True}, GQ_CREDIT, GQ_URL),
    ("crowd_cheer_2", "oga/gq/Gregor Quendel - Free Crowd Cheering Sounds - MP3/Gregor Quendel - Crowd Cheering Sounds - 03 - Strong cheering - I.mp3", "the crowd going up, another (Medium, High)", "shot",
     {"start": 0.5, "take": 7.0, "fadeout": 2.5, "lowpass": 5000}, GQ_CREDIT, GQ_URL),
    ("crowd_cheer_3", "oga/gq/Gregor Quendel - Free Crowd Cheering Sounds - MP3/Gregor Quendel - Crowd Cheering Sounds - 01 - Strong cheering and strong rhythmic cheering.mp3", "the crowd going up and clapping in time (Medium, High)", "shot",
     {"start": 2.0, "take": 9.0, "fadeout": 3.0, "lowpass": 5000}, GQ_CREDIT, GQ_URL),
    ("applause_2", "oga/gq/Gregor Quendel - Free Crowd Cheering Sounds - MP3/Gregor Quendel - Crowd Cheering Sounds - 06 - Soft cheering - II.mp3", "applause, another (Medium, High)", "shot",
     {"start": 1.0, "take": 6.0, "fadeout": 2.0, "lowpass": 5000}, GQ_CREDIT, GQ_URL),
]


def read(path, stereo=False):
    """Float samples at 32 kHz: mono, or (n, 2) for stereo."""
    out = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "2" if stereo else "1", "-ar", "32000", "-f", "f32le", "-"],
                         check=True, capture_output=True).stdout
    x = np.frombuffer(out, dtype=np.float32).astype(np.float64)
    return x.reshape(-1, 2) if stereo else x


def lowpass(x, hz):
    """A gentle one-pole low-pass (twice), for distance."""
    if x.ndim == 2:
        return np.column_stack([lowpass(x[:, c], hz) for c in range(x.shape[1])])
    a = np.exp(-2 * np.pi * hz / 32000)
    for _ in range(2):
        y = np.empty_like(x)
        acc = 0.0
        for i, v in enumerate(x):
            acc = (1 - a) * v + a * acc
            y[i] = acc
        x = y
    return x


def trim(x, floor=0.01):
    idx = np.nonzero(np.abs(x) > floor * np.max(np.abs(x)))[0]
    if len(idx) == 0:
        return x
    a = max(0, idx[0] - 160)
    b = min(len(x), idx[-1] + 1600)
    y = x[a:b].copy()
    fade = min(len(y) // 4, 1600)
    y[-fade:] *= np.linspace(1, 0, fade)
    return y


def loop(x, fade_s):
    """Seamless: the last fade_s seconds cross-faded into the first, then dropped."""
    n = int(fade_s * 32000)
    head = x[:n]
    tail = x[-n:]
    t = np.linspace(0, 1, n)
    if x.ndim == 2:
        t = t[:, None]
    body = x[n:-n] if len(x) > 2 * n else x[n:]
    mixed = tail * np.cos(t * np.pi / 2) + head * np.sin(t * np.pi / 2)
    return np.concatenate([mixed, body])


def write(x, name, quality):
    dst = OUT / (name + ".ogg")
    with tempfile.TemporaryDirectory() as d:
        w = pathlib.Path(d) / "s.wav"
        with wave.open(str(w), "wb") as f:
            f.setnchannels(2 if x.ndim == 2 else 1)
            f.setsampwidth(2)
            f.setframerate(32000)
            f.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(w), "-c:a", "libvorbis", "-q:a", str(quality), str(dst)], check=True)
    return dst


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    src = pathlib.Path(sys.argv[1])
    rows = []
    total = 0
    for name, f, what, kind, opt, (author, lic), url in SOUNDS:
        x = read(src / f, bool(opt.get("stereo", False)))
        if "start" in opt:
            x = x[int(opt["start"] * 32000):]
        if "take" in opt:
            x = x[: int(opt["take"] * 32000)]
        if "lowpass" in opt:
            x = lowpass(x, opt["lowpass"])
        if kind == "shot":
            x = trim(x) if x.ndim == 1 else x
            if "fadeout" in opt:
                n = min(len(x), int(opt["fadeout"] * 32000))
                x[-n:] *= np.linspace(1, 0, n) ** 2
            x = x / max(1e-6, np.max(np.abs(x))) * 0.89          # -1 dBFS peak
            q = 2
        else:
            x = loop(x, opt.get("fade", 1.0))
            rms = np.sqrt(np.mean(x ** 2))
            x = x * (0.1 / max(rms, 1e-6))                       # -20 dBFS RMS: every bed at the same loudness
            peak = np.max(np.abs(x))
            if peak > 0.89:
                x = x * 0.89 / peak
            q = 2 if x.ndim == 2 else 1
        dst = write(x, name, q)
        total += dst.stat().st_size
        rows.append((name, what, f.split("/")[-1], author, lic, url, len(x) / 32000))
        print("%-14s %5.1f s %4d KB  %s" % (name, len(x) / 32000, dst.stat().st_size // 1024, f))
    print("total %d KB" % (total // 1024))
    (ROOT / "tools" / "sound" / "sounds.json").write_text(json.dumps(
        [{"file": r[0] + ".ogg", "what": r[1], "source_file": r[2], "author": r[3], "licence": r[4], "url": r[5]} for r in rows], indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())

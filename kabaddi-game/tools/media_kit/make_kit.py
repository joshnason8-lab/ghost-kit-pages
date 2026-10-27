#!/usr/bin/env python3
"""The media kit for the game's website, made again from the current build: media-kit-kabaddi-raid.zip.

    python3 tools/media_kit/make_kit.py OUT [--contact EMAIL] [--store] [--skip-render]

OUT is a working folder outside the repository (the renders and the video are big; none of it is committed). It
needs Godot, xvfb-run and ffmpeg. Steps:
  1. tests/media.tscn renders the screenshots (raids on every ground, caught as they happen) and every menu screen,
     on High, in English, at 1920x1080.
  2. tests/trailer.tscn records the trailer's footage with Movie Maker at 30 fps, with the game's own sound
     (an override.cfg beside project.godot sets the 1920x1080 window while it records, then is removed).
  3. With --store, the Play store's pictures are made again too (tests/screenshots.tscn "store", then
     tools/store_art.py), so the listing's screenshots and feature graphic follow the build.
  4. The icons (1024 and 512 px, from the icon's source painting), the feature graphic, the website copy
     (store/media/text/*.md, with the version and the contact filled in), the trailer (30-45 s, 1920x1080, H.264 and
     AAC) and a 15 s vertical cut (1080x1920), CREDITS.txt, and the zip.
--skip-render reuses OUT/raw from a run before (to recut the trailer or rebuild the zip).
The game is landscape only, so there are no portrait screenshots.
"""
import argparse
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import zipfile

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import store_art  # noqa: E402  (its font() and rounded())

W, H = 1920, 1080
FPS = 30
BG = (12, 26, 41)
INK = store_art.INK
GOLD = store_art.GOLD
XVFB = ["xvfb-run", "-a", "-s", "-screen 0 1920x1080x24"]
GODOT = ["godot", "--path", str(ROOT), "--rendering-driver", "opengl3"]


def run(cmd, log=None, **kw):
    print("+", " ".join(str(c) for c in cmd)[:200], flush=True)
    with open(log, "w") if log else open(os.devnull, "w") as f:
        r = subprocess.run(cmd, stdout=f if log else None, stderr=subprocess.STDOUT if log else None, **kw)
    if r.returncode != 0:
        raise SystemExit("failed (%d): %s" % (r.returncode, cmd[0]))


def version():
    return re.search(r'config/version="([^"]+)"', (ROOT / "project.godot").read_text()).group(1)


# ---------------------------------------------------------------- rendering

def render(raw: pathlib.Path, store: bool):
    for what in ["shots", "menus"]:
        d = raw / what
        shutil.rmtree(d, ignore_errors=True)
        run(XVFB + GODOT + ["--resolution", "%dx%d" % (W, H), "res://tests/media.tscn", "--", str(d), what],
            log=raw / ("%s.log" % what))
    override = ROOT / "override.cfg"
    override.write_text("[display]\n\nwindow/size/window_width_override=%d\nwindow/size/window_height_override=%d\n"
                        % (W, H))
    try:
        run(XVFB + GODOT + ["--write-movie", str(raw / "trailer.avi"), "--fixed-fps", str(FPS),
                            "res://tests/trailer.tscn"], log=raw / "trailer.log")
    finally:
        override.unlink()
    if store:
        d = raw / "store"
        run(XVFB + GODOT + ["--resolution", "%dx%d" % (W, H), "res://tests/screenshots.tscn", "--", str(d), "store"],
            log=raw / "store.log")
        run([sys.executable, str(ROOT / "tools" / "store_art.py"), str(d)])


# ---------------------------------------------------------------- pictures

def icons(out: pathlib.Path):
    """The launcher icon as phones show it (tools/ui_art/import_art.py's framing), at 1024 and 512 px. The icon is a
    painting to its edges, so it has no transparent background."""
    sys.path.insert(0, str(ROOT / "tools" / "ui_art"))
    import import_art
    src = Image.open(ROOT / "tools" / "ui_art" / "src" / "icon_source.webp").convert("RGB")
    pad = import_art.FRAME
    base = src.resize((src.width + 2 * pad, src.width + 2 * pad), Image.LANCZOS).filter(ImageFilter.GaussianBlur(40))
    base.paste(src, (pad, pad))
    cx, cy = import_art.CENTRE[0] + pad, import_art.CENTRE[1] + pad
    vis = import_art.FRAME * 72 // 108
    shown = base.crop((cx - vis // 2, cy - vis // 2, cx + vis // 2, cy + vis // 2))
    out.mkdir(parents=True, exist_ok=True)
    for n in [1024, 512]:
        shown.resize((n, n), Image.LANCZOS).save(out / ("icon-%d.png" % n), optimize=True)
        store_art.rounded(shown.resize((n, n), Image.LANCZOS), n * 22 // 100).save(
            out / ("icon-%d-rounded.png" % n), optimize=True)
    shutil.copy(ROOT / "store" / "graphics" / "feature-1024x500.png", out / "feature-1024x500.png")


def card(path: pathlib.Path, size, title: str, lines, tag: str = ""):
    """A title or end card: the icon, the game's name, and lines under it, on the game's dark blue."""
    w, h = size
    img = Image.new("RGB", (w, h), BG)
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse((w // 2 - w // 2, h // 2 - h // 3, w // 2 + w // 2, h // 2 + h // 3), fill=70)
    img = Image.composite(Image.new("RGB", (w, h), (30, 58, 88)), img, glow.filter(ImageFilter.GaussianBlur(w // 8)))
    s = min(w, h)
    ic = store_art.rounded(Image.open(ROOT / "assets" / "icon" / "icon_512.png").convert("RGB")
                           .resize((s * 30 // 100, s * 30 // 100), Image.LANCZOS), s * 7 // 100)
    y = h // 2 - s * 36 // 100
    img.paste(ic, ((w - ic.width) // 2, y), ic)
    d = ImageDraw.Draw(img)
    y += ic.height + s * 3 // 100
    f = store_art.font("Teko.ttf", s * 17 // 100, 600)
    tw = d.textlength(title, font=f)
    d.text(((w - tw) / 2, y), title, font=f, fill=INK)
    y += s * 19 // 100
    for i, line in enumerate(lines):
        f = store_art.font("NotoSans.ttf", s * (5 if i == 0 else 3) // 100, 700 if i == 0 else 500)
        tw = d.textlength(line, font=f)
        d.text(((w - tw) / 2, y), line, font=f, fill=GOLD if i == 0 else (205, 216, 230))
        y += s * (8 if i == 0 else 5) // 100
    if tag:
        f = store_art.font("NotoSans.ttf", s * 25 // 1000, 500)
        tw = d.textlength(tag, font=f)
        d.text(((w - tw) / 2, h - s * 7 // 100), tag, font=f, fill=(150, 165, 185))
    img.save(path)


def caption(path: pathlib.Path, size, text: str, small: str = ""):
    """A caption over the footage, low on the picture, on a soft dark band (a transparent PNG)."""
    w, h = size
    s = min(w, h)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    band = Image.new("L", (w, h), 0)
    ImageDraw.Draw(band).rectangle((0, h - s * 30 // 100, w, h), fill=170)
    img.putalpha(0)
    shade = Image.new("RGBA", (w, h), (6, 14, 24, 255))
    shade.putalpha(band.filter(ImageFilter.GaussianBlur(s // 14)))
    img = Image.alpha_composite(img, shade)
    d = ImageDraw.Draw(img)
    f = store_art.font("Teko.ttf", s * 11 // 100, 600)
    tw = d.textlength(text, font=f)
    y = h - s * (23 if small else 18) // 100
    d.text(((w - tw) / 2, y), text, font=f, fill=INK)
    if small:
        f2 = store_art.font("NotoSans.ttf", s * 36 // 1000, 600)
        tw = d.textlength(small, font=f2)
        d.text(((w - tw) / 2, y + s * 12 // 100), small, font=f2, fill=GOLD)
    img.save(path)


# ---------------------------------------------------------------- the trailer

def marks(log: pathlib.Path) -> dict:
    out = {}
    for line in log.read_text(errors="replace").splitlines():
        m = re.match(r"TRAILER (\S+) ([0-9.]+)$", line.strip())
        if m:
            out.setdefault(m.group(1), float(m.group(2)))
    return out


def moment(mk: dict, ground: str, prefer, before=1.6, after=1.9):
    """The best moment on a ground: (start, length) of the window round it, inside the ground's own footage."""
    lo, hi = mk.get(ground + "_start"), mk.get(ground + "_end")
    for kind in prefer:
        t = mk.get("%s_%s" % (ground, kind))
        if t is not None and lo is not None:
            a = max(lo + 0.2, t - before)
            b = min(hi - 0.1 if hi else t + after, t + after)
            if b - a > 1.5:
                return a, b - a
    if lo is not None:
        return lo + 2.0, before + after
    return None


def segment(avi, out, start, dur, vf_extra="", overlay=None, size=(W, H), crop=None):
    """One cut of the footage, made uniform (size, 30 fps, H.264, AAC 48 kHz stereo), with an optional caption."""
    w, h = size
    vf = "fps=%d,scale=%d:%d:flags=lanczos,setsar=1" % (FPS, w, h)
    if crop:
        vf = "crop=%s,%s" % (crop, vf)
    if vf_extra:
        vf += "," + vf_extra
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-ss", "%.3f" % start, "-t", "%.3f" % dur, "-i", str(avi)]
    if overlay:
        cmd += ["-loop", "1", "-t", "%.3f" % dur, "-i", str(overlay), "-filter_complex",
                "[0:v]%s[v];[1:v]format=rgba,fade=t=in:st=0.15:d=0.35:alpha=1,fade=t=out:st=%.2f:d=0.3:alpha=1[c];"
                "[v][c]overlay=0:0:shortest=1[o]" % (vf, max(0.5, dur - 0.45)), "-map", "[o]", "-map", "0:a?"]
    else:
        cmd += ["-vf", vf, "-map", "0:v", "-map", "0:a?"]
    cmd += ["-c:v", "libx264", "-preset", "medium", "-crf", "19", "-pix_fmt", "yuv420p", "-r", str(FPS),
            "-c:a", "aac", "-b:a", "160k", "-ar", "48000", "-ac", "2", "-shortest", str(out)]
    subprocess.run(cmd, check=True)


def still(png, out, dur, fade_in=True, fade_out=True):
    vf = "fps=%d,format=yuv420p" % FPS
    if fade_in:
        vf += ",fade=t=in:st=0:d=0.6"
    if fade_out:
        vf += ",fade=t=out:st=%.2f:d=0.6" % (dur - 0.6)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-loop", "1", "-t", "%.3f" % dur, "-i", str(png),
                    "-f", "lavfi", "-t", "%.3f" % dur, "-i", "anullsrc=r=48000:cl=stereo", "-vf", vf,
                    "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-pix_fmt", "yuv420p", "-r", str(FPS),
                    "-c:a", "aac", "-b:a", "160k", "-shortest", str(out)], check=True)


def assemble(parts, out, music_gain=0.32):
    """The parts one after another, with the menus' music under them all (fading in and out)."""
    lst = out.with_suffix(".txt")
    lst.write_text("".join("file '%s'\n" % p for p in parts))
    joined = out.with_name(out.stem + "_joined.mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy",
                    str(joined)], check=True)
    dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                                str(joined)], capture_output=True, text=True, check=True).stdout)
    music = ROOT / "assets" / "audio" / "menu_music.ogg"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(joined), "-stream_loop", "-1", "-i", str(music),
                    "-filter_complex",
                    "[1:a]aresample=48000,aformat=channel_layouts=stereo,volume=%.2f,afade=t=in:d=1.2,"
                    "afade=t=out:st=%.2f:d=2.0[m];[0:a]volume=1.0[g];[g][m]amix=inputs=2:duration=first:"
                    "normalize=0,alimiter=limit=0.95[a]" % (music_gain, dur - 2.0),
                    "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-t", "%.3f" % dur,
                    "-movflags", "+faststart", str(out)], check=True)
    joined.unlink()
    lst.unlink()
    return dur


def trailer(raw: pathlib.Path, out: pathlib.Path, tmp: pathlib.Path):
    avi = raw / "trailer.avi"
    mk = marks(raw / "trailer.log")
    print("trailer marks:", json.dumps(mk))
    tmp.mkdir(parents=True, exist_ok=True)
    out.mkdir(parents=True, exist_ok=True)
    ver = version().replace("-beta", "")
    card(tmp / "title.png", (W, H), "KABADDI RAID", ["Raid. Touch. Return.", "3D kabaddi for Android"])
    card(tmp / "end.png", (W, H), "KABADDI RAID", ["Coming soon to Google Play", "Offline  ·  No ads  ·  8 languages"],
         "Gameplay recorded in the game (version %s), on High graphics" % ver)
    caption(tmp / "c_grounds.png", (W, H), "FIVE GROUNDS", "From a village mud court to a floodlit stadium")
    caption(tmp / "c_modes.png", (W, H), "QUICK MATCH  ·  LEAGUE SEASON  ·  NATIONS CUP")
    caption(tmp / "c_auction.png", (W, H), "BUILD YOUR FRANCHISE", "Win the auction, pick your seven")
    caption(tmp / "c_rules.png", (W, H), "REAL KABADDI", "Touches, dubkis, ankle holds and chain tackles")
    caption(tmp / "c_offline.png", (W, H), "PLAYS OFFLINE", "No ads, no purchases, eight languages")
    hot = ["takedown", "escape", "hold", "touch", "point"]
    plan = [("title", None), ("stadium", "c_rules"), ("village", "c_grounds"), ("menu", "c_modes"),
            ("dome", None), ("auction", "c_auction"), ("beach", "c_offline"), ("monsoon", None), ("end", None)]
    parts = []
    for i, (what, cap) in enumerate(plan):
        p = tmp / ("p%02d_%s.mp4" % (i, what))
        if what in ["title", "end"]:
            still(tmp / (what + ".png"), p, 3.2 if what == "title" else 4.5)
        elif what in ["menu", "auction"]:
            a = mk.get(what + "_start")
            if a is None:
                continue
            segment(avi, p, a, min(3.0, mk.get(what + "_end", a + 3.0) - a), overlay=tmp / (cap + ".png"))
        else:
            w = moment(mk, what, hot, 1.8, 2.2)
            if w is None:
                continue
            segment(avi, p, w[0], w[1], overlay=(tmp / (cap + ".png")) if cap else None)
        parts.append(p)
    dur = assemble(parts, out / "kabaddi-raid-trailer-1080p.mp4")
    # The vertical cut: the middle of the picture, three raids, between cards made for the tall frame.
    vw, vh = 1080, 1920
    card(tmp / "v_title.png", (vw, vh), "KABADDI RAID", ["Raid. Touch. Return.", "3D kabaddi for Android"])
    card(tmp / "v_end.png", (vw, vh), "KABADDI RAID", ["Coming soon to Google Play", "Offline  ·  No ads"])
    vparts = []
    still(tmp / "v_title.png", tmp / "v0.mp4", 2.4, fade_out=False)
    vparts.append(tmp / "v0.mp4")
    for i, g in enumerate(["stadium", "dome", "beach"]):
        w = moment(mk, g, hot, 1.3, 1.7)
        if w:
            p = tmp / ("v%d.mp4" % (i + 1))
            segment(avi, p, w[0], min(w[1], 3.0), size=(vw, vh), crop="ih*9/16:ih")
            vparts.append(p)
    still(tmp / "v_end.png", tmp / "v9.mp4", 3.0, fade_in=False)
    vparts.append(tmp / "v9.mp4")
    vdur = assemble(vparts, out / "kabaddi-raid-trailer-vertical-15s.mp4")
    return dur, vdur


# ---------------------------------------------------------------- the kit

CREDITS = """Kabaddi Raid media kit: credits

Everything in this kit was captured from the game itself (version {version}), on High graphics.

Trailer audio
- Music: "Indian" by LNPLUSMUSIC (Pixabay track 611803), Pixabay Content License, https://pixabay.com/service/license-summary/
  (edited into the game's menu loop).
- Crowd murmur, cheers, rhythmic clapping and roars: "Free Crowd Cheering Sounds" by Gregor Quendel,
  https://opengameart.org/content/free-crowd-cheering-sounds, CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).
- Applause: "Applause in a large hall or church" by eXpl0it3r, OpenGameArt, CC0.
- Referee whistles: Pixabay 568615 (charlesheffley009), 291816 (framptones), 6121 and 6320 (freesound_community),
  Pixabay Content License.
- Footsteps, impacts and clicks: Kenney (kenney.nl, Impact Sounds, Interface Sounds), CC0; Fantozzi's footsteps
  (OpenGameArt), CC0.
- Rain, sea, birds and crickets: OpenGameArt (Kresiek The Furry, jasinski, Thimras, Wolfgang_), CC0.

Pictures and footage
- Grounds' skies, surfaces and props: Poly Haven (polyhaven.com), CC0.
- Players, referees and the crowd: modelled with Meshy for the game.
- Movement: Mixamo (Adobe), the CMU Graphics Lab Motion Capture Database (mocap.cs.cmu.edu) and match footage.
- Fonts: Teko and Noto Sans, SIL Open Font License 1.1.
- Made with the Godot Engine (godotengine.org), MIT licence.

The full list, with every file, is in the game: Settings > About > Licences.
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--contact", default="(the developer's contact email)")
    ap.add_argument("--store", action="store_true", help="also make the Play store's pictures again")
    ap.add_argument("--skip-render", action="store_true")
    a = ap.parse_args()
    out = pathlib.Path(a.out).resolve()
    raw = out / "raw"
    raw.mkdir(parents=True, exist_ok=True)
    if not a.skip_render:
        render(raw, a.store)
    kit = out / "media-kit-kabaddi-raid"
    shutil.rmtree(kit, ignore_errors=True)
    for d in ["screenshots", "menus", "icons", "trailer", "text"]:
        (kit / d).mkdir(parents=True)
    for p in sorted((raw / "shots").glob("*.png")):
        shutil.copy(p, kit / "screenshots" / p.name)
    for p in sorted((raw / "menus").glob("*.png")):
        shutil.copy(p, kit / "menus" / p.name)
    icons(kit / "icons")
    ver = version()
    for p in sorted((ROOT / "store" / "media" / "text").glob("*.md")):
        (kit / "text" / p.name).write_text(p.read_text().replace("{{VERSION}}", ver).replace("{{CONTACT}}", a.contact))
    dur, vdur = trailer(raw, kit / "trailer", out / "tmp")
    (kit / "CREDITS.txt").write_text(CREDITS.format(version=ver))
    zp = out / "media-kit-kabaddi-raid.zip"
    with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(kit.rglob("*")):
            if p.is_file():
                z.write(p, p.relative_to(out))
    print("trailer %.1f s, vertical %.1f s; %s: %.1f MB" % (dur, vdur, zp, zp.stat().st_size / 1e6))


if __name__ == "__main__":
    main()

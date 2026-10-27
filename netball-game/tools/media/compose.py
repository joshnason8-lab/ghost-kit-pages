#!/usr/bin/env python3
"""The media kit's steps that are not Godot's: picking the trailer's moments from the scanned matches, the icons, the
title and end cards and captions, cutting and mixing the trailer (landscape and a vertical cut), the credits and the
zip. tools/media/make_media_kit.sh runs these in order; each is a subcommand:

  compose.py venues                 the matches to scan: "venue home away seed frames" lines
  compose.py plan WORK              WORK/scan_<venue>/events.json -> WORK/plan.json; prints "venue last windows" lines
  compose.py check WORK             the shot matches played as scanned (same events at the same frames)
  compose.py icons OUT              OUT/icons: the icon at 1024 and 512, the 1024x500 feature graphic
  compose.py screens SRC OUT        SRC/media_*.png -> OUT/screenshots, SRC/menu_*.png -> OUT/menus (RGB PNGs)
  compose.py text OUT               tools/media/text/*.md -> OUT/text (the version filled in from project.godot)
  compose.py trailer WORK OUT       OUT/trailer: the trailer (1920x1080) and the vertical cut (1080x1920)
  compose.py credits OUT            OUT/CREDITS.txt
  compose.py zip OUT                OUT/media-kit-netball-unleashed.zip

Needs Pillow and ffmpeg (with libx264, and drawtext not needed: the words are drawn here with the game's fonts).
"""
import json
import pathlib
import shutil
import subprocess
import sys
import zipfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
FPS = 30
BIG = ROOT / "fonts" / "BarlowCondensed-ExtraBold.ttf"
SEMI = ROOT / "fonts" / "BarlowCondensed-SemiBold.ttf"
NAVY = (10, 22, 58)
ORANGE = (255, 140, 40)
INK = (246, 243, 255)
LIME = (214, 245, 66)
AUDIO = ROOT / "assets" / "audio"
ZIP_NAME = "media-kit-netball-unleashed.zip"

# The matches played for the trailer: AI v AI on High, one in each venue (seeded: the same play every time).
VENUES = {"arena": ("AUS", "NZL", 5), "hall": ("ENG", "WAL", 7), "outdoor": ("MWI", "UGA", 5)}
SCAN_FRAMES = 4500   # two and a half minutes of each match

# The trailer's play, in order: a shot ending in a goal (or a miss), from `lead` frames before the shot to `tail`
# frames after the ball drops. "nth" counts that venue's goals (misses) from 0. A miss falls back to a goal.
CLIPS = [
    {"venue": "arena", "event": "goal", "nth": 0, "lead": 90, "tail": 50},
    {"venue": "hall", "event": "goal", "nth": 0, "lead": 75, "tail": 55, "caption": "Three venues"},
    {"venue": "outdoor", "event": "goal", "nth": 0, "lead": 70, "tail": 45},
    {"venue": ["hall", "arena", "outdoor"], "event": "miss", "nth": 0, "lead": 70, "tail": 42},
    {"venue": "arena", "event": "goal", "nth": 2, "lead": 40, "tail": 85, "caption": "Play offline"},
]
TITLE_S = 3.5
STILL_S = 3.5
END_S = 4.5
STILL_CAPTION = "Nations Cup · Club Season"
# The vertical cut (15 s): the title, three goals from the clips above (by index), the end card.
V_TITLE_S = 2.4
V_END_S = 2.4
V_SHOTS = [(0, "Play offline"), (1, "Three venues"), (4, "Nations Cup · Club Season")]
V_SHOT_FRAMES = 102
V_BEFORE_GOAL = 56

# Sounds mixed into the trailers: only the game's own, CC0 and CC-BY 4.0 sounds (credited in CREDITS.txt); none of
# the CC-BY-SA beds, so the trailer's soundtrack carries no share-alike terms.
MUSIC = AUDIO / "menu_music.ogg"
CHEER = {"arena": AUDIO / "crowd_cheer.ogg", "hall": AUDIO / "crowd_cheer_small.ogg", "outdoor": AUDIO / "crowd_cheer_small.ogg"}
SWISH = AUDIO / "swish.ogg"
RIM = AUDIO / "rim.ogg"
GROAN = AUDIO / "crowd_groan.ogg"
AMB_ARENA = AUDIO / "amb_arena.ogg"
WHISTLE = AUDIO / "whistle_long_1.ogg"


def font(path, size):
    return ImageFont.truetype(str(path), size)


def run(cmd):
    print("+", " ".join(str(c) for c in cmd[:6]), "..." if len(cmd) > 6 else "", flush=True)
    subprocess.run([str(c) for c in cmd], check=True)


def ffmpeg(*args):
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args])


# ---------------------------------------------------------------- the plan

def cmd_venues():
    for v, (h, a, s) in VENUES.items():
        print(v, h, a, s, SCAN_FRAMES)


def _events(work, v, sub="scan"):
    return json.loads((work / f"{sub}_{v}" / "events.json").read_text())["events"]


def _find(events, kind, nth):
    """The nth event of this kind, with the shot that led to it: (shot frame, event frame) or None."""
    n = 0
    last_shot = None
    for e in events:
        if e["kind"] == "shot_start":
            last_shot = e["frame"]
        elif e["kind"] == kind and last_shot is not None:
            if n == nth:
                return last_shot, e["frame"]
            n += 1
    return None


def cmd_plan(work):
    events = {v: _events(work, v) for v in VENUES}
    clips = []
    for c in CLIPS:
        venues = c["venue"] if isinstance(c["venue"], list) else [c["venue"]]
        hit = None
        for v in venues:
            f = _find(events[v], c["event"], c["nth"])
            if f:
                hit = (v, c["event"], f)
                break
        if hit is None:   # no miss in any match: another goal
            v = venues[0]
            used = sum(1 for k in clips if k["venue"] == v and k["event"] == "goal")
            f = _find(events[v], "goal", used + 1)
            if f is None:
                sys.exit(f"plan: no {c['event']} in {venues} to cut")
            hit = (v, "goal", f)
        v, kind, (shot, ev) = hit
        first = max(4, shot - c["lead"])
        last = ev + c["tail"]
        clips.append({"venue": v, "event": kind, "shot": shot, "at": ev, "first": first, "last": last,
                      "caption": c.get("caption", "")})
    (work / "plan.json").write_text(json.dumps({"clips": clips}, indent=1))
    for v in VENUES:
        ws = [f"{k['first']}-{k['last']}" for k in clips if k["venue"] == v]
        if ws:
            last = max(k["last"] for k in clips if k["venue"] == v) + 2
            print(v, last, ",".join(ws))
    total = TITLE_S + STILL_S + END_S + sum((k["last"] - k["first"] + 1) / FPS for k in clips)
    print(f"# trailer: {len(clips)} clips, {total:.1f} s", file=sys.stderr)


def cmd_check(work):
    bad = 0
    plan = json.loads((work / "plan.json").read_text())
    for v in {k["venue"] for k in plan["clips"]}:
        a = _events(work, v, "scan")
        b = _events(work, v, "shoot")
        n = min(len(a), len(b))
        if a[:n] != b[:n] or n == 0:
            print(f"check: {v}: the shot match did not play as scanned", file=sys.stderr)
            bad += 1
        for k in plan["clips"]:
            if k["venue"] == v:
                missing = [f for f in range(k["first"], k["last"] + 1)
                           if not (work / f"shoot_{v}" / f"f_{f:06d}.jpg").exists()]
                if missing:
                    print(f"check: {v}: {len(missing)} frames missing", file=sys.stderr)
                    bad += 1
    print("check:", "ok" if not bad else f"{bad} problems")
    return 1 if bad else 0


# ---------------------------------------------------------------- icons and screenshots

def cmd_icons(out):
    d = out / "icons"
    d.mkdir(parents=True, exist_ok=True)
    src = Image.open(ROOT / "store" / "graphics" / "icon-source.jpg").convert("RGB")
    side = min(src.size)
    src = src.crop(((src.width - side) // 2, (src.height - side) // 2, (src.width + side) // 2, (src.height + side) // 2))
    # The artwork is a full square picture (no transparent edge to keep), so the icons are opaque.
    src.resize((1024, 1024), Image.LANCZOS).save(d / "icon-1024.png")
    src.resize((512, 512), Image.LANCZOS).save(d / "icon-512.png")
    shutil.copy(ROOT / "store" / "graphics" / "feature-1024x500.png", d / "feature-graphic-1024x500.png")
    print("icons:", sorted(p.name for p in d.iterdir()))


def cmd_screens(src, out):
    d = out / "screenshots"
    d.mkdir(parents=True, exist_ok=True)
    n = 0
    for p in sorted(src.glob("media_*.png")):
        name = p.name.replace("media_", "netball-unleashed-")
        Image.open(p).convert("RGB").save(d / name, optimize=True)
        n += 1
    if n < 8:
        sys.exit(f"screens: only {n} screenshots")
    d = out / "menus"
    d.mkdir(parents=True, exist_ok=True)
    m = 0
    for p in sorted(src.glob("menu_*.png")):
        Image.open(p).convert("RGB").save(d / p.name.replace("menu_", "", 1), optimize=True)
        m += 1
    if m < 18:
        sys.exit(f"screens: only {m} menu pictures")
    print("screenshots:", n, "menus:", m)


def version():
    for line in (ROOT / "project.godot").read_text().splitlines():
        if line.startswith("config/version="):
            return line.split("=", 1)[1].strip().strip('"')
    return "unknown"


def cmd_text(out):
    d = out / "text"
    d.mkdir(parents=True, exist_ok=True)
    for p in sorted((ROOT / "tools" / "media" / "text").glob("*.md")):
        (d / p.name).write_text(p.read_text().replace("{{VERSION}}", version()))
    print("text:", sorted(p.name for p in d.iterdir()))


# ---------------------------------------------------------------- cards and captions

def _art(size):
    art = Image.open(ROOT / "store" / "graphics" / "icon-source.jpg").convert("RGBA")
    return art.resize((size, size), Image.LANCZOS)


def _title_words(d, x, y, size, center_w=None):
    """NETBALL in white, UNLEASHED in orange, on one line (centred in center_w when given)."""
    f = font(BIG, size)
    w1 = d.textlength("NETBALL ", font=f)
    w2 = d.textlength("UNLEASHED", font=f)
    if center_w is not None:
        x = (center_w - (w1 + w2)) / 2
    d.text((x, y), "NETBALL ", font=f, fill=INK)
    d.text((x + w1, y), "UNLEASHED", font=f, fill=ORANGE)


def _centred(d, w, y, text, f, fill):
    d.text(((w - d.textlength(text, font=f)) / 2, y), text, font=f, fill=fill)


def title_card(w, h):
    img = Image.new("RGBA", (w, h), NAVY + (255,))
    if w > h:
        art = _art(h + 80)
        img.alpha_composite(art, (w - art.width + 40, -40))
        shade = Image.new("RGBA", img.size)
        sd = ImageDraw.Draw(shade)
        edge = w - art.width + 40
        for x in range(w):
            a = int(min(1.0, max(0.0, (edge + 520 - x) / 520.0)) ** 1.4 * 255)
            sd.line([(x, 0), (x, h)], fill=NAVY + (a,))
        img.alpha_composite(shade)
        d = ImageDraw.Draw(img)
        big = font(BIG, 230)
        d.text((120, 250), "NETBALL", font=big, fill=INK)
        d.text((120, 470), "UNLEASHED", font=big, fill=ORANGE)
        d.text((128, 760), "The real rules of netball. Nineteen languages.", font=font(SEMI, 64), fill=INK)
    else:
        art = _art(w)
        img.alpha_composite(art, (0, 560))
        shade = Image.new("RGBA", img.size)
        sd = ImageDraw.Draw(shade)
        for y in range(h):
            top = min(1.0, max(0.0, (800 - y) / 240.0))
            bot = min(1.0, max(0.0, (y - 1380) / 260.0))
            sd.line([(0, y), (w, y)], fill=NAVY + (int(max(top, bot) ** 1.2 * 255),))
        img.alpha_composite(shade)
        d = ImageDraw.Draw(img)
        big = font(BIG, 210)
        _centred(d, w, 120, "NETBALL", big, INK)
        _centred(d, w, 320, "UNLEASHED", big, ORANGE)
        _centred(d, w, 1690, "The real rules of netball.", font(SEMI, 76), INK)
    return img.convert("RGB")


def end_card(w, h):
    img = Image.new("RGBA", (w, h), NAVY + (255,))
    d = ImageDraw.Draw(img)
    portrait = h > w
    icon = 420 if portrait else 330
    top = 470 if portrait else 150
    art = _art(icon)
    mask = Image.new("L", (icon, icon), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, icon - 1, icon - 1], radius=icon // 5, fill=255)
    img.paste(art, ((w - icon) // 2, top), mask)
    if portrait:
        big = font(BIG, 190)
        _centred(d, w, top + icon + 80, "NETBALL", big, INK)
        _centred(d, w, top + icon + 270, "UNLEASHED", big, ORANGE)
        _centred(d, w, top + icon + 560, "Coming soon", font(BIG, 110), LIME)
        _centred(d, w, top + icon + 690, "to Google Play", font(SEMI, 96), INK)
    else:
        _title_words(d, 0, top + icon + 60, 170, center_w=w)
        _centred(d, w, top + icon + 290, "Coming soon to Google Play", font(SEMI, 96), LIME)
    return img.convert("RGB")


def caption_landscape(text, w=1920, h=1080):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = font(BIG, 96)
    tw = d.textlength(text.upper(), font=f)
    x, y, ph = 96, h - 96 - 150, 150
    d.rounded_rectangle([x, y, x + tw + 96, y + ph], radius=22, fill=NAVY + (215,))
    d.rectangle([x, y + 22, x + 14, y + ph - 22], fill=ORANGE)
    d.text((x + 50, y + 18), text.upper(), font=f, fill=INK)
    return img


def caption_vertical(text, w=1080, h=1920):
    """Big words above the picture, the game's name below it."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    size = 150
    f = font(BIG, size)
    lines = text.upper().split(" · ") if "·" in text else [text.upper()]
    while max(d.textlength(t, font=f) for t in lines) > w - 120:
        size -= 6
        f = font(BIG, size)
    y = 420 - len(lines) * (size + 10) // 2
    for t in lines:
        tw = d.textlength(t, font=f)
        d.rounded_rectangle([(w - tw) / 2 - 36, y - 6, (w + tw) / 2 + 36, y + size + 14], radius=24, fill=NAVY + (200,))
        d.text(((w - tw) / 2, y - 4), t, font=f, fill=INK)
        y += size + 44
    _title_words(d, 0, 1500, 120, center_w=w)
    return img


# ---------------------------------------------------------------- the trailer

def _enc(fast=True):
    return ["-c:v", "libx264", "-preset", "veryfast" if fast else "slow", "-crf", "14" if fast else "19",
            "-pix_fmt", "yuv420p", "-r", str(FPS)]


def _still(img_path, secs, out, zoom=False, size=(1920, 1080)):
    w, h = size
    fades = f"fade=t=in:st=0:d=0.35,fade=t=out:st={secs - 0.35:.2f}:d=0.35"
    if zoom:   # a slow push in on a screenshot
        vf = (f"scale={w * 2}:{h * 2},zoompan=z='1+0.06*on/{int(secs * FPS)}':d=1:x='iw/2-(iw/zoom/2)'"
              f":y='ih/2-(ih/zoom/2)':s={w}x{h}:fps={FPS},{fades}")
    else:
        vf = fades
    ffmpeg("-loop", "1", "-framerate", str(FPS), "-t", f"{secs}", "-i", img_path, "-vf", vf + ",format=yuv420p",
           "-frames:v", str(int(round(secs * FPS))), *_enc(), out)


def _still_caption(img_path, cap_path, secs, out):
    n = int(round(secs * FPS))
    flt = (f"[0:v]scale=3840:2160,zoompan=z='1+0.06*on/{n}':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'"
           f":s=1920x1080:fps={FPS}[b];"
           f"[1:v]format=rgba,fade=t=in:st=0.4:d=0.35:alpha=1[c];"
           f"[b][c]overlay=0:0,fade=t=in:st=0:d=0.35,fade=t=out:st={secs - 0.35:.2f}:d=0.35,format=yuv420p[v]")
    ffmpeg("-loop", "1", "-framerate", str(FPS), "-t", f"{secs}", "-i", img_path,
           "-loop", "1", "-framerate", str(FPS), "-t", f"{secs}", "-i", cap_path,
           "-filter_complex", flt, "-map", "[v]", "-frames:v", str(n), *_enc(), out)


def _play(work, clip, first, n, out, cap_path=None, vertical=False):
    secs = n / FPS
    src = ["-framerate", str(FPS), "-start_number", str(first), "-i", work / f"shoot_{clip['venue']}" / "f_%06d.jpg"]
    if vertical:
        base = ("[0:v]split[a][b];[a]scale=-2:1920,crop=1080:1920,gblur=sigma=28,eq=brightness=-0.12[bg];"
                "[b]crop=1350:1080:285:0,scale=1080:864[fg];[bg][fg]overlay=0:528[p]")
    else:
        base = "[0:v]null[p]"
    if cap_path:
        src += ["-loop", "1", "-framerate", str(FPS), "-t", f"{secs}", "-i", cap_path]
        cap = (f";[1:v]format=rgba,fade=t=in:st=0.35:d=0.3:alpha=1,fade=t=out:st={secs - 0.75:.2f}:d=0.3:alpha=1[c];"
               f"[p][c]overlay=0:0[q]")
    else:
        cap = ";[p]null[q]"
    flt = base + cap + f";[q]fade=t=in:st=0:d=0.2,fade=t=out:st={secs - 0.2:.2f}:d=0.2,format=yuv420p[v]"
    ffmpeg(*src, "-filter_complex", flt, "-map", "[v]", "-frames:v", str(n), *_enc(), out)


def _concat(parts, out):
    lst = out.with_suffix(".txt")
    lst.write_text("".join(f"file '{p.resolve()}'\n" for p in parts))
    ffmpeg("-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", out)


def _mix(video, total, sounds, out, ambience=()):
    """The music under it all, the game's sounds at their moments: sounds = [(path, at_seconds, volume)];
    ambience = [(path, start, secs, volume)] looped beds. Encoded for delivery (H.264 high, AAC, faststart)."""
    args = ["-i", video, "-i", MUSIC]
    parts = [f"[1:a]aloop=loop=-1:size=2147483647,atrim=0:{total:.3f},aresample=48000,"
             f"aformat=channel_layouts=stereo,afade=t=in:d=0.8,afade=t=out:st={total - 2.5:.3f}:d=2.5,volume=0.55[m]"]
    labels = ["[m]"]
    i = 2
    for path, start, secs, vol in ambience:
        args += ["-stream_loop", "-1", "-i", path]
        ms = int(start * 1000)
        parts.append(f"[{i}:a]atrim=0:{secs:.3f},aresample=48000,aformat=channel_layouts=stereo,"
                     f"afade=t=in:d=0.3,afade=t=out:st={secs - 0.3:.3f}:d=0.3,volume={vol},adelay={ms}|{ms}[s{i}]")
        labels.append(f"[s{i}]")
        i += 1
    for path, at, vol in sounds:
        args += ["-i", path]
        ms = max(0, int(at * 1000))
        parts.append(f"[{i}:a]aresample=48000,aformat=channel_layouts=stereo,volume={vol},adelay={ms}|{ms}[s{i}]")
        labels.append(f"[s{i}]")
        i += 1
    parts.append("".join(labels) + f"amix=inputs={len(labels)}:normalize=0:duration=first,"
                 f"atrim=0:{total:.3f},alimiter=limit=0.9[a]")
    ffmpeg(*args, "-filter_complex", ";".join(parts), "-map", "0:v", "-map", "[a]",
           "-c:v", "libx264", "-preset", "slow", "-crf", "19", "-maxrate", "10M", "-bufsize", "20M",
           "-profile:v", "high", "-pix_fmt", "yuv420p", "-r", str(FPS),
           "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-movflags", "+faststart", "-t", f"{total:.3f}", out)


def _clip_sounds(clip, t0, first):
    """The goal's swish and cheer (or the miss's ring and groan), at their time in the cut starting at t0."""
    at = t0 + (clip["at"] - first) / FPS
    if clip["event"] == "goal":
        return [(SWISH, at - 0.05, 1.0), (CHEER[clip["venue"]], at + 0.05, 0.9)]
    return [(RIM, at - 0.05, 1.0), (GROAN, at + 0.15, 0.9)]


def cmd_trailer(work, out):
    plan = json.loads((work / "plan.json").read_text())["clips"]
    tdir = out / "trailer"
    tdir.mkdir(parents=True, exist_ok=True)
    seg = work / "segments"
    seg.mkdir(parents=True, exist_ok=True)
    # The cards and captions.
    title_card(1920, 1080).save(seg / "title.png")
    end_card(1920, 1080).save(seg / "end.png")
    title_card(1080, 1920).save(seg / "v_title.png")
    end_card(1080, 1920).save(seg / "v_end.png")
    caption_landscape(STILL_CAPTION).save(seg / "cap_still.png")
    home = out / "screenshots" / "netball-unleashed-08_home.png"
    if not home.exists():
        home = sorted((out / "screenshots").glob("*home*.png"))[0]

    # The landscape trailer.
    parts, sounds, amb = [], [], []
    t = 0.0
    _still(seg / "title.png", TITLE_S, seg / "00_title.mp4")
    parts.append(seg / "00_title.mp4")
    sounds.append((WHISTLE, TITLE_S - 0.6, 0.55))
    t += TITLE_S
    for i, clip in enumerate(plan):
        n = clip["last"] - clip["first"] + 1
        cap = None
        if clip["caption"]:
            cap = seg / f"cap_{i}.png"
            caption_landscape(clip["caption"]).save(cap)
        p = seg / f"{i + 1:02d}_{clip['venue']}.mp4"
        _play(work, clip, clip["first"], n, p, cap)
        parts.append(p)
        sounds += _clip_sounds(clip, t, clip["first"])
        if clip["venue"] == "arena":
            amb.append((AMB_ARENA, t, n / FPS, 0.45))
        t += n / FPS
    _still_caption(home, seg / "cap_still.png", STILL_S, seg / "90_still.mp4")
    parts.append(seg / "90_still.mp4")
    t += STILL_S
    _still(seg / "end.png", END_S, seg / "99_end.mp4")
    parts.append(seg / "99_end.mp4")
    t += END_S
    _concat(parts, seg / "landscape.mp4")
    _mix(seg / "landscape.mp4", t, sounds, tdir / "netball-unleashed-trailer-1080p.mp4", amb)

    # The vertical cut, 15 s.
    parts, sounds = [], []
    t = 0.0
    _still(seg / "v_title.png", V_TITLE_S, seg / "v00_title.mp4", size=(1080, 1920))
    parts.append(seg / "v00_title.mp4")
    t += V_TITLE_S
    for j, (ci, text) in enumerate(V_SHOTS):
        clip = plan[ci]
        first = max(clip["first"], clip["at"] - V_BEFORE_GOAL)
        n = min(V_SHOT_FRAMES, clip["last"] - first + 1)
        cap = seg / f"v_cap_{j}.png"
        caption_vertical(text).save(cap)
        p = seg / f"v{j + 1:02d}.mp4"
        _play(work, clip, first, n, p, cap, vertical=True)
        parts.append(p)
        sounds += _clip_sounds(clip, t, first)
        t += n / FPS
    _still(seg / "v_end.png", V_END_S, seg / "v99_end.mp4", size=(1080, 1920))
    parts.append(seg / "v99_end.mp4")
    t += V_END_S
    _concat(parts, seg / "vertical.mp4")
    _mix(seg / "vertical.mp4", t, sounds, tdir / "netball-unleashed-vertical-15s.mp4")
    for p in sorted(tdir.glob("*.mp4")):
        print(f"trailer: {p.name} {p.stat().st_size / 1e6:.1f} MB")


# ---------------------------------------------------------------- credits and zip

CREDITS = """Netball Unleashed: media kit
=============================

Netball Unleashed is made by Josh Nason. Everything in this kit is from the game itself: the screenshots and the
trailers' play are the game running (AI v AI matches on High graphics, recorded frame by frame), the icons and the
feature graphic are the game's own artwork.

Free to use in articles, videos and on websites about the game. Please do not alter the logo or icon artwork.

Contents
--------
screenshots/   1920x1080 PNGs: play in the three venues (the arena, the sports hall, the outdoor park court), the
               team card, the home screen, quick setup, the Nations Cup, How to Play and a result
menus/         1920x1080 PNGs of every menu screen in English, named by screen (a screen that scrolls has a picture
               for each page: _2, _3...)
text/          website copy (Markdown): about.md, features.md, facts.md, sport.md, press.md
icons/         icon-1024.png, icon-512.png (the game's icon artwork, opaque), feature-graphic-1024x500.png
trailer/       netball-unleashed-trailer-1080p.mp4 (1920x1080, 30 fps, H.264 + AAC)
               netball-unleashed-vertical-15s.mp4 (1080x1920, 15 s, for social media)

Made with
---------
Godot Engine (godotengine.org): MIT License. Copyright (c) 2014-present Godot Engine contributors; (c) 2007-2014
Juan Linietsky, Ariel Manzur.

The players: Josh Nason's own 3D model, made with Meshy (meshy.ai), rigged and animated with Mixamo (Adobe,
mixamo.com) under Mixamo's terms. Motion capture data from mocap.cs.cmu.edu (the database was created with funding
from NSF EIA-0196217); clips 102_27 and 16_08 in Bruce Hahne's BVH conversion.
Umpires, venues, crowd, ball and flags: made in code for the game. Venue models by Josh Nason, made with Meshy.
Poly Haven (polyhaven.com), CC0: the skies, floor and wall textures, trees, benches, hall lights, clock, signs and
street lamps.

Fonts (the game's, and the words on the cards and captions): Barlow Condensed, Copyright 2017 The Barlow Project
Authors (github.com/jpt/barlow); Noto Sans, Copyright The Noto Project Authors (github.com/notofonts). SIL Open Font
License 1.1.

Sound in the trailers
---------------------
Music: "Netball Unleashed" menu music, written for the game by Josh Nason (the game's own).
Crowd cheers and the arena's crowd: Gregor Quendel, "Free Crowd Cheering Sounds"
  (opengameart.org/content/free-crowd-cheering-sounds), CC-BY 4.0 (creativecommons.org/licenses/by/4.0).
The ball through the net and off the ring: Kenney (kenney.nl), RPG Audio and Impact Sounds, CC0.
The crowd's groan: from Kabaddi Raid, by Josh Nason (the game's own).
The umpire's whistle: "Referee whistle" by charlesheffley009, Pixabay (pixabay.com), Pixabay Content License.

The game's other sounds (not in the trailers) and their licences are listed in the game's Licences screen and in
docs/SOUNDS.md.

"Google Play" is a trademark of Google LLC.
"""


def cmd_credits(out):
    out.mkdir(parents=True, exist_ok=True)
    (out / "CREDITS.txt").write_text(CREDITS)


def cmd_zip(out):
    z = out / ZIP_NAME
    if z.exists():
        z.unlink()
    with zipfile.ZipFile(z, "w", zipfile.ZIP_DEFLATED) as zf:
        for sub in ["screenshots", "menus", "icons", "trailer", "text"]:
            for p in sorted((out / sub).iterdir()):
                # PNGs and MP4s are compressed already: stored as they are.
                zf.write(p, f"{sub}/{p.name}",
                         compress_type=zipfile.ZIP_DEFLATED if p.suffix == ".md" else zipfile.ZIP_STORED)
        zf.write(out / "CREDITS.txt", "CREDITS.txt")
    print(f"zip: {z} {z.stat().st_size / 1e6:.1f} MB")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd, args = sys.argv[1], [pathlib.Path(a) for a in sys.argv[2:]]
    if cmd == "venues":
        cmd_venues()
    elif cmd == "plan":
        cmd_plan(args[0])
    elif cmd == "check":
        sys.exit(cmd_check(args[0]))
    elif cmd == "icons":
        cmd_icons(args[0])
    elif cmd == "screens":
        cmd_screens(args[0], args[1])
    elif cmd == "text":
        cmd_text(args[0])
    elif cmd == "trailer":
        cmd_trailer(args[0], args[1])
    elif cmd == "credits":
        cmd_credits(args[0])
    elif cmd == "zip":
        cmd_zip(args[0])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()

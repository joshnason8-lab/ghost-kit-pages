#!/usr/bin/env python3
"""The media kit's trailer (about 40 s, 1920 x 1080) and its 15 s vertical cut (1080 x 1920), from the game's own
footage (tests/trailer_rec.tscn, which writes the film and a list of its moments):

    python3 tools/store/make_trailer.py FOOTAGE.avi FOOTAGE.json OUT_DIR     (needs ffmpeg and Pillow)

A title card, six moments from the four grounds (a dive, a pole turn, an out, a kho...) with two captions, and an end
card. The sound is the game's own, with its menu music under it (written for the game: tools/audio/make_music.py).
H.264 and AAC, for any phone or site.
"""
import json
import pathlib
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
FONT = str(ROOT / "fonts" / "Baloo2.ttf")
BODY = str(ROOT / "fonts" / "NotoSans.ttf")
MUSIC = str(ROOT / "assets" / "audio" / "menu_music.ogg")
CREAM, SAFFRON, GOLD, INK = (247, 239, 226), (255, 176, 32), (255, 217, 122), (20, 12, 10)
# The moments, in order: (ground, kind, caption). Each clip starts LEAD s before its moment and runs CLIP s.
PLAN = [("maidan", "kho", ""), ("school", "pole_turn", "Swing round the pole"), ("school", "dive", "Dive for the tag"),
        ("floodlit", "pole_dive", ""), ("arena", "out", ""), ("maidan", "out", "")]
VERTICAL = [("school", "dive"), ("floodlit", "pole_turn"), ("arena", "out")]
FALLBACK = ["dive", "pole_turn", "out", "kho", "swerve", "pole_dive"]
LEAD, CLIP, VCLIP = 1.6, 4.6, 3.8


def run(args: list) -> None:
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"] + args, check=True)


def card(path: pathlib.Path, bg: Image.Image, size: tuple, lines: list) -> None:
    """A still: a frame of the game, darkened, with the lines (text, font, size, colour) set in the middle."""
    w, h = size
    s = max(w / bg.width, h / bg.height)
    img = bg.resize((int(bg.width * s) + 1, int(bg.height * s) + 1), Image.LANCZOS)
    img = img.crop(((img.width - w) // 2, (img.height - h) // 2, (img.width - w) // 2 + w, (img.height - h) // 2 + h))
    img = Image.blend(img.convert("RGB"), Image.new("RGB", size, INK), 0.62)
    d = ImageDraw.Draw(img)
    fonts = [(ImageFont.truetype(f, int(px * w / 1920 if w > h else px * w / 1080)), t, c) for t, f, px, c in lines]
    total = sum(f.getbbox(t)[3] + 24 for f, t, _ in fonts)
    y = (h - total) // 2
    for f, t, c in fonts:
        box = d.textbbox((0, 0), t, font=f)
        d.text(((w - box[2]) // 2, y), t, font=f, fill=c, stroke_width=3, stroke_fill=INK)
        y += box[3] + 24
    img.save(path)


def still(png: pathlib.Path, out: pathlib.Path, secs: float, size: tuple) -> None:
    run(["-loop", "1", "-t", str(secs), "-i", str(png), "-f", "lavfi", "-t", str(secs), "-i",
         "anullsrc=r=48000:cl=stereo", "-vf", f"scale={size[0]}:{size[1]},fade=in:0:12,fade=out:st={secs - 0.4}:d=0.4,"
         "format=yuv420p,fps=30", "-c:v", "libx264", "-crf", "18", "-c:a", "aac", "-shortest", str(out)])


def clip(src: str, t: float, secs: float, out: pathlib.Path, vf: str, caption: str, size: tuple) -> None:
    f = vf
    if caption:
        fs = int(size[0] / 22) if size[0] > size[1] else int(size[0] / 13)
        f += (f",drawtext=fontfile={FONT}:text='{caption}':fontsize={fs}:fontcolor=0xF7EFE2:borderw=4:bordercolor=0x140C0A"
              f":x=(w-text_w)/2:y=h*0.80:alpha='min(1,max(0,(t-0.3)*3))'")
    f += f",fade=in:0:6,fade=out:st={secs - 0.25}:d=0.25,format=yuv420p,fps=30"
    run(["-ss", f"{max(0.0, t):.3f}", "-t", str(secs), "-i", src, "-vf", f, "-af",
         f"afade=in:0:d=0.2,afade=out:st={secs - 0.3}:d=0.3,aresample=48000", "-ac", "2", "-c:v", "libx264", "-crf",
         "18", "-c:a", "aac", str(out)])


def pick(events: list, plan: list, used: set) -> list:
    """Each planned moment's time: the first such moment on that ground not yet used and with room before and after
    it (or another kind on that ground)."""
    ends = {e["ground"]: e["t"] for e in events if e["kind"] == "end"}
    starts, prev = {}, 0.0
    for e in events:
        if e["kind"] == "end":
            starts[e["ground"]] = prev
            prev = e["t"]
    picks = []
    for g, kind, *rest in plan:
        found = None
        for k in [kind] + FALLBACK:
            for e in events:
                if (e["ground"] == g and e["kind"] == k and e["t"] - LEAD > starts[g] + 2.0 and e["t"] + CLIP - LEAD
                        < ends[g] and all(abs(e["t"] - u) > CLIP for u in used)):
                    found = e["t"]
                    break
            if found is not None:
                break
        if found is None:
            print(f"no moment on {g}; skipped")
            continue
        used.add(found)
        picks.append((found, rest[0] if rest else ""))
    return picks


def join(parts: list, out: pathlib.Path, work: pathlib.Path, total: float) -> None:
    lst = work / (out.stem + ".txt")
    lst.write_text("".join(f"file '{p}'\n" for p in parts))
    cut = work / (out.stem + "_cut.mp4")
    run(["-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(cut)])
    # The menu music under the game's sound, faded in and out over the whole film.
    run(["-i", str(cut), "-stream_loop", "-1", "-i", MUSIC, "-filter_complex",
         f"[1:a]volume=0.45,afade=in:0:d=1.5,afade=out:st={total - 2.0}:d=2.0,atrim=0:{total}[m];"
         "[0:a][m]amix=inputs=2:duration=first:normalize=0[a]", "-map", "0:v", "-map", "[a]", "-c:v", "libx264",
         "-crf", "21", "-maxrate", "11M", "-bufsize", "22M", "-preset", "slow", "-profile:v", "high", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
         "-movflags", "+faststart", str(out)])


def main() -> int:
    src, events, out = sys.argv[1], json.loads(pathlib.Path(sys.argv[2]).read_text()), pathlib.Path(sys.argv[3])
    work = out / "work"
    work.mkdir(parents=True, exist_ok=True)
    frame = work / "frame.png"
    first = next(t for t, _ in pick(events, [("maidan", "kho")], set()))
    run(["-ss", f"{first:.2f}", "-i", src, "-frames:v", "1", str(frame)])
    bg = Image.open(frame)
    title = [("Kho Kho Rush", FONT, 150, CREAM), ("खो-खो", FONT, 90, SAFFRON), ("India's chasing game", BODY, 40, GOLD)]
    end = [("Kho Kho Rush", FONT, 140, CREAM), ("Coming soon to Google Play", BODY, 48, GOLD)]

    # The landscape trailer.
    size = (1920, 1080)
    parts = []
    card(work / "title.png", bg, size, title)
    still(work / "title.png", work / "a0.mp4", 3.0, size)
    parts.append(work / "a0.mp4")
    for i, (t, cap) in enumerate(pick(events, PLAN, set())):
        clip(src, t - LEAD, CLIP, work / f"a{i + 1}.mp4", "scale=1920:1080", cap, size)
        parts.append(work / f"a{i + 1}.mp4")
    card(work / "end.png", bg, size, end)
    still(work / "end.png", work / "a9.mp4", 4.0, size)
    parts.append(work / "a9.mp4")
    total = 3.0 + CLIP * (len(parts) - 2) + 4.0
    join(parts, out / "kho-kho-rush-trailer.mp4", work, total)

    # The vertical cut: the middle of the picture, for phone stories and shorts.
    size = (1080, 1920)
    parts = []
    picks = pick(events, [(g, k, "") for g, k in VERTICAL], set())
    for i, (t, _) in enumerate(picks):
        cap = "Kho Kho Rush" if i == 0 else ""
        clip(src, t - LEAD + 0.3, VCLIP, work / f"v{i}.mp4", "scale=1920:1080,crop=608:1080:(iw-608)/2:0,scale=1080:1920", cap, size)
        parts.append(work / f"v{i}.mp4")
    card(work / "vend.png", bg, size, [("Kho Kho Rush", FONT, 130, CREAM), ("खो-खो", FONT, 80, SAFFRON),
                                        ("Coming soon to", BODY, 54, GOLD), ("Google Play", BODY, 54, GOLD)])
    vend = 15.0 - VCLIP * len(parts)
    still(work / "vend.png", work / "v9.mp4", vend, size)
    parts.append(work / "v9.mp4")
    join(parts, out / "kho-kho-rush-vertical-15s.mp4", work, 15.0)
    for f in ("kho-kho-rush-trailer.mp4", "kho-kho-rush-vertical-15s.mp4"):
        print(f, subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration,size", "-of", "csv=p=0",
                                 str(out / f)], capture_output=True, text=True).stdout.strip())
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Cuts the trailer from the clips tools/media/trailer_clip.tscn recorded (each a folder of numbered frames, the game's
sound as f.wav, and marks.txt with the "MARK <name> <frame>" lines it printed; or the frames already encoded as
clip.mp4) and the cards tools/media/cards.py made.

  trailer/pok-ta-pok-rivals-trailer.mp4           1920 x 1080, 30 fps, H.264 + AAC, about 36 s
  trailer/pok-ta-pok-rivals-trailer-vertical.mp4  1080 x 1920, 15 s, for social media

The title and end cards are laid over the home screen's music (the game's own, made in code); every game clip keeps
its own sound (the ball, the crowd, the conch: docs/SOUNDS.md has each sound's source and licence).

Usage: python3 tools/media/cut_trailer.py CLIPS_DIR CARDS_DIR OUT_DIR   (needs ffmpeg)
"""
import pathlib
import subprocess
import sys

FPS = 30

# (kind, source, mark, seconds before the mark, length, caption)
LANDSCAPE = [
    ("card", "title", None, 0.0, 3.0, None),
    ("clip", "ritual", "start", -1.5, 5.0, "maya"),
    ("clip", "village", "action", 1.2, 4.5, "ulama"),
    ("clip", "dive", "dive", 1.6, 4.0, "team"),
    ("clip", "night", "action", 1.2, 4.0, "courts"),
    ("clip", "festival", "action", 1.2, 4.0, "offline"),
    ("clip", "ring", "strike", 0.3, 3.0, None),
    ("clip", "ring", "ringpass", 3.0, 4.5, None),
    ("card", "end", None, 0.0, 4.0, None),
]
VERTICAL = [
    ("card", "title", None, 0.0, 2.0, None),
    ("clip", "ritual", "start", -1.5, 3.0, "maya"),
    ("clip", "dive", "dive", 1.4, 3.0, None),
    ("clip", "ring", "ringpass", 2.5, 3.5, None),
    ("card", "end", None, 0.0, 3.5, None),
]


def run(args: list) -> None:
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"] + [str(a) for a in args], check=True)


def marks(clip: pathlib.Path) -> dict:
    out = {}
    for line in (clip / "marks.txt").read_text().splitlines():
        parts = line.split()
        if len(parts) == 3 and parts[0] == "MARK":
            out[parts[1]] = int(parts[2])
    return out


def segment(i: int, seg: tuple, clips: pathlib.Path, cards: pathlib.Path, tmp: pathlib.Path, vertical: bool) -> pathlib.Path:
    kind, src, mark, before, length, cap = seg
    out = tmp / f"seg{i:02d}.mp4"
    w, h = (1080, 1920) if vertical else (1920, 1080)
    tag = "_v" if vertical else ""
    fade = f"afade=t=in:d=0.12,afade=t=out:st={length - 0.15:.2f}:d=0.15"
    if kind == "card":
        # The card over the home screen's music: the start of it for the title, further on for the end.
        menu = clips / "menu"
        start = (marks(menu).get("start", 0) / FPS) + (0.0 if src == "title" else 4.0)
        vfade = f"fade=t=in:d=0.4,fade=t=out:st={length - 0.5:.2f}:d=0.5"
        run(["-loop", "1", "-framerate", FPS, "-t", length, "-i", cards / f"{src}{tag}.png",
             "-ss", f"{start:.3f}", "-t", length, "-i", menu / "f.wav",
             "-vf", f"scale={w}:{h},format=yuv420p,{vfade}", "-af", f"{fade},afade=t=in:d=0.4",
             "-r", FPS, "-c:v", "libx264", "-crf", "16", "-preset", "medium", "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
             "-ac", "2", "-shortest", out])
        return out
    clip = clips / src
    m = marks(clip)
    first = max(0, m[mark] - int(round(before * FPS)))
    frames = int(round(length * FPS))
    if (clip / "clip.mp4").exists():
        # The recording as make_media_kit.sh keeps it: its frames encoded near-losslessly.
        pic = ["-ss", f"{first / FPS:.3f}", "-i", clip / "clip.mp4"]
    else:
        pic = ["-framerate", FPS, "-start_number", first, "-i", clip / "f%08d.png"]
    snd = ["-ss", f"{first / FPS:.3f}", "-t", length, "-i", clip / "f.wav"]
    if vertical:
        # The game's picture across the middle, over a blurred, filled copy of itself.
        base = (f"[0:v]split[a][b];[a]scale=-2:{h},crop={w}:{h},boxblur=20:2,eq=brightness=-0.12[bg];"
                f"[b]scale={w}:-2[fg];[bg][fg]overlay=0:(H-h)/2")
    else:
        base = "[0:v]null"
    inputs = pic + snd
    if cap:
        inputs += ["-loop", "1", "-framerate", FPS, "-t", length, "-i", cards / f"cap_{cap}{tag}.png"]
        vf = (f"{base}[v0];[2:v]format=rgba,fade=t=in:st=0.25:d=0.35:alpha=1,"
              f"fade=t=out:st={length - 0.6:.2f}:d=0.35:alpha=1[c];[v0][c]overlay=0:0,format=yuv420p[v]")
    else:
        vf = f"{base},format=yuv420p[v]"
    run(inputs + ["-filter_complex", vf, "-map", "[v]", "-map", "1:a", "-frames:v", frames, "-af", fade,
                  "-r", FPS, "-c:v", "libx264", "-crf", "16", "-preset", "medium", "-c:a", "aac", "-b:a", "192k",
                  "-ar", "48000", "-ac", "2", out])
    return out


def cut(plan: list, clips: pathlib.Path, cards: pathlib.Path, out: pathlib.Path, vertical: bool, crf: int) -> None:
    tmp = out.parent / ("_segments_v" if vertical else "_segments")
    tmp.mkdir(parents=True, exist_ok=True)
    segs = [segment(i, s, clips, cards, tmp, vertical) for i, s in enumerate(plan)]
    lst = tmp / "list.txt"
    lst.write_text("".join(f"file '{p.resolve()}'\n" for p in segs))
    # Capped so the landscape trailer stays well under 60 MB: the game's crowds and stone are fine detail that
    # H.264 would otherwise spend a lot on.
    run(["-f", "concat", "-safe", "0", "-i", lst, "-c:v", "libx264", "-crf", crf, "-maxrate", "10M", "-bufsize", "20M",
         "-preset", "slow", "-profile:v", "high",
         "-pix_fmt", "yuv420p", "-r", FPS, "-af", "loudnorm=I=-16:TP=-1.5:LRA=11",   # the game's mix, to web loudness
         "-c:a", "aac", "-b:a", "160k", "-ar", "48000", "-movflags", "+faststart", out])
    for p in segs:
        p.unlink()
    lst.unlink()
    tmp.rmdir()


def main() -> int:
    clips, cards, out = (pathlib.Path(a) for a in sys.argv[1:4])
    out.mkdir(parents=True, exist_ok=True)
    cut(LANDSCAPE, clips, cards, out / "pok-ta-pok-rivals-trailer.mp4", False, 19)
    cut(VERTICAL, clips, cards, out / "pok-ta-pok-rivals-trailer-vertical.mp4", True, 20)
    for f in sorted(out.glob("*.mp4")):
        d = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", f],
                           capture_output=True, text=True).stdout.strip()
        print(f"{f.name}: {float(d):.1f} s, {f.stat().st_size / 1048576:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())

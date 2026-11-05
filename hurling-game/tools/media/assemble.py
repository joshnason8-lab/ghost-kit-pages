#!/usr/bin/env python3
"""Puts the media kit together from the game's own pictures (tools/media/make_media_kit.sh runs it):

- trailer/hurling-heroes-trailer-1080p.mp4: about 32 s, 1920 x 1080, 30 fps, H.264 with AAC sound: a title card,
  six shots from real matches (tools/media/trailer.gd), three captions, the home screen, an end card ("Coming soon to
  Google Play");
- trailer/hurling-heroes-vertical-15s.mp4: 15 s, 1080 x 1920, for social media (the middle of each shot, full
  height);
- icons/: the icon at 1024 and 512 (PNG with alpha) and the 1024 x 500 feature graphic;
- text/: the website's copy (tools/media/text/: about, features, facts, the sport, a press blurb);
- CREDITS.txt; then the zip, media-kit-hurling-heroes.zip.

The sound is the game's own, each already licensed and credited in the game: the menus' jig (written for the game),
the stadium crowd (Gregor Quendel, CC-BY 4.0) and a referee's whistle (Pixabay Content License). No other music.

Usage: python3 tools/media/assemble.py <footage dir> <kit dir>   (from hurling-game/; needs ffmpeg, Pillow)
"""
import json
import pathlib
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
FONT = str(ROOT / "fonts/Oswald.ttf")
BODY = str(ROOT / "fonts/NotoSans.ttf")
INK = (28, 26, 22)
PAPER = (246, 238, 214)
RED = (200, 69, 44)
GOLD = (233, 182, 60)
FPS = 30

# The trailer: [shot name from trailer.gd, seconds, caption]
CUT = [
    ["final_point", 4.5, ""],
    ["floodlit_catch", 3.0, "Four grounds, by day and under lights"],
    ["parish_dusk", 3.5, "Plays offline. In English and Irish."],
    ["tackle", 3.0, "The real rules. Every county."],
    ["county_point", 4.5, "The Summer Championship"],
    ["celebration", 3.0, ""],
]
TITLE_S, MENU_S, END_S = 3.5, 2.5, 5.0
# The vertical cut: 15 s.
VCUT = [["final_point", 4.5], ["floodlit_catch", 3.0], ["celebration", 2.5]]
VTITLE_S, VEND_S = 2.5, 2.5


def font(path, size, weight=None):
    f = ImageFont.truetype(path, size)
    if weight:
        try:
            f.set_variation_by_axes([weight])
        except Exception:
            pass
    return f


def run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def card(size, lines, path, art=True):
    """A card in the game's programme style: the owner's cover art of a hurler, the name, a line or two."""
    w, h = size
    pic = Image.new("RGB", size, PAPER)
    d = ImageDraw.Draw(pic)
    if art:
        cover = Image.open(ROOT / "tools/store/src/cover_source.webp").convert("RGB")
        ch = int(h * (0.62 if w > h else 0.5))
        cw = int(cover.size[0] * ch / cover.size[1])
        cover = cover.resize((cw, ch), Image.LANCZOS)
        if w > h:
            pic.paste(cover, (w - cw - int(w * 0.06), (h - ch) // 2))
        else:
            pic.paste(cover, ((w - cw) // 2, int(h * 0.36)))
    d.rectangle([0, 0, w, int(h * 0.06)], fill=RED)
    big = font(FONT, int(min(w, h) * (0.15 if w > h else 0.13)), 700)
    small = font(BODY, int(min(w, h) * 0.042))
    x = int(w * 0.07)
    y = int(h * (0.30 if w > h else 0.12))
    title = "HURLING HEROES"
    if w < h:
        # Two lines on a tall card.
        for t in ["HURLING", "HEROES"]:
            tw = d.textlength(t, font=big)
            d.text(((w - tw) / 2, y), t, font=big, fill=INK)
            y += int(big.size * 1.05)
    else:
        d.text((x, y), title, font=big, fill=INK)
        y += int(big.size * 1.15)
    y += int(big.size * 0.3)   # (the capitals stand tall: room under them)
    for t in lines:
        tw = d.textlength(t, font=small)
        d.text((x if w > h else (w - tw) / 2, y), t, font=small, fill=INK)
        y += int(small.size * 1.5)
    pic.save(path)


def caption(text, path, size=(1920, 1080)):
    """A caption for the lower third: gold-edged dark band, white Oswald capitals."""
    pic = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(pic)
    f = font(FONT, 64, 600)
    t = text.upper()
    tw = d.textlength(t, font=f)
    x, y = 110, size[1] - 230
    d.rectangle([x - 30, y - 18, x + tw + 30, y + 92], fill=(16, 32, 22, 205))
    d.rectangle([x - 30, y - 18, x - 18, y + 92], fill=GOLD + (255,))
    d.text((x, y), t, font=f, fill=(255, 255, 255, 255))
    pic.save(path)


def encode_still(img, secs, out, size, zoom=False):
    w, h = size
    vf = f"scale={w}:{h},format=yuv420p,fade=t=in:st=0:d=0.4,fade=t=out:st={secs - 0.4}:d=0.4"
    if zoom:
        frames = int(secs * FPS)
        vf = (f"scale={w * 2}:{h * 2},zoompan=z='min(zoom+0.0008,1.08)':d={frames}:s={w}x{h}:fps={FPS},"
              f"format=yuv420p,fade=t=in:st=0:d=0.3,fade=t=out:st={secs - 0.4}:d=0.4")
    run(["ffmpeg", "-y", "-loop", "1", "-framerate", str(FPS), "-i", str(img), "-t", str(secs), "-vf", vf,
         "-r", str(FPS), "-c:v", "libx264", "-preset", "medium", "-crf", "18", str(out)])


def encode_shot(seg_dir, secs, out, cap=None, vertical=False):
    frames = int(secs * FPS)
    inputs = ["-framerate", str(FPS), "-i", str(seg_dir / "%04d.jpg")]
    if vertical:
        # Full height, the middle of the picture: the camera keeps the ball there.
        fc = "[0:v]scale=3414:1920,crop=1080:1920,format=yuv420p[v]"
    elif cap:
        inputs += ["-loop", "1", "-i", str(cap)]
        fc = ("[1:v]format=rgba,fade=t=in:st=0.3:d=0.4:alpha=1[c];[0:v][c]overlay=0:0:shortest=1,format=yuv420p[v]")
    else:
        fc = "[0:v]format=yuv420p[v]"
    run(["ffmpeg", "-y", *inputs, "-filter_complex", fc, "-map", "[v]", "-frames:v", str(frames), "-r", str(FPS),
         "-c:v", "libx264", "-preset", "medium", "-crf", "18", str(out)])


def concat(parts, out, work):
    lst = work / (out.stem + "_list.txt")
    lst.write_text("".join(f"file '{p.resolve()}'\n" for p in parts))
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(out)])


def soundtrack(total, hits, out, title_s, end_s):
    """The jig under everything, the crowd under the play, a whistle at the throw-in, cheers where the points go
    over and a roar for the celebration."""
    a = ROOT / "assets/audio"
    inputs = ["-stream_loop", "-1", "-i", str(a / "menu_music.ogg"), "-stream_loop", "-1", "-i", str(a / "crowd_loop.ogg")]
    filters = [f"[0:a]atrim=0:{total},volume=0.55,afade=t=in:d=1,afade=t=out:st={total - 2}:d=2[m]",
               f"[1:a]atrim=0:{total - title_s - end_s},volume=0.75,afade=t=in:d=0.6,afade=t=out:st={total - title_s - end_s - 1}:d=1,"
               f"adelay={int(title_s * 1000)}|{int(title_s * 1000)}[c]"]
    mix = ["[m]", "[c]"]
    for k, (name, at, vol) in enumerate(hits):
        inputs += ["-i", str(a / f"{name}.ogg")]
        ms = int(at * 1000)
        filters.append(f"[{k + 2}:a]volume={vol},adelay={ms}|{ms}[h{k}]")
        mix.append(f"[h{k}]")
    filters.append(f"{''.join(mix)}amix=inputs={len(mix)}:normalize=0:duration=first,atrim=0:{total},"
                   f"aformat=sample_rates=48000:channel_layouts=stereo,loudnorm=I=-16:TP=-1.5[out]")
    run(["ffmpeg", "-y", *inputs, "-filter_complex", ";".join(filters), "-map", "[out]", "-c:a", "aac", "-b:a", "160k",
         str(out)])


def mux(video, audio, out):
    """The cut and its sound in one file, encoded once more with the bitrate held to 11 Mb/s at most (grass and crowds
    take all a constant quality gives them): a 45 s trailer stays under 60 MB."""
    run(["ffmpeg", "-y", "-i", str(video), "-i", str(audio), "-map", "0:v", "-map", "1:a", "-c:v", "libx264",
         "-preset", "slow", "-crf", "20", "-maxrate", "11M", "-bufsize", "22M", "-pix_fmt", "yuv420p", "-c:a", "copy",
         "-shortest", "-movflags", "+faststart", str(out)])


def main():
    foot, kit = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    shots = {json.loads((d / "info.json").read_text())["name"]: d for d in sorted(foot.glob("seg_*")) if (d / "info.json").exists()}
    work = foot / "work"
    work.mkdir(exist_ok=True)
    (kit / "trailer").mkdir(parents=True, exist_ok=True)
    (kit / "icons").mkdir(parents=True, exist_ok=True)

    # The landscape trailer.
    card((1920, 1080), ["Hurling, as it is played."], work / "title.png")
    card((1920, 1080), ["Coming soon to Google Play", "Plays offline  ·  English and Irish  ·  No ads"], work / "end.png")
    parts = [work / "title.mp4"]
    encode_still(work / "title.png", TITLE_S, parts[0], (1920, 1080))
    t = TITLE_S
    hits = [("whistle_long", t + 0.2, 0.9)]
    for i, (name, secs, cap) in enumerate(CUT):
        capfile = None
        if cap:
            capfile = work / f"cap_{i}.png"
            caption(cap, capfile)
        p = work / f"shot_{i}.mp4"
        encode_shot(shots[name], secs, p, capfile)
        parts.append(p)
        if name.endswith("_point"):
            hits.append(("crowd_cheer" if name == "final_point" else "crowd_cheer_2", t + 2.2, 1.0))
        if name == "celebration":
            hits.append(("roar", t + 0.1, 0.9))
        t += secs
    menu = kit / "screenshots/09_menu.png"
    if menu.exists():
        p = work / "menu.mp4"
        encode_still(menu, MENU_S, p, (1920, 1080), zoom=True)
        parts.append(p)
        t += MENU_S
    p = work / "end.mp4"
    encode_still(work / "end.png", END_S, p, (1920, 1080))
    parts.append(p)
    total = t + END_S
    concat(parts, work / "video.mp4", work)
    soundtrack(total, hits, work / "audio.m4a", TITLE_S, END_S)
    mux(work / "video.mp4", work / "audio.m4a", kit / "trailer/hurling-heroes-trailer-1080p.mp4")

    # The vertical cut.
    card((1080, 1920), ["Hurling, as it is played."], work / "vtitle.png")
    card((1080, 1920), ["Coming soon to", "Google Play"], work / "vend.png")
    vparts = [work / "vtitle.mp4"]
    encode_still(work / "vtitle.png", VTITLE_S, vparts[0], (1080, 1920))
    vt = VTITLE_S
    vhits = [("whistle_long", vt + 0.2, 0.9)]
    for i, (name, secs) in enumerate(VCUT):
        p = work / f"vshot_{i}.mp4"
        encode_shot(shots[name], secs, p, vertical=True)
        vparts.append(p)
        if name == "final_point":
            vhits.append(("crowd_cheer", vt + 2.2, 1.0))
        if name == "celebration":
            vhits.append(("roar", vt + 0.1, 0.9))
        vt += secs
    p = work / "vend.mp4"
    encode_still(work / "vend.png", VEND_S, p, (1080, 1920))
    vparts.append(p)
    vtotal = vt + VEND_S
    concat(vparts, work / "vvideo.mp4", work)
    soundtrack(vtotal, vhits, work / "vaudio.m4a", VTITLE_S, VEND_S)
    mux(work / "vvideo.mp4", work / "vaudio.m4a", kit / "trailer/hurling-heroes-vertical-15s.mp4")

    # Icons and the feature graphic.
    art = Image.open(ROOT / "tools/store/src/icon_source.webp").convert("RGBA")
    art.resize((1024, 1024), Image.LANCZOS).save(kit / "icons/icon-1024.png")
    art.resize((512, 512), Image.LANCZOS).save(kit / "icons/icon-512.png")
    shutil.copy(ROOT / "store/graphics/feature-1024x500.png", kit / "icons/feature-1024x500.png")

    shutil.copytree(ROOT / "tools/media/text", kit / "text", dirs_exist_ok=True)
    (kit / "CREDITS.txt").write_text(CREDITS.format(total=round(total, 1)))
    for f in ["trailer/hurling-heroes-trailer-1080p.mp4", "trailer/hurling-heroes-vertical-15s.mp4"]:
        d = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration,size", "-of", "csv=p=0", str(kit / f)],
                           capture_output=True, text=True).stdout.strip()
        print(f, d)
    zipf = kit.parent / "media-kit-hurling-heroes"
    shutil.make_archive(str(zipf), "zip", root_dir=kit)
    print("wrote", zipf.with_suffix(".zip"), zipf.with_suffix(".zip").stat().st_size)


CREDITS = """Hurling Heroes: media kit

Everything here is from the game itself, captured from real matches on High graphics with the HD pack.

screenshots/  1920 x 1080 PNG: the action at each ground (by day and under floodlights), the officials, a goal's
              celebration, and the menus (one in Irish).
menus/        1920 x 1080 PNG: every menu screen, in English, named by screen.
text/         the website's copy in Markdown: about.md, features.md, facts.md, sport.md, press.md.
icons/        the game's icon at 1024 and 512 (PNG), the 1024 x 500 feature graphic.
trailer/      hurling-heroes-trailer-1080p.mp4 ({total} s, 1920 x 1080, 30 fps, H.264 / AAC) and
              hurling-heroes-vertical-15s.mp4 (15 s, 1080 x 1920) for social media.

Credits (as in the game's Settings > About > Licences):
- The game, its footage, the menus' music (heard in the trailer) and the hurlers' model: Josh Nason.
- The cover art of a hurler on the cards and the icon: the game's own artwork, by the maker.
- The stadium crowd heard in the trailer: "Free Crowd Cheering Sounds" by Gregor Quendel
  (https://opengameart.org/content/free-crowd-cheering-sounds), CC-BY 4.0
  (https://creativecommons.org/licenses/by/4.0/). Trimmed and levelled.
- The referee's whistle: Pixabay (pixabay.com) "Referee whistle" by charlesheffley009, Pixabay Content License.
- The players' movement: Adobe Mixamo, and the CMU Graphics Lab Motion Capture Database (mocap.cs.cmu.edu; the
  database was created with funding from NSF EIA-0196217).
- Skies, grass and models: Poly Haven (polyhaven.com), CC0; the officials, crowd and floodlights made with Meshy
  (meshy.ai) by the maker.
- Fonts: Oswald and Noto Sans, SIL Open Font License 1.1.

Hurling Heroes is an independent game, not connected with or endorsed by any sporting body, county board or club.
Google Play is a trademark of Google LLC.
Contact: joshnason8@gmail.com
"""


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""The media kit's trailer (1920 x 1080, about 41 s) and its vertical cut (1080 x 1920, 15 s), the icons and the zip,
from what tools/media/media_kit.tscn captured from the game (tools/media/make_media_kit.sh runs both):

    python3 -I tools/media/make_trailer.py <media dir> <version>

The footage is the game's own frames; the cards and captions are drawn here in the game's fonts and the whiteboard's
colours; the sound is the game's own recordings and music (store/media-kit/CREDITS.txt). Needs ffmpeg and Pillow.
"""
import json
import pathlib
import shutil
import subprocess
import sys
import zipfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
FPS = 30
BLUE, RED, INK = (29, 78, 216), (214, 40, 57), (31, 41, 51)
AUDIO = ROOT / "assets" / "audio"

# The 16:9 cut: (clip, start in s from the clip's moment, length s, caption).
WIDE = [
	("arena_faceoff", 0.0, 3.5, "FIVE A SIDE AND A GOALKEEPER · THE REAL 2026 RULES"),
	("arena_goal", -5.0, 7.0, ""),
	("arena_save_high", -3.0, 4.0, "GOALKEEPERS WHO READ THE SHOT"),
	("hall_goal_women", -4.0, 6.0, "MEN'S AND WOMEN'S NATIONAL TEAMS"),
	("hall_penalty", -2.0, 4.5, "TWO REFEREES CALL EVERY RULE"),
	("school_goal_end", -4.0, 6.0, "CITY ARENA · SPORTS HALL · SCHOOL GYM"),
]
MENUS = ["quick_match_setup", "world_finals_groups", "season_table"]
MENU_S = 1.2
MENU_CAPTION = "QUICK MATCH · WORLD FINALS · CLUB SEASON · PLAYS OFFLINE"
TITLE_S, END_S = 3.0, 3.5
# The vertical cut: 15 s.
TALL = [("arena_goal", -3.0, 4.5, "SCORE TO THE REAL RULES"), ("arena_save_high", -2.0, 3.0, "GOALKEEPERS WHO READ THE SHOT"),
	("hall_goal_women", -2.5, 3.5, "MEN'S AND WOMEN'S TEAMS")]
TALL_TITLE_S, TALL_END_S = 2.0, 2.0


def font(name, size, bold=None):
	f = ImageFont.truetype(str(ROOT / "fonts" / name), size)
	if bold:
		f.set_variation_by_axes([bold])
	return f


def run(*args):
	subprocess.run(["ffmpeg", "-v", "error", "-y", *map(str, args)], check=True)


# ---------------------------------------------------------------- the cards

def whiteboard(img, box, radius=18):
	"""The coach's whiteboard (the home screen's) as a panel on img."""
	layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
	d = ImageDraw.Draw(layer)
	d.rounded_rectangle(box, radius, fill=(233, 236, 234, 246), outline=(170, 179, 188, 255), width=12)
	shadow = layer.filter(ImageFilter.GaussianBlur(18))
	img = Image.alpha_composite(img, Image.eval(shadow, lambda v: v // 3))
	return Image.alpha_composite(img, layer)


def backdrop(frame, size):
	bg = Image.open(frame).convert("RGB")
	k = max(size[0] / bg.width, size[1] / bg.height)
	bg = bg.resize((int(bg.width * k + 1), int(bg.height * k + 1)), Image.LANCZOS)
	x, y = (bg.width - size[0]) // 2, (bg.height - size[1]) // 2
	bg = bg.crop((x, y, x + size[0], y + size[1])).filter(ImageFilter.GaussianBlur(6))
	return Image.blend(bg, Image.new("RGB", size, (12, 16, 24)), 0.35).convert("RGBA")


def name_block(d, x, y, scale, line2=None):
	title = font("Caveat.ttf", int(150 * scale), 700)
	d.text((x, y), "Floorball", font=title, fill=BLUE)
	d.text((x, y + int(130 * scale)), "Unleashed", font=title, fill=RED)
	sub = font("BarlowCondensed-SemiBold.ttf", int(54 * scale))
	ly = y + int(310 * scale)
	d.line([(x + 6, ly), (x + int(600 * scale), ly - 8)], fill=INK, width=max(4, int(7 * scale)))
	d.text((x + 8, ly + int(20 * scale)), line2 or "FLOORBALL · 5 v 5 · REAL RULES", font=sub, fill=INK)
	for i, c in enumerate([BLUE, RED, (15, 139, 95), (240, 138, 36)]):
		cx, cy = x + int((30 + i * 66) * scale), ly + int(130 * scale)
		r = int(22 * scale)
		d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c)


def card(frame, size, line2=None, icon=True):
	w, h = size
	img = backdrop(frame, size)
	if w > h:
		box = (w // 2 - 640, h // 2 - 300, w // 2 + 640, h // 2 + 300)
		img = whiteboard(img, box)
		d = ImageDraw.Draw(img)
		if icon:
			ic = Image.open(ROOT / "store" / "graphics" / "icon-512.png").convert("RGBA").resize((400, 400), Image.LANCZOS)
			mask = Image.new("L", ic.size, 0)
			ImageDraw.Draw(mask).rounded_rectangle((0, 0, 399, 399), 72, fill=255)
			img.paste(ic, (box[0] + 70, h // 2 - 200), mask)
		name_block(d, box[0] + 530, h // 2 - 250, 1.0, line2)
	else:
		box = (70, h // 2 - 520, w - 70, h // 2 + 520)
		img = whiteboard(img, box)
		d = ImageDraw.Draw(img)
		ic = Image.open(ROOT / "store" / "graphics" / "icon-512.png").convert("RGBA").resize((360, 360), Image.LANCZOS)
		mask = Image.new("L", ic.size, 0)
		ImageDraw.Draw(mask).rounded_rectangle((0, 0, 359, 359), 64, fill=255)
		img.paste(ic, ((w - 360) // 2, box[1] + 60), mask)
		name_block(d, box[0] + 90, box[1] + 450, 0.95, line2)
	return img.convert("RGB")


def caption(text, size, y):
	"""A strip of the whiteboard's tape along the bottom, the caption on it (transparent elsewhere)."""
	w, h = size
	img = Image.new("RGBA", size, (0, 0, 0, 0))
	if not text:
		return img
	f = font("BarlowCondensed-Bold.ttf", 52 if w > h else 46)
	tw = ImageDraw.Draw(img).textlength(text, font=f)
	pad = 34
	box = (int((w - tw) / 2 - pad), y, int((w + tw) / 2 + pad), y + 84)
	d = ImageDraw.Draw(img)
	d.rounded_rectangle(box, 10, fill=(233, 236, 234, 240), outline=(170, 179, 188, 255), width=5)
	d.rectangle((box[0] + 5, box[3] - 14, box[2] - 5, box[3] - 6), fill=RED + (255,))
	d.text((w / 2, y + 40), text, font=f, fill=INK, anchor="mm")
	return img


def tall_frame_overlay(text):
	"""The vertical cut's layer over the footage: the name above, the caption below."""
	w, h = 1080, 1920
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	img = whiteboard(img, (90, 250, w - 90, 560))
	d = ImageDraw.Draw(img)
	title = font("Caveat.ttf", 120, 700)
	d.text((w / 2, 345), "Floorball", font=title, fill=BLUE, anchor="mm")
	d.text((w / 2, 455), "Unleashed", font=title, fill=RED, anchor="mm")
	return Image.alpha_composite(img, caption(text, (w, h), 1420))


# ---------------------------------------------------------------- the video

def meta(media, clip):
	return json.loads((media / "frames" / clip / "meta.json").read_text())


def segment(media, clip, start, length, overlay_png, out, tall=False):
	m = meta(media, clip)
	first = int(round(m["event"] + start * FPS))
	first = max(0, min(first, m["frames"] - int(length * FPS)))
	frames = media / "frames" / clip / "%04d.jpg"
	if tall:
		fil = ("[0:v]split[a][b];[a]scale=-2:1920,crop=1080:1920,gblur=sigma=28,eq=brightness=-0.12[bg];"
			"[b]scale=1080:-2[fg];[bg][fg]overlay=0:(H-h)/2[v];[v][1:v]overlay,format=yuv420p")
	else:
		fil = "[0:v][1:v]overlay,format=yuv420p"
	run("-framerate", FPS, "-start_number", first, "-i", frames, "-i", overlay_png, "-filter_complex", fil,
		"-frames:v", int(length * FPS), "-r", FPS, "-c:v", "libx264", "-preset", "slow", "-crf", "18", out)
	return (first, m["event"])


def still(png, length, out, fade_in=True, fade_out=True):
	fades = []
	if fade_in:
		fades.append("fade=in:st=0:d=0.5")
	if fade_out:
		fades.append("fade=out:st=%.2f:d=0.5" % (length - 0.5))
	run("-loop", 1, "-framerate", FPS, "-i", png, "-t", length, "-vf", ",".join(fades + ["format=yuv420p"]),
		"-r", FPS, "-c:v", "libx264", "-preset", "slow", "-crf", "18", out)


def concat(parts, out):
	lst = out.with_suffix(".txt")
	lst.write_text("".join("file '%s'\n" % p for p in parts))
	run("-f", "concat", "-safe", 0, "-i", lst, "-c", "copy", out)


def soundtrack(total, action, events, out):
	"""The menu music under the cards, the crowd under the play, a whistle and a cheer at each moment."""
	a0, a1 = action
	ins = ["-stream_loop", -1, "-i", AUDIO / "menu_music.ogg", "-stream_loop", -1, "-i", AUDIO / "crowd_loop.ogg"]
	fil = ["[0:a]atrim=0:%.2f,volume='if(between(t,%.2f,%.2f),0.28,0.9)':eval=frame[mu]" % (total, a0, a1),
		"[1:a]atrim=0:%.2f,volume='if(between(t,%.2f,%.2f),1.0,0)':eval=frame[cr]" % (total, a0 - 0.1, a1)]
	mix = ["[mu]", "[cr]"]
	for i, (t, sound, vol) in enumerate(events):
		ins += ["-i", AUDIO / (sound + ".ogg")]
		k = len(mix)
		fil.append("[%d:a]aformat=channel_layouts=stereo,volume=%.2f,adelay=%d|%d[s%d]" % (k, vol, t * 1000, t * 1000, k))
		mix.append("[s%d]" % k)
	fil.append("%samix=inputs=%d:normalize=0:duration=first,alimiter=limit=0.9,afade=out:st=%.2f:d=1.5[out]"
		% ("".join(mix), len(mix), total - 1.5))
	subprocess.run(["ffmpeg", "-v", "error", "-y", *map(str, ins), "-filter_complex", ";".join(fil), "-map", "[out]",
		"-t", "%.2f" % total, "-c:a", "aac", "-b:a", "192k", "-ar", "44100", str(out)], check=True)


def wide(media, work, out):
	bg = media / "frames" / "arena_faceoff" / "0000.jpg"
	card(bg, (1920, 1080)).save(work / "title.png")
	card(bg, (1920, 1080), "COMING SOON TO GOOGLE PLAY").save(work / "end.png")
	parts, events, t = [], [], 0.0
	still(work / "title.png", TITLE_S, work / "w00.mp4", fade_in=True)
	parts.append(work / "w00.mp4")
	t += TITLE_S
	action0 = t
	for i, (clip, start, length, text) in enumerate(WIDE):
		caption(text, (1920, 1080), 930).save(work / ("cap%d.png" % i))
		first, ev = segment(media, clip, start, length, work / ("cap%d.png" % i), work / ("w%02d.mp4" % (i + 1)))
		at = t + (ev - first) / FPS   # when the moment comes in the trailer
		if clip.endswith("faceoff"):
			events.append((t + 0.1, "whistle_long_a", 0.8))
		elif "goal" in clip:
			events += [(at + 0.05, "whistle_long_b", 0.7), (at, "crowd_cheer", 1.1), (at + 0.1, "roar", 0.7)]
		elif "penalty" in clip:
			events.append((at, "whistle_short_a", 0.9))
		elif "save" in clip:
			events.append((at + 0.1, "crowd_ooh", 0.9))
		parts.append(work / ("w%02d.mp4" % (i + 1)))
		t += length
	caption(MENU_CAPTION, (1920, 1080), 930).save(work / "capm.png")
	for j, name in enumerate(MENUS):
		Image.alpha_composite(Image.open(media / "menus" / next(p.name for p in sorted((media / "menus").glob("*_%s.png" % name)))).convert("RGBA"),
			Image.open(work / "capm.png")).convert("RGB").save(work / ("m%d.png" % j))
		still(work / ("m%d.png" % j), MENU_S, work / ("wm%d.mp4" % j), fade_in=False, fade_out=False)
		parts.append(work / ("wm%d.mp4" % j))
		t += MENU_S
	action1 = t
	still(work / "end.png", END_S, work / "w99.mp4", fade_out=True)
	parts.append(work / "w99.mp4")
	t += END_S
	events.append((action1 + 0.2, "whistle_final", 0.7))
	concat(parts, work / "wide_v.mp4")
	soundtrack(t, (action0, action1), events, work / "wide_a.m4a")
	run("-i", work / "wide_v.mp4", "-i", work / "wide_a.m4a", "-c", "copy", "-movflags", "+faststart", "-shortest", out)
	return t


def tall(media, work, out):
	bg = media / "frames" / "arena_goal" / "0000.jpg"
	card(bg, (1080, 1920)).save(work / "ttitle.png")
	card(bg, (1080, 1920), "COMING SOON TO GOOGLE PLAY").save(work / "tend.png")
	parts, events, t = [], [], 0.0
	still(work / "ttitle.png", TALL_TITLE_S, work / "t00.mp4")
	parts.append(work / "t00.mp4")
	t += TALL_TITLE_S
	a0 = t
	for i, (clip, start, length, text) in enumerate(TALL):
		tall_frame_overlay(text).save(work / ("tcap%d.png" % i))
		first, ev = segment(media, clip, start, length, work / ("tcap%d.png" % i), work / ("t%02d.mp4" % (i + 1)), tall=True)
		at = t + (ev - first) / FPS
		if "goal" in clip:
			events += [(at + 0.05, "whistle_long_b", 0.7), (at, "crowd_cheer", 1.1)]
		else:
			events.append((at + 0.1, "crowd_ooh", 0.9))
		parts.append(work / ("t%02d.mp4" % (i + 1)))
		t += length
	a1 = t
	still(work / "tend.png", TALL_END_S, work / "t99.mp4")
	parts.append(work / "t99.mp4")
	t += TALL_END_S
	concat(parts, work / "tall_v.mp4")
	soundtrack(t, (a0, a1), events, work / "tall_a.m4a")
	run("-i", work / "tall_v.mp4", "-i", work / "tall_a.m4a", "-c", "copy", "-movflags", "+faststart", "-shortest", out)
	return t


# ---------------------------------------------------------------- the kit

def main():
	media = pathlib.Path(sys.argv[1]).resolve()
	version = sys.argv[2] if len(sys.argv) > 2 else ""
	kit = media / "media-kit-floorball-unleashed"
	work = media / "work"
	shutil.rmtree(kit, ignore_errors=True)
	shutil.rmtree(work, ignore_errors=True)
	for d in ["screenshots", "icons", "trailer", "menus", "text"]:
		(kit / d).mkdir(parents=True)
	work.mkdir()
	# Screenshots: the stills of the action (PNG, 1920 x 1080), named in order.
	for i, p in enumerate(sorted((media / "screenshots").glob("*.png"))):
		shutil.copy(p, kit / "screenshots" / ("%02d_%s" % (i + 1, p.name)))
	for p in sorted((media / "menus").glob("*.png")):
		shutil.copy(p, kit / "menus" / p.name)
	# Icons: the artwork fills the square (it has no transparent edge), 1024 and 512; the feature graphic.
	art = Image.open(ROOT / "store" / "graphics" / "icon_art.webp").convert("RGBA")
	side = min(art.size)
	art = art.crop(((art.width - side) // 2, (art.height - side) // 2, (art.width + side) // 2, (art.height + side) // 2))
	art.resize((1024, 1024), Image.LANCZOS).save(kit / "icons" / "icon-1024.png")
	art.resize((512, 512), Image.LANCZOS).save(kit / "icons" / "icon-512.png")
	shutil.copy(ROOT / "store" / "graphics" / "feature-1024x500.png", kit / "icons" / "feature-1024x500.png")
	# Text and credits.
	for p in sorted((ROOT / "store" / "media-kit" / "text").glob("*.md")):
		shutil.copy(p, kit / "text" / p.name)
	shutil.copy(ROOT / "store" / "media-kit" / "CREDITS.txt", kit / "CREDITS.txt")
	if version:
		facts = (kit / "text" / "facts.md").read_text()
		(kit / "text" / "facts.md").write_text(facts.replace("{version}", version))
	tw = wide(media, work, kit / "trailer" / "floorball-unleashed-trailer-1920x1080.mp4")
	tt = tall(media, work, kit / "trailer" / "floorball-unleashed-social-1080x1920.mp4")
	zp = media / "media-kit-floorball-unleashed.zip"
	with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED) as z:
		for p in sorted(kit.rglob("*")):
			if p.is_file():
				z.write(p, p.relative_to(kit.parent))
	print("trailer %.1f s, vertical %.1f s, zip %s (%.1f MB)" % (tw, tt, zp, zp.stat().st_size / 1e6))


if __name__ == "__main__":
	main()

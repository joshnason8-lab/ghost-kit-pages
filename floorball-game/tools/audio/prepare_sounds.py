#!/usr/bin/env python3
"""The game's recorded sounds, cut from their sources (docs/SOUNDS.md has each source, author and licence):

    python3 -I tools/audio/prepare_sounds.py <downloads>

<downloads> holds the sources as downloaded and unpacked (docs/SOUNDS.md, "Remaking them"). Each sound is cut to its
part, faded, made mono at 22,050 Hz, brought to one loudness for its kind (EBU R128: one-shots -16 LUFS, the crowd
bed -20; the footsteps and the menu click, too short to measure, to a peak of -12 and -6 dBFS), and written as Ogg Vorbis (quality 2, about 48 kbit/s) to assets/audio/.
The crowd bed is made to loop: its last 1.5 seconds are crossfaded into its start. Needs ffmpeg and numpy.
"""
import os
import subprocess
import sys

import numpy as np

SR = 22050
OUT = "assets/audio"
GQ = "gregor_quendel_-_free_crowd_cheering_sounds_-_mp3/Gregor Quendel - Free Crowd Cheering Sounds - MP3/" \
	"Gregor Quendel - Crowd Cheering Sounds - %s.mp3"

# name: (source, start s, length s, fade in s, fade out s, loudness LUFS, loop)
SOUNDS = {
	"crowd_loop": (GQ % "10 - Ambience", 12.0, 16.0, 0.0, 0.0, -20, True),
	"crowd_cheer": (GQ % "04 - Strong cheering - II - Short", 3.0, 9.0, 0.15, 3.0, -16, False),
	"roar": (GQ % "03 - Strong cheering - I", 4.0, 7.0, 0.3, 2.5, -16, False),
	"applause": ("applause-clapping-church-crowd-immersive.wav", 2.0, 5.5, 0.1, 1.8, -16, False),
	"click": ("interface-sounds/Audio/click_001.ogg", 0.0, 0.3, 0.0, 0.05, -18, False),
}
for i in range(5):
	SOUNDS["step_%d" % (i + 1)] = ("impact-sounds/Audio/footstep_wood_%03d.ogg" % i, 0.0, 0.4, 0.0, 0.08, -24, False)


def read(path):
	raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
		capture_output=True, check=True).stdout
	return np.frombuffer(raw, np.float32).astype(np.float64)


def loudness(x):
	"""Integrated loudness (LUFS) by ffmpeg's ebur128 filter."""
	tmp = "/tmp/_snd_%d.wav" % os.getpid()
	write_wav(tmp, x)
	log = subprocess.run(["ffmpeg", "-nostats", "-v", "info", "-i", tmp, "-af", "ebur128", "-f", "null", "-"],
		capture_output=True, text=True).stderr
	os.remove(tmp)
	for line in reversed(log.splitlines()):
		if line.strip().startswith("I:"):
			return float(line.split()[1])
	return -70.0


def write_wav(path, x):
	pcm = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
	subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-", path],
		input=pcm, check=True)


def make(name, spec, src):
	path, start, length, fin, fout, lufs, loop = spec
	x = read(os.path.join(src, path))
	a = int(start * SR)
	if loop:
		f = int(1.5 * SR)
		n = int(length * SR)
		seg = x[a:a + n + f]
		out = seg[:n].copy()
		w = np.linspace(0.0, 1.0, f)
		# The start fades in from what followed the end: the join is seamless.
		out[:f] = seg[:f] * w + seg[n:n + f] * (1.0 - w)
	else:
		out = x[a:a + int(length * SR)].copy()
		# Start at the first sound: a quiet lead-in trimmed (one-shots only).
		lead = np.argmax(np.abs(out) > 0.02 * np.abs(out).max())
		out = out[max(0, lead - int(0.005 * SR)):]
		if fin > 0:
			k = min(len(out), int(fin * SR))
			out[:k] *= np.linspace(0.0, 1.0, k)
		if fout > 0:
			k = min(len(out), int(fout * SR))
			out[-k:] *= np.linspace(1.0, 0.0, k) ** 1.5
	if len(out) < 0.6 * SR:
		# Too short for a loudness reading (it needs 0.4 s): brought to a peak instead, as many dB under full scale.
		out = out * (10 ** ((lufs + 12) / 20.0) / np.abs(out).max())
	else:
		out = out * 10 ** ((lufs - loudness(out)) / 20.0)
	peak = np.abs(out).max()
	if peak > 0.97:
		out *= 0.97 / peak
	tmp = "/tmp/_snd_out_%d.wav" % os.getpid()
	write_wav(tmp, out)
	dst = os.path.join(OUT, name + ".ogg")
	subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "2", dst], check=True)
	os.remove(tmp)
	print("%-12s %5.2f s  %6d bytes  from %s" % (name, len(out) / SR, os.path.getsize(dst), path.rsplit("/", 1)[-1]))


if __name__ == "__main__":
	src = sys.argv[1]
	only = sys.argv[2:]
	for name, spec in SOUNDS.items():
		if not only or name in only:
			make(name, spec, src)

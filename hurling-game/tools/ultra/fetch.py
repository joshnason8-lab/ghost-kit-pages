#!/usr/bin/env python3
"""Fetches the HD pack's large source files that are not kept in the repository: Poly Haven's 4K grass_ground
textures (CC0, https://polyhaven.com/a/grass_ground), each checked against its SHA-256. Run before building the
pack (the Android workflow does); files already here and whole are left alone.

    python3 tools/ultra/fetch.py
"""
import hashlib
import os
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
PH = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/4k/grass_ground/"
FILES = [
	("ultra/ground/grass_ground_albedo_4k.jpg", PH + "grass_ground_diff_4k.jpg",
		"a8bca0397c9e21d3bd3fe133b7bf912c0a3a0f3ef791d5779cbfcb729db0998a"),
	("ultra/ground/grass_ground_normal_4k.jpg", PH + "grass_ground_nor_gl_4k.jpg",
		"f7c89e09273625a5b7b1acece98e339f7ea27ef34c45736e86008e6556d5dbad"),
	("ultra/ground/grass_ground_rough_4k.jpg", PH + "grass_ground_rough_4k.jpg",
		"e4a034efc4ba3c539982417256ed8d7bd5f22683a8f6ab239f0dc2777bdd3dd6"),
]


def sha256(path):
	h = hashlib.sha256()
	with open(path, "rb") as f:
		for block in iter(lambda: f.read(1 << 20), b""):
			h.update(block)
	return h.hexdigest()


def main():
	for rel, url, want in FILES:
		path = os.path.join(ROOT, rel)
		if os.path.exists(path) and sha256(path) == want:
			print("have", rel)
			continue
		os.makedirs(os.path.dirname(path), exist_ok=True)
		# curl: Poly Haven's server turns away Python's own client.
		for _ in range(3):
			if subprocess.call(["curl", "-sSfL", "--retry", "3", "-o", path + ".part", url]) == 0:
				break
		if not os.path.exists(path + ".part") or sha256(path + ".part") != want:
			sys.exit("could not fetch %s whole from %s" % (rel, url))
		os.replace(path + ".part", path)
		print("got", rel)


if __name__ == "__main__":
	main()

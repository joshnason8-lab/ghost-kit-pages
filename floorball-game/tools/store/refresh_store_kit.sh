#!/usr/bin/env bash
# The store listing's pictures, made again from the game as it is now (run just before submitting to Google Play):
# the phone screenshots (1920 x 1080, High), the feature graphic (1024 x 500) and the hi-res icon (512 x 512, 32-bit).
# Then checks each against Play's rules. Run from floorball-game/; needs Godot 4.7, xvfb-run and Pillow.
#   bash tools/store/refresh_store_kit.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 res://tools/store/store_shots.tscn
python3 -I tools/store/make_feature.py
python3 -I tools/store/make_icons.py
python3 -I - <<'PY'
import pathlib
from PIL import Image
g = pathlib.Path("store/graphics")
icon = Image.open(g / "icon-512.png")
assert icon.size == (512, 512) and icon.mode == "RGBA", ("icon", icon.size, icon.mode)
assert Image.open(g / "feature-1024x500.png").size == (1024, 500)
shots = sorted((g / "screenshots").glob("*.jpg"))
assert 4 <= len(shots) <= 8, len(shots)
for p in shots:
	w, h = Image.open(p).size
	assert min(w, h) >= 1080 and abs(w / h - 16 / 9) < 0.01, (p, w, h)
for p in sorted(pathlib.Path("store/listing").glob("*.txt")):
	parts, key = {}, None
	for line in p.read_text().splitlines():
		if line.startswith("== "):
			key = line.strip("= ")
			parts[key] = []
		elif key and not line.startswith("#"):
			parts[key].append(line)
	text = {k: "\n".join(v).strip() for k, v in parts.items()}
	for k, n in [("App name", 30), ("Short description", 80), ("Full description", 4000)]:
		assert len(text[k]) <= n, (p.name, k, len(text[k]))
print("store kit ok: icon 512 RGBA, feature 1024x500, %d screenshots, %d listings" % (len(shots), len(list(pathlib.Path("store/listing").glob("*.txt")))))
PY

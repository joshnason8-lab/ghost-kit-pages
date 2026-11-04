#!/usr/bin/env bash
# Regenerates the Play listing's drafts from the current build, just before submitting: the phone screenshots
# (1920 x 1080, captured from the game on High: tests/screenshots.gd, part "store"), the 1024 x 500 feature graphic
# and the 512 x 512 icon. The listing text is store/listing/*.txt (edit by hand; tools/store/check_listing.py checks
# Play's limits). Run from netball-game/ on a machine with xvfb (software GL renders High slowly: ~15 minutes).
#   tools/store/refresh.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=store/graphics/screenshots
TMP=$(mktemp -d)
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --import >/dev/null 2>&1
timeout 3600 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1920x1080 \
	res://tests/screenshots.tscn -- "$TMP" en store high
ls "$TMP"/store_*.png >/dev/null
rm -f "$OUT"/store_*.png
cp "$TMP"/store_*.png "$OUT"/
rm -rf "$TMP"
python3 tools/store/make_feature.py
python3 tools/store/check_listing.py
godot --headless --path . --import >/dev/null 2>&1
ls -la "$OUT" store/graphics

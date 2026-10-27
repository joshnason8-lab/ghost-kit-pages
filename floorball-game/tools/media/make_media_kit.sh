#!/usr/bin/env bash
# The media kit for the website, made from the game as it is now: the screenshots and menus (PNG, 1920 x 1080, High),
# the icons, the trailer (16:9, about 41 s) and its vertical cut (9:16, 15 s), the website text and the credits, as
# media-kit-floorball-unleashed.zip. Run from floorball-game/; needs Godot 4.7, xvfb-run, ffmpeg and Pillow.
#   bash tools/media/make_media_kit.sh <out dir> [version]
# The GitHub workflow "Floorball Unleashed · media kit" runs it and puts the zip on the release floorball-unleashed-media.
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=$(realpath -m "${1:-/tmp/floorball-media}")
VERSION=${2:-$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)}
mkdir -p "$OUT"
rm -rf "$OUT/frames" "$OUT/screenshots" "$OUT/menus"
GODOT=(xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --fixed-fps 30
	res://tools/media/media_kit.tscn --)
"${GODOT[@]}" "$OUT" menus 2>&1 | grep -E "^media|SCRIPT ERROR" || true
"${GODOT[@]}" "$OUT" clips 2>&1 | grep -E "^media|SCRIPT ERROR" || true
python3 -I tools/media/make_trailer.py "$OUT" "$VERSION"

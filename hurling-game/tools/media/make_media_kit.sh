#!/usr/bin/env bash
# The website's media kit, made again from the current build (the CI workflow "Hurling Heroes · Media kit" runs it and
# publishes the zip on the hurling-heroes-media release):
#   tools/media/make_media_kit.sh [work dir]     -> <work dir>/media-kit-hurling-heroes.zip
# screenshots/ (12 PNGs at 1920 x 1080 from tools/store/store_shots.tscn -- media), menus/ (every menu screen,
# tools/media/menus.tscn), icons/, trailer/ (the trailer from tools/media/trailer.tscn's footage, cut by
# tools/media/assemble.py), text/ (the website's copy, tools/media/text/), CREDITS.txt. Everything on High with the HD
# pack, on Vulkan. Run from hurling-game/. Needs Godot 4.7, a display (or xvfb-run), ffmpeg, python3 with Pillow.
# Nothing it makes is committed: the video is large.
set -euo pipefail
cd "$(dirname "$0")/../.."
WORK=$(realpath -m "${1:-build/media}")
rm -rf "$WORK"
mkdir -p "$WORK/kit/screenshots" "$WORK/kit/menus" "$WORK/footage"
python3 tools/ultra/fetch.py > /dev/null
godot --headless --path . --import > /dev/null 2>&1 || true
RUN=(godot)
if [ -z "${DISPLAY:-}" ]; then
	RUN=(xvfb-run -a -s "-screen 0 1920x1080x24" godot)
fi
"${RUN[@]}" --path . --resolution 1920x1080 --fixed-fps 30 res://tools/store/store_shots.tscn -- media "out=$WORK/kit/screenshots" 2>&1 | grep -E "^shot|SCRIPT ERROR" || true
"${RUN[@]}" --path . --resolution 1920x1080 --fixed-fps 30 res://tools/media/menus.tscn -- "$WORK/kit/menus" 2>&1 | grep -E "^menu|SCRIPT ERROR" || true
"${RUN[@]}" --path . --resolution 1920x1080 --fixed-fps 30 res://tools/media/trailer.tscn -- "$WORK/footage" 2>&1 | grep -E "^trailer|SCRIPT ERROR" || true
test "$(ls "$WORK/kit/screenshots" | wc -l)" -ge 8
test "$(ls "$WORK/kit/menus" | wc -l)" -ge 15
test -s "$WORK/footage/shots.json"
python3 tools/media/assemble.py "$WORK/footage" "$WORK/kit"
ls -la "$WORK"

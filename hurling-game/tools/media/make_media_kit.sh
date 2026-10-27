#!/usr/bin/env bash
# The website's media kit, made again from the current build (the CI workflow "Hurling Heroes · Media kit" runs its
# steps in parallel jobs and publishes the zip on the hurling-heroes-media release):
#   tools/media/make_media_kit.sh <work dir> [step]     -> <work dir>/media-kit-hurling-heroes.zip
# The steps, each into <work dir> (all of them in turn when none is given):
#   shots       kit/screenshots/: 12 PNGs at 1920 x 1080 (tools/store/store_shots.tscn -- media)
#   menus       kit/menus/: every menu screen (tools/media/menus.tscn)
#   footage [n,n]  footage/seg_<n>/: the trailer's shots from real matches (tools/media/trailer.tscn; all, or those)
#   assemble    the trailer and its vertical cut, icons/, text/ (tools/media/text/), CREDITS.txt, and the zip
#               (tools/media/assemble.py)
# Everything on High with the HD pack, on Vulkan: on a software renderer each picture takes minutes. Run from
# hurling-game/. Needs Godot 4.7, a display (or xvfb-run), ffmpeg, python3 with Pillow. Nothing it makes is committed.
set -euo pipefail
cd "$(dirname "$0")/../.."
WORK=$(realpath -m "${1:-build/media}")
STEP=${2:-all}
mkdir -p "$WORK/kit/screenshots" "$WORK/kit/menus" "$WORK/footage"
RUN=(godot)
if [ -z "${DISPLAY:-}" ]; then
	RUN=(xvfb-run -a -s "-screen 0 1920x1080x24" godot)
fi
GODOT=("${RUN[@]}" --path . --resolution 1920x1080 --fixed-fps 30)
if [ "$STEP" != "assemble" ]; then
	python3 tools/ultra/fetch.py > /dev/null
	godot --headless --path . --import > /dev/null 2>&1 || true
fi
if [ "$STEP" = all ] || [ "$STEP" = shots ]; then
	"${GODOT[@]}" res://tools/store/store_shots.tscn -- media "out=$WORK/kit/screenshots" 2>&1 | grep -E "^shot|SCRIPT ERROR" || true
	test "$(ls "$WORK/kit/screenshots" | wc -l)" -ge 8
fi
if [ "$STEP" = all ] || [ "$STEP" = menus ]; then
	"${GODOT[@]}" res://tools/media/menus.tscn -- "$WORK/kit/menus" 2>&1 | grep -E "^menu|SCRIPT ERROR" || true
	test "$(ls "$WORK/kit/menus" | wc -l)" -ge 15
fi
if [ "$STEP" = all ] || [ "$STEP" = footage ]; then
	"${GODOT[@]}" res://tools/media/trailer.tscn -- "$WORK/footage" ${3:-} 2>&1 | grep -E "^trailer|SCRIPT ERROR" || true
	ls "$WORK"/footage/seg_*/info.json
fi
if [ "$STEP" = all ] || [ "$STEP" = assemble ]; then
	python3 tools/media/assemble.py "$WORK/footage" "$WORK/kit"
	ls -la "$WORK"
fi

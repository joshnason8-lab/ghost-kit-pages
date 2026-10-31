#!/usr/bin/env bash
# Makes the Play store kit again from the current build, just before it is submitted (store/PLAY_STORE.md, step 8):
# the nine 1920 x 1080 screenshots on High with the HD pack (on Vulkan, as a recent phone draws them), the 512 icon
# (32-bit PNG) and the 1024 x 500 feature graphic, then checks the listing text against Play's limits.
#   tools/store/make_store_kit.sh            everything (about an hour on a software renderer; minutes on a GPU)
#   tools/store/make_store_kit.sh menus      only the menu screenshots (05 to 09)
# Run from hurling-game/. Needs Godot 4.7 on the PATH, a display (or xvfb-run), python3 with Pillow.
set -euo pipefail
cd "$(dirname "$0")/../.."
python3 tools/ultra/fetch.py > /dev/null      # the HD pack's large sources, so High draws as with the pack
godot --headless --path . --import > /dev/null 2>&1 || true
RUN=(godot)
if [ -z "${DISPLAY:-}" ]; then
	RUN=(xvfb-run -a -s "-screen 0 1920x1080x24" godot)
fi
if [ -z "${1:-}" ]; then
	"${RUN[@]}" --path . --resolution 1920x1080 --fixed-fps 30 res://tools/store/store_shots.tscn 2>&1 | grep -E "^shot|SCRIPT ERROR"
else
	"${RUN[@]}" --path . --resolution 1920x1080 --fixed-fps 30 res://tools/store/store_shots.tscn -- "$1" 2>&1 | grep -E "^shot|SCRIPT ERROR"
fi
python3 tools/store/make_icons.py
python3 tools/store/make_feature.py
python3 tools/store/check_listing.py
ls -la store/graphics store/graphics/screenshots

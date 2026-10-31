#!/usr/bin/env bash
# The store's pictures and the media kit's, from the current build (store/PLAY_STORE.md, "Graphics").
#   tools/store/make_kit.sh [OUT_DIR]     (needs godot 4.7, xvfb-run and Pillow; about 20 minutes)
# Writes store/graphics/ (icon-512, icon-1024, feature-1024x500 and the seven screenshots) and, in OUT_DIR
# (default build/kit): menus/ (every screen, 1920 x 1080) and action/ (each ground's wide view and a kho, a dive, a
# pole turn and an out on it). Runs with an empty user folder, so the pictures show a new player's settings and the
# machine's own saves are left alone.
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="${1:-build/kit}"
OUT="$(mkdir -p "$OUT" && cd "$OUT" && pwd)"
export XDG_DATA_HOME="$(mktemp -d)"
trap 'rm -rf "$XDG_DATA_HOME"' EXIT
GD=(xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3)

"${GD[@]}" res://tests/media_tour.tscn -- "$OUT/menus" menus
"${GD[@]}" res://tests/media_tour.tscn -- "$OUT/action" action
"${GD[@]}" res://tests/screenshots.tscn -- "$OUT/tour" en 1920x1080
"${GD[@]}" res://tests/screenshots.tscn -- "$OUT/tour_clean" en 1920x1080 clean
python3 tools/store/make_feature.py "$OUT/tour" "$OUT/tour_clean"
python3 tools/store/make_icons.py
ls "$OUT/menus" "$OUT/action" store/graphics store/graphics/screenshots

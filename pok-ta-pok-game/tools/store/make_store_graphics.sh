#!/usr/bin/env bash
# Remakes the Play store graphics from the game as it is now (they are drafts until the game is submitted: run this
# just before, so they show the current build):
#   store/graphics/screenshots/   eight 1920 x 1080 screenshots on High graphics (tools/store/store_shots.gd, "store")
#   store/graphics/feature-1024x500.png   the feature graphic, from a fresh render of the stone court and its ring
#   store/graphics/icon-512.png   the hi-res icon (32-bit PNG), from the launcher icon
#   tools/store/make_store_graphics.sh      (from pok-ta-pok-game/; needs godot, xvfb-run, python3 + Pillow)
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-godot}
XVFB=(xvfb-run -a -s "-screen 0 1920x1080x24")
python3 tools/build_i18n.py >/dev/null
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "== screenshots"
"${XVFB[@]}" "$GODOT" --path . --rendering-driver opengl3 --fixed-fps 30 res://tools/store/store_shots.tscn -- \
  "$PWD/store/graphics/screenshots" store | grep '^shot'

echo "== feature graphic"
TMP=$(mktemp -d)
"${XVFB[@]}" "$GODOT" --path . --rendering-driver opengl3 res://tools/store/icon_render.tscn -- "$TMP" feature >/dev/null 2>&1
python3 - "$TMP/feature_render.png" <<'PY'
import sys
from PIL import Image
Image.open(sys.argv[1]).convert("RGB").save("tools/store/feature_source.webp", quality=92)
PY
rm -rf "$TMP"
python3 tools/store/make_feature.py

echo "== icon and formats"
python3 - <<'PY'
import pathlib
from PIL import Image
# Play: the icon a 32-bit PNG; screenshots and the feature graphic 24-bit PNG (no alpha).
Image.open("assets/icon/icon_512.png").convert("RGBA").save("store/graphics/icon-512.png")
for p in [pathlib.Path("store/graphics/feature-1024x500.png")] + sorted(pathlib.Path("store/graphics/screenshots").glob("*.png")):
    Image.open(p).convert("RGB").save(p, optimize=True)
    print(p, Image.open(p).size)
PY

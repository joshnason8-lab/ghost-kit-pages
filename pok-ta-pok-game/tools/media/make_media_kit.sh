#!/usr/bin/env bash
# The media kit for the website, rendered from the game as it is now:
#   media-kit-pok-ta-pok-rivals/screenshots/   twelve 1920 x 1080 PNGs on High graphics (tools/store/store_shots.gd, "media")
#   media-kit-pok-ta-pok-rivals/menus/         every menu screen in English, 1920 x 1080 PNGs ("menus" set)
#   media-kit-pok-ta-pok-rivals/text/          the website's copy: about, features, facts, the sport, a press blurb
#   media-kit-pok-ta-pok-rivals/icons/         the icon at 1024 and 512, and the 1024 x 500 feature graphic
#   media-kit-pok-ta-pok-rivals/trailer/       the trailer (1920 x 1080, ~36 s) and a 15 s vertical cut (1080 x 1920)
#   media-kit-pok-ta-pok-rivals/CREDITS.txt    every outside work in the pictures and the sound
# zipped as media-kit-pok-ta-pok-rivals.zip in OUT_DIR. The game is recorded with Godot's Movie Maker (its own
# pictures and sound, frame by frame), so it needs a display: run it under xvfb-run. Rendering is slow without a GPU
# (an hour or more on a CPU-only machine).
#   tools/media/make_media_kit.sh OUT_DIR        (from pok-ta-pok-game/; needs godot, xvfb-run, ffmpeg, python3 + Pillow)
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=$(realpath -m "${1:?OUT_DIR}")
KIT="$OUT/media-kit-pok-ta-pok-rivals"
WORK="$OUT/work"
GODOT=${GODOT:-godot}
XVFB=(xvfb-run -a -s "-screen 0 1920x1080x24")
mkdir -p "$KIT/screenshots" "$KIT/menus" "$KIT/text" "$KIT/icons" "$KIT/trailer" "$WORK/clips" "$WORK/cards"

python3 tools/build_i18n.py >/dev/null
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "== screenshots"
"${XVFB[@]}" "$GODOT" --path . --rendering-driver opengl3 --fixed-fps 30 res://tools/store/store_shots.tscn -- "$KIT/screenshots" media \
  | grep '^shot'
echo "== menus"
"${XVFB[@]}" "$GODOT" --path . --rendering-driver opengl3 --fixed-fps 30 res://tools/store/store_shots.tscn -- "$KIT/menus" menus \
  | grep '^shot'
python3 - "$KIT/screenshots" "$KIT/menus" <<'PY'
import pathlib, sys
from PIL import Image
for d in sys.argv[1:]:
    for p in sorted(pathlib.Path(d).glob("*.png")):
        Image.open(p).convert("RGB").save(p, optimize=True)
PY
cp tools/media/text/*.md "$KIT/text/"

echo "== icons"
python3 - "$KIT/icons" <<'PY'
import pathlib, sys
from PIL import Image
out = pathlib.Path(sys.argv[1])
src = Image.open("tools/store/icon_render_source.webp").convert("RGBA")
# The icon is a full-bleed picture (the ring and the ball on stone), so it has no transparent background.
src.resize((1024, 1024), Image.LANCZOS).save(out / "icon-1024.png")
Image.open("store/graphics/icon-512.png").convert("RGBA").save(out / "icon-512.png")
Image.open("store/graphics/feature-1024x500.png").convert("RGB").save(out / "feature-1024x500.png")
PY

echo "== trailer clips"
# Movie Maker records at the window's size: 1920 x 1080 for the recording only.
printf '[display]\n\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n' > override.cfg
trap 'rm -f override.cfg' EXIT
for clip in menu ritual village dive night festival ring; do
  dir="$WORK/clips/$clip"
  rm -rf "$dir" && mkdir -p "$dir"
  "${XVFB[@]}" "$GODOT" --path . --rendering-driver opengl3 --fixed-fps 30 --write-movie "$dir/f.png" \
    res://tools/media/trailer_clip.tscn -- "$clip" 2>&1 | grep '^MARK' > "$dir/marks.txt"
  echo "$clip: $(ls "$dir" | grep -c png) frames; $(tr '\n' ' ' < "$dir/marks.txt")"
done
rm -f override.cfg

echo "== trailer"
python3 tools/media/cards.py "$WORK/cards"
python3 tools/media/cut_trailer.py "$WORK/clips" "$WORK/cards" "$KIT/trailer"

cp tools/media/CREDITS.txt "$KIT/CREDITS.txt"
( cd "$OUT" && rm -f media-kit-pok-ta-pok-rivals.zip && zip -qr media-kit-pok-ta-pok-rivals.zip media-kit-pok-ta-pok-rivals )
ls -la "$OUT/media-kit-pok-ta-pok-rivals.zip"

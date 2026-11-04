#!/usr/bin/env bash
# The media kit, from the game itself (CI runs it: .github/workflows/kho-kho-media-kit.yml; about two hours):
#   tools/store/make_media_kit.sh [OUT_DIR]    (needs godot 4.7, xvfb-run, ffmpeg, zip and Pillow)
# Records footage of the AI playing on the four grounds and cuts it into the trailer and a 15 s vertical cut
# (make_trailer.py), photographs every screen and each ground in play (tests/media_tour), and zips them with the
# icons, the feature graphic, the texts in store/media/text and the credits: OUT_DIR/media-kit-kho-kho-rush.zip.
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="${1:-build/media}"
mkdir -p "$OUT" && OUT="$(cd "$OUT" && pwd)"
VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
export XDG_DATA_HOME="$(mktemp -d)"
GD=(xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3)
# Movie Maker takes the window's size from the project, so the film is made at 1080p with a passing override.
trap 'rm -rf "$XDG_DATA_HOME" override.cfg' EXIT
printf '[display]\n\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n' > override.cfg
"${GD[@]}" --write-movie "$OUT/footage.avi" --fixed-fps 30 res://tests/trailer_rec.tscn -- "$OUT/footage.json" 24
rm -f override.cfg
"${GD[@]}" res://tests/media_tour.tscn -- "$OUT/menus" menus
"${GD[@]}" res://tests/media_tour.tscn -- "$OUT/action" action
python3 tools/store/make_trailer.py "$OUT/footage.avi" "$OUT/footage.json" "$OUT/trailer"

K="$OUT/media-kit-kho-kho-rush"
rm -rf "$K" && mkdir -p "$K"/{trailer,screenshots,store,icons,menus,text}
cp "$OUT"/trailer/*.mp4 "$K/trailer/"
# Twelve pictures: each ground's wide view, then the moments, mixed across grounds (those that were caught).
i=1
for n in maidan_ground school_ground floodlit_ground arena_ground maidan_kho school_pole_turn floodlit_out arena_dive \
    maidan_out school_kho floodlit_pole_turn arena_kho maidan_dive school_out floodlit_kho arena_pole_turn \
    maidan_pole_turn school_dive floodlit_dive arena_out; do
  f="$OUT/action/$n.png"
  if [ -f "$f" ] && [ $i -le 12 ]; then cp "$f" "$K/screenshots/$(printf %02d $i)_$n.png"; i=$((i + 1)); fi
done
cp "$OUT"/menus/*.png "$K/menus/"
cp store/graphics/feature-1024x500.png "$K/store/"
python3 tools/store/make_icons.py
cp store/graphics/icon-1024.png store/graphics/icon-512.png "$K/icons/"
cp store/media/text/*.md "$K/text/"
sed "s/VERSION/$VERSION/" store/media/README.txt > "$K/README.txt"
sed "s/VERSION/$VERSION/" store/media/CREDITS.txt > "$K/CREDITS.txt"
(cd "$OUT" && rm -f media-kit-kho-kho-rush.zip && zip -qr media-kit-kho-kho-rush.zip media-kit-kho-kho-rush)
ls -la "$OUT/media-kit-kho-kho-rush.zip"

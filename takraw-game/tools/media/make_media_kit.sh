#!/usr/bin/env bash
# The media kit for the owner's website, made from the game itself (nothing in it is drawn by hand):
#   screenshots/  the moments and the menus, 1920 x 1080 PNG, on High (tools/media/trailer.gd, stills)
#   menus/        every menu screen, clean and in English, 1920 x 1080 PNG named by screen (trailer.gd, menus)
#   icons/        the icon at 1024 and 512 px, and the store's 1024 x 500 feature graphic
#   trailer/      the trailer, 1920 x 1080, 30 fps, H.264 with AAC, and a 15-second 1080 x 1920 cut for social media:
#                 filmed with Godot's Movie Maker from real AI-v-AI matches, the game's own sound under the menu music
#   text/         the website's copy (tools/media/text/*.md, the version and download size filled in)
#   CREDITS.txt   whose sounds, music and pieces are in it, under what licences
# and zips it as media-kit-sepak-takraw-unleashed.zip. The videos are not kept in the repository: run this again
# (or the "Sepak Takraw Unleashed · Media kit" workflow) to remake them from the current build.
#   tools/media/make_media_kit.sh [OUTDIR]     (needs Godot 4.7 on PATH as godot, xvfb-run, ffmpeg, python3 + Pillow)
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=$(realpath -m "${1:-build/media}")
NAME=media-kit-sepak-takraw-unleashed
KIT=$OUT/$NAME
RAW=$OUT/raw
rm -rf "$KIT" "$RAW" "$OUT/$NAME.zip"
mkdir -p "$KIT/screenshots" "$KIT/menus" "$KIT/icons" "$KIT/trailer" "$KIT/text" "$RAW"

# Each run's window size and Movie Maker's settings, for these runs only (an override.cfg next to project.godot is read
# at start-up; Movie Maker films at the window size it sets, not at --resolution's).
trap 'rm -f override.cfg' EXIT

run() {   # resolution, then the scene's arguments; Movie Maker's output when a fourth is given
	local res=$1 dir=$2 mode=$3 movie=${4:-}
	local extra=()
	[ -n "$movie" ] && extra=(--fixed-fps 30 --write-movie "$movie")
	printf '[display]\nwindow/size/window_width_override=%s\nwindow/size/window_height_override=%s\n[editor]\nmovie_writer/mjpeg_quality=0.95\nmovie_writer/fps=30\n' \
		"${res%x*}" "${res#*x}" > override.cfg
	xvfb-run -a -s "-screen 0 ${res}x24" godot --path . --rendering-driver opengl3 --resolution "$res" "${extra[@]}" \
		res://tools/media/trailer.tscn -- "$dir" "$mode" 2>&1 | grep -E "^(shot|still) |SCRIPT ERROR|trailer:" || true
}

echo "== screenshots"
run 1920x1080 "$KIT/screenshots" stills
echo "== menus"
run 1920x1080 "$KIT/menus" menus
echo "== trailer (1920 x 1080)"
run 1920x1080 "$RAW" trailer "$RAW/trailer.avi"
echo "== vertical cut (1080 x 1920)"
run 1080x1920 "$RAW" vertical "$RAW/vertical.avi"

# The game's sound as filmed, the menu music under it (faded in and out), H.264 + AAC for every player and site.
encode() {   # in, out, longest seconds
	local in=$1 out=$2 most=$3
	local dur
	dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$in")
	dur=$(python3 -c "print(min(float('$dur'), $most))")
	local fo
	fo=$(python3 -c "print(max(0.0, $dur - 2.5))")
	ffmpeg -y -v error -i "$in" -i assets/audio/menu_music.ogg -t "$dur" -filter_complex \
		"[1:a]volume=0.30,afade=t=in:d=1.5,afade=t=out:st=$fo:d=2.5[mu];[0:a][mu]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.9[a];[0:v]format=yuv420p,fade=t=out:st=$(python3 -c "print(max(0.0, $dur - 0.5))"):d=0.5[v]" \
		-map "[v]" -map "[a]" -c:v libx264 -preset slow -crf 19 -profile:v high -r 30 -c:a aac -b:a 192k -ar 48000 \
		-movflags +faststart "$out"
	echo "$(basename "$out"): $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out") s, $(du -h "$out" | cut -f1)"
}
echo "== encoding"
encode "$RAW/trailer.avi" "$KIT/trailer/sepak-takraw-unleashed-trailer-1080p.mp4" 45
encode "$RAW/vertical.avi" "$KIT/trailer/sepak-takraw-unleashed-vertical-15s.mp4" 15

echo "== icons"
python3 - "$KIT/icons" <<'EOF'
import shutil, sys
from PIL import Image
out = sys.argv[1]
src = Image.open("store/graphics/icon_source.jpg").convert("RGBA")
for n in (1024, 512):
    src.resize((n, n), Image.LANCZOS).save(f"{out}/icon-{n}.png")
shutil.copy("store/graphics/feature-1024x500.png", f"{out}/feature-1024x500.png")
EOF

echo "== text"
VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
APK_SIZE=$(curl -s ${GH_TOKEN:+-H "Authorization: Bearer $GH_TOKEN"} \
	https://api.github.com/repos/joshnason8-lab/ghost-kit-pages/releases/tags/sepak-takraw-unleashed-beta \
	| python3 -c "import json,sys; a=[x for x in json.load(sys.stdin).get('assets',[]) if x['name'].endswith('.apk')]; print('%.0f MB' % (a[0]['size']/1e6) if a else '')" 2>/dev/null || true)
for f in tools/media/text/*.md; do
	sed -e "s/{VERSION}/$VERSION/g" -e "s/{APK_SIZE}/${APK_SIZE:-about 128 MB}/g" "$f" > "$KIT/text/$(basename "$f")"
done

cat > "$KIT/CREDITS.txt" <<'EOF'
Sepak Takraw Unleashed: media kit
Made by Josh Nason. Everything here is captured from the game itself (Android, Godot Engine 4.7), on High graphics.
Contact: joshnason8@gmail.com

screenshots/  1920 x 1080 PNG: moments from AI-v-AI matches in the five venues, and the menus.
menus/        1920 x 1080 PNG: every menu screen, in English, named by screen.
text/         copy for a website, in Markdown: about, features, facts, the sport, a press blurb.
icons/        the icon at 1024 and 512 px (PNG), the 1024 x 500 feature graphic.
trailer/      the trailer (1920 x 1080, 30 fps, H.264, AAC) and a 15-second vertical cut (1080 x 1920).

THE TRAILER'S SOUND
Music: "Kingdom of a Million Elephants under a White Parasol" by Spring Spring (Julie Damsgaard), CC0
  (opengameart.org/content/kingdom-of-a-million-elephants-under-a-white-parasol).
The game's own sounds, as heard in the matches:
- The crowd's murmur and cheers: "Free Crowd Cheering Sounds" by Gregor Quendel (www.gregorquendel.com;
  opengameart.org/content/free-crowd-cheering-sounds), CC BY 4.0, cut and levelled for the game.
- Applause: "Applause in a large hall or church" by eXpl0it3r (CC0); "Applause" by the Blender Foundation
  (opengameart.org/content/applause), CC BY 3.0.
- The sea at the beach and the evening at the park: "Nature Ambient Pack Vol 1" by JC Sounds
  (opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1), CC BY 4.0.
- Footsteps: "Footsteps on different surfaces" by congusbongus, from recordings by swuing and ceberation
  (opengameart.org/content/footsteps-on-different-surfaces), CC BY 3.0; footsteps on sand by Fantozzi (CC0).
- The referee's whistle: Pixabay (Pixabay Content License): "Referee whistle" by charlesheffley009, "Referee whistle /
  coach whistle / sports whistle" by framptones, "Metal whistle" and "Referee whistle blow, gymnasium" by
  freesound_community.
- The ball: sound effects from Mixkit (mixkit.co), Mixkit Sound Effects Free License. Impacts and the net from Kenney
  (kenney.nl), CC0.
- The arena's drums, the crowd's "ooh" and groan, the players' calls: made for the games, the owner's own.
(The mall's background chatter, CC BY-SA 4.0, is silenced in the trailer's mall shot, so no share-alike sound is in it.)

THE PICTURES
Players, ball, officials and most venue models: made for the game (Meshy, meshy.ai, for the owner). Skies, surfaces
and other venue pieces: Poly Haven (polyhaven.com), CC0. Motion capture: Mixamo; and the CMU Graphics Lab Motion
Capture Database (mocap.cs.cmu.edu), created with funding from NSF EIA-0196217. Fonts: Noto Sans and Teko, SIL Open
Font License 1.1. Godot Engine (godotengine.org), MIT licence.

Sepak Takraw Unleashed is an independent game, not affiliated with or endorsed by any sepak takraw federation,
league, club or player.
EOF

cd "$OUT"
rm -f "$NAME.zip"
zip -q -r "$NAME.zip" "$NAME"
echo "== $(ls -l "$NAME.zip" | awk '{print $5}') bytes: $OUT/$NAME.zip"

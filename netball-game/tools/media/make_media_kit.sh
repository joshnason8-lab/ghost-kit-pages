#!/usr/bin/env bash
# The media kit for the website: screenshots, every menu screen, icons, a trailer and a vertical cut, the website
# copy (tools/media/text), the credits, and a zip of it all.
#   cd netball-game && tools/media/make_media_kit.sh [OUT_DIR]        (default build/media)
# Needs godot (4.7) on PATH (or GODOT=...), xvfb-run, ffmpeg and python3 with Pillow. The project must have been
# imported once (godot --headless --path . --import). On software GL (CI, a headless box) the trailer's ~900 High
# frames take about 15-20 minutes; the screenshots about a minute.
# SKIP_TRAILER=1 makes only the screenshots, icons and credits (and a zip without the trailer).
set -euo pipefail

cd "$(dirname "$0")/../.."
OUT="${1:-build/media}"
GODOT="${GODOT:-godot}"
WORK="$OUT/work"
mkdir -p "$OUT" "$WORK"
OUT="$(cd "$OUT" && pwd)"
WORK="$OUT/work"
rm -rf "$OUT/screenshots" "$OUT/menus" "$OUT/icons" "$OUT/trailer" "$OUT/text" "$OUT"/*.zip

# A 1920x1080 screen for the window; the opengl3 driver (Low, Medium and High are GL Compatibility).
# godot_x SECONDS args...: Godot under Xvfb, stopped after SECONDS.
godot_x() {
  local secs=$1
  shift
  timeout "$secs" xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --fixed-fps 30 "$@" < /dev/null
}

# Godot does not fail on a script error: the log is read for them.
check_log() {
  if grep -q "SCRIPT ERROR" "$1"; then
    grep -A4 "SCRIPT ERROR" "$1"
    echo "make_media_kit: script error (see $1)" >&2
    exit 1
  fi
}

start=$(date +%s)
echo "== icons"
python3 tools/media/compose.py icons "$OUT"

echo "== screenshots and menus"
rm -rf "$WORK/shots"
godot_x 1800 res://tests/screenshots.tscn -- "$WORK/shots" en media,kitmenus high > "$WORK/shots.log" 2>&1 || true
check_log "$WORK/shots.log"
grep -c "^saved" "$WORK/shots.log" || true
python3 tools/media/compose.py screens "$WORK/shots" "$OUT"

echo "== credits and text"
python3 tools/media/compose.py credits "$OUT"
python3 tools/media/compose.py text "$OUT"

if [ "${SKIP_TRAILER:-0}" != 1 ]; then
  echo "== scanning the matches (no drawing)"
  while read -r venue home away seed frames; do
    rm -rf "$WORK/scan_$venue"
    godot_x 900 res://tools/media/record.tscn -- "$WORK/scan_$venue" "$venue" "$home" "$away" "$seed" "$frames" \
      > "$WORK/scan_$venue.log" 2>&1
    check_log "$WORK/scan_$venue.log"
    tail -1 "$WORK/scan_$venue.log"
  done < <(python3 tools/media/compose.py venues)

  echo "== the trailer's moments"
  python3 tools/media/compose.py plan "$WORK" > "$WORK/windows.txt"
  cat "$WORK/windows.txt"

  echo "== recording them on High"
  while read -r venue last windows; do
    read -r _ home away seed _ < <(python3 tools/media/compose.py venues | grep "^$venue ")
    rm -rf "$WORK/shoot_$venue"
    t0=$(date +%s)
    godot_x 3600 res://tools/media/record.tscn -- "$WORK/shoot_$venue" "$venue" "$home" "$away" "$seed" \
      "$last" "$windows" > "$WORK/shoot_$venue.log" 2>&1
    check_log "$WORK/shoot_$venue.log"
    echo "$venue: $(tail -1 "$WORK/shoot_$venue.log") in $(( $(date +%s) - t0 )) s"
  done < "$WORK/windows.txt"
  python3 tools/media/compose.py check "$WORK"

  echo "== cutting the trailers"
  python3 tools/media/compose.py trailer "$WORK" "$OUT"
  for f in "$OUT"/trailer/*.mp4; do
    ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate:format=duration,size -of compact "$f"
  done
else
  mkdir -p "$OUT/trailer"
fi

echo "== zip"
python3 tools/media/compose.py zip "$OUT"
echo "make_media_kit: done in $(( $(date +%s) - start )) s: $OUT"

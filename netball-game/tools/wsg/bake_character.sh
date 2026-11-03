#!/bin/sh
# Bakes a rigged character onto the World Stage Games rig (bake_character.gd says what it does).
#   tools/bake_character.sh <model.glb|.fbx> <out dir> <prefix> [tris_hi] [tris_lo]
# Needs godot 4.7 on the PATH. Works in a scratch project; writes <out>/<prefix>_hi.res, _lo.res, _rig.json.
# A script error stops it (Godot's -s run would otherwise sit there for ever) with the error printed and exit 1, as
# does taking longer than BAKE_TIMEOUT seconds (default 1200; a big model's bake takes a few minutes).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
# (The foundation's own tools/, or a game's tools/wsg/ after vendor.sh.)
if [ -d "$HERE/../addons/wsg_foundation" ]; then ADDON=$(cd "$HERE/../addons/wsg_foundation" && pwd); else ADDON=$(cd "$HERE/../../addons/wsg_foundation" && pwd); fi
MODEL=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
OUT=$(mkdir -p "$2" && cd "$2" && pwd)
WORK=$(mktemp -d)
mkdir -p "$WORK/src" "$WORK/addons"
printf 'config_version=5\n[application]\nconfig/name="bake"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n' > "$WORK/project.godot"
cp -r "$ADDON" "$WORK/addons/wsg_foundation"
rm -rf "$WORK/addons/wsg_foundation/data"
cp "$HERE/bake_character.gd" "$WORK/"
EXT="${MODEL##*.}"
cp "$MODEL" "$WORK/src/model.$EXT"
godot --headless --path "$WORK" --import >/dev/null 2>&1 || true
# Parse errors first (a -s run of a script that does not parse never quits).
if ! godot --headless --path "$WORK" --check-only -s bake_character.gd > "$WORK/check.log" 2>&1 || grep -q "Parse Error\|SCRIPT ERROR" "$WORK/check.log"; then
	grep -A3 "Parse Error\|SCRIPT ERROR\|ERROR" "$WORK/check.log" >&2 || cat "$WORK/check.log" >&2
	echo "bake_character.sh: bake_character.gd does not compile (above)" >&2
	rm -rf "$WORK"
	exit 1
fi
# The bake, watched: its output shown as it comes; a script error or the time limit ends it.
LOG="$WORK/bake.log"
: > "$LOG"
godot --headless --path "$WORK" -s bake_character.gd -- "res://src/model.$EXT" "$OUT" "$3" ${4:-6000} ${5:-2000} > "$LOG" 2>&1 &
PID=$!
# Shown as it comes where tail can follow a process (GNU); otherwise all at the end.
TAIL=""
if tail --pid=$PID -n 0 "$LOG" >/dev/null 2>&1; then
	tail -n +1 -f "$LOG" --pid=$PID &
	TAIL=$!
fi
LIMIT=${BAKE_TIMEOUT:-1200}
WAITED=0
FAILED=""
while kill -0 $PID 2>/dev/null; do
	if grep -q "SCRIPT ERROR\|Parse Error" "$LOG"; then
		FAILED="a script error"
		break
	fi
	if [ "$WAITED" -ge "$LIMIT" ]; then
		FAILED="no end after $LIMIT s (BAKE_TIMEOUT)"
		break
	fi
	sleep 1
	WAITED=$((WAITED + 1))
done
if [ -n "$FAILED" ]; then
	sleep 1
	kill $PID 2>/dev/null || true
	wait $PID 2>/dev/null || true
	if [ -n "$TAIL" ]; then kill $TAIL 2>/dev/null || true; else cat "$LOG"; fi
	echo "" >&2
	echo "bake_character.sh: stopped: $FAILED" >&2
	grep -A6 "SCRIPT ERROR\|Parse Error" "$LOG" >&2 || true
	rm -rf "$WORK"
	exit 1
fi
STATUS=0
wait $PID || STATUS=$?
if [ -n "$TAIL" ]; then sleep 0.2; kill $TAIL 2>/dev/null || true; else cat "$LOG"; fi
rm -rf "$WORK"
if [ "$STATUS" -ne 0 ]; then
	echo "bake_character.sh: the bake failed (exit $STATUS; above)" >&2
	exit "$STATUS"
fi

#!/usr/bin/env bash
# The soak test (tests/soak_test.gd) with its log read: a monkey of random input on every screen, then AI-v-AI
# matches on Low and High. Fails if the log has a script error, an engine error or a soak complaint.
#   tools/soak.sh [events] [matches] [log]
# The monkey needs a window (controls are picked under the pointer). The matches alone (events 0) run headless: on a
# desktop without a GPU, software OpenGL draws a match at about a frame a second, and a whole match would take hours.
set -u
cd "$(dirname "$0")/.."
EVENTS=${1:-3000}
MATCHES=${2:-12}
LOG=${3:-/tmp/soak.log}
if [ "$EVENTS" = "0" ]; then
	RUN=(godot --headless)
else
	RUN=(xvfb-run -a godot --rendering-driver opengl3)
fi
timeout 14400 "${RUN[@]}" --path . --fixed-fps 30 res://tests/soak_test.tscn -- "$EVENTS" "$MATCHES" > "$LOG" 2>&1
STATUS=$?
grep "^soak:" "$LOG"
# What a run on a desktop without sound or a GPU always prints, and leaks at exit: not the game's.
ERRORS=$(grep -E "SCRIPT ERROR|^ERROR:|USER ERROR" "$LOG" | grep -v -E "ALSA|audio|PCM|Condition \"status < 0\"|init_output_device" | sort | uniq -c | sort -rn)
if [ -n "$ERRORS" ]; then
	echo "errors in the log:"
	echo "$ERRORS" | head -40
fi
grep -q "^soak: done" "$LOG" || { echo "the soak did not finish (exit $STATUS)"; exit 1; }
[ -z "$ERRORS" ] || exit 1
echo "soak: clean"

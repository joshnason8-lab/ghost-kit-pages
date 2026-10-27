#!/usr/bin/env bash
# The monkey test (tests/soak.gd): random taps, drags, Back, the app sent to the background and back, and matches
# started and left, on Low and on High; then fails if the engine printed any script error.
#   tools/soak.sh [EVENTS]     (default 3000 a run; about 15 minutes each on a laptop, longer headless)
set -uo pipefail
cd "$(dirname "$0")/.."
N="${1:-3000}"
export XDG_DATA_HOME="$(mktemp -d)"
trap 'rm -rf "$XDG_DATA_HOME"' EXIT
fail=0
for g in low high; do
  log="$XDG_DATA_HOME/soak-$g.log"
  xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/soak.tscn -- "$N" "$g" 7 > "$log" 2>&1
  code=$?
  grep -E "^soak|monkey:" "$log"
  errs=$(grep -c "SCRIPT ERROR" "$log")
  echo "$g: exit $code, $errs script errors"
  if [ "$code" -ne 0 ] || [ "$errs" -ne 0 ]; then grep -A3 "SCRIPT ERROR" "$log" | head -40; fail=1; fi
done
exit $fail

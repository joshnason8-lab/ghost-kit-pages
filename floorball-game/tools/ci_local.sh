#!/bin/bash
# The checks the "Floorstorm · Android build" action runs, run here before a push, so a push only fails CI for what
# cannot be caught on this machine (the Android export itself, which needs the Android SDK).
#   tools/ci_local.sh            everything
#   tools/ci_local.sh quick      the test_runner's quick mode and no fit audit (while working)
set -u
cd "$(dirname "$0")/.."
LOG=${CI_LOG_DIR:-/tmp/floorstorm-ci}
mkdir -p "$LOG"
fail=0
step() { echo "== $1"; }
bad() { echo "FAILED: $1"; fail=1; }

step "scripts parse";      python3 tools/check_scripts.py > "$LOG/check_scripts.log" 2>&1 || bad "check_scripts (see $LOG/check_scripts.log)"
step "translations";       python3 tools/build_i18n.py > "$LOG/i18n.log" 2>&1 || bad "build_i18n"
step "import";             timeout 600 godot --headless --path . --import > "$LOG/import.log" 2>&1
step "compile check";      timeout 300 godot --headless --path . res://tests/compile_check.tscn > "$LOG/compile.log" 2>&1 || bad "compile_check"
grep -q " 0 broken" "$LOG/compile.log" || bad "compile_check: $(grep broken "$LOG/compile.log")"

if [ "${1:-}" = "quick" ]; then
	step "test_runner (quick)"; timeout 1200 godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn -- quick > "$LOG/test_runner.log" 2>&1 || bad "test_runner"
else
	step "test_runner";        timeout 2400 godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn > "$LOG/test_runner.log" 2>&1 || bad "test_runner"
fi
grep "test_runner:" "$LOG/test_runner.log"
grep "^FAIL" "$LOG/test_runner.log" | head -20
grep -q "SCRIPT ERROR" "$LOG/test_runner.log" && { grep -A4 "SCRIPT ERROR" "$LOG/test_runner.log" | head -20; bad "script error in test_runner"; }

if [ "${1:-}" != "quick" ]; then
	step "fit audit";          timeout 2400 godot --headless --path . --fixed-fps 30 res://tests/fit_audit.tscn -- "$LOG/fit.jsonl" all 1280x720,2340x1080,2400x1080,2048x1536 > "$LOG/fit.log" 2>&1 || bad "fit_audit"
	tail -3 "$LOG/fit.log"
	grep -q "SCRIPT ERROR" "$LOG/fit.log" && { grep -A4 "SCRIPT ERROR" "$LOG/fit.log" | head -20; bad "script error in fit_audit"; }
	step "touch input";        timeout 600 xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/input_test.tscn > "$LOG/input.log" 2>&1 || bad "input_test"
	tail -2 "$LOG/input.log"
fi

if [ $fail -ne 0 ]; then echo "== NOT READY TO PUSH"; exit 1; fi
echo "== all green"

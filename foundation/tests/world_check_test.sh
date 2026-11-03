#!/bin/sh
# wsg_world_check's own test: the foundation's demo world (tests/world_demo/world.gd) keeps every rule, and each fault
# a game could have (world.gd's BAD) fails the rule it breaks - and only that rule.
#   sh tests/world_check_test.sh
cd "$(dirname "$0")/.."
OUT="${TMPDIR:-/tmp}/wsg_world_check_test"
export WSG_WORLD_ENFORCE=1
rm -rf "$OUT"
mkdir -p "$OUT"
RULES=feet,pose,officials,sounds,loading,joystick,web,tiers
GAME=res://tests/world_demo/world.gd
run() {
	name=$1
	shift
	godot --headless --fixed-fps 30 --path . -s res://tools/world_check.gd -- --game "$GAME" --out "$OUT/$name" "$@" > "$OUT/$name.log" 2>&1
}
FAIL=0
if ! run clean --only $RULES; then
	echo "world_check_test: the demo world fails a rule it keeps:"; grep -E "FAIL|NOT WIRED" "$OUT/clean.log"; FAIL=1
fi
for bad in loading pose officials feet sounds joystick tiers; do
	run "$bad" --only $RULES --bad "$bad"
	code=$?
	broke=$(grep -E "^[a-z]+ +(FAIL|NOT WIRED)" "$OUT/$bad.log" | awk '{print $1}' | tr '\n' ' ')
	if [ $code = 0 ] || [ "$broke" != "$bad " ]; then
		echo "world_check_test: --bad $bad: exit $code, rules failed: '$broke' (only $bad should)"; FAIL=1
	else
		echo "world_check_test: --bad $bad caught: $(grep -E "^$bad " "$OUT/$bad.log" | cut -c21- | cut -c1-150)"
	fi
done
# A walker the game advances itself (set_manual) is walked, not waited on for ever (Hurling's hung the feet rule).
# A mode freeing the last one's match (as a tap does): the later rules go on, and the check finishes (Hurling's and
# Floorball's stopped on a freed body and never printed WORLD CHECK).
run freed --only pose,officials,loading,joystick --bad freed
code=$?
if [ $code != 0 ] || ! grep -q "^WORLD CHECK: PASS" "$OUT/freed.log"; then
	echo "world_check_test: a mode freeing the last stopped the check (exit $code):"; grep -E "SCRIPT ERROR|FAIL|WORLD CHECK" "$OUT/freed.log" | head -8; FAIL=1
else
	echo "world_check_test: a mode freeing the last: the check went on and passed"
fi
# A failing audit fails its rule (it was reported PASS: Sepak Takraw's "crowd | PASS | crowd_audit failed (exit 1)").
run audit --only props --bad audit
if ! grep -qE "^props +FAIL" "$OUT/audit.log"; then
	echo "world_check_test: a failing prop audit was not a failed rule:"; grep -E "^props|WORLD CHECK" "$OUT/audit.log"; FAIL=1
else
	echo "world_check_test: a failing audit fails its rule"
fi
# A rule the game defers (the lead's word, until a time): reported deferred, not failed, before it; failed after.
WSG_DEMO_DEFER=2999-01-01T00:00Z run defer_before --only feet --bad feet
code=$?
if [ $code != 0 ] || ! grep -qE "^feet +DEFERRED" "$OUT/defer_before.log"; then
	echo "world_check_test: a deferred rule before its time was not reported deferred (exit $code)"; grep -E "^feet|deferred" "$OUT/defer_before.log"; FAIL=1
else
	echo "world_check_test: a deferred rule before its time: deferred, not failed"
fi
WSG_DEMO_DEFER=2000-01-01T00:00Z run defer_after --only feet --bad feet
code=$?
if [ $code = 0 ] || ! grep -qE "^feet +FAIL" "$OUT/defer_after.log"; then
	echo "world_check_test: a deferral past its time did not fail (exit $code)"; grep -E "^feet" "$OUT/defer_after.log"; FAIL=1
else
	echo "world_check_test: a deferral past its time: failed"
fi
# The feet rule's own later time (RULE_FROM), without the test's WSG_WORLD_ENFORCE: deferred before it, failed after.
WSG_WORLD_ENFORCE= WSG_NOW=2026-11-04T11:59Z run feet_from_before --only feet --bad feet
grep -qE "^feet +DEFERRED" "$OUT/feet_from_before.log" || { echo "world_check_test: the feet rule failed before its own time"; grep -E "^feet" "$OUT/feet_from_before.log"; FAIL=1; }
WSG_WORLD_ENFORCE= WSG_NOW=2026-11-04T12:00Z run feet_from_after --only feet --bad feet
code=$?
if [ $code = 0 ] || ! grep -qE "^feet +FAIL" "$OUT/feet_from_after.log"; then
	echo "world_check_test: the feet rule did not fail from its own time (exit $code)"; FAIL=1
else
	echo "world_check_test: the feet rule: deferred before 2026-11-04 12:00, failed from it"
fi
run manual --only feet --bad manual || { echo "world_check_test: a manual walker fails the feet rule"; tail -12 "$OUT/manual.log"; FAIL=1; }
# The Web rule: a Web preset without the licensed data excluded, and a pack that holds it, fail; excluded passes.
printf '[preset.0]\nname="Web"\nplatform="Web"\nexclude_filter=""\n' > "$OUT/bad_presets.cfg"
printf '[preset.0]\nname="Web"\nplatform="Web"\nexclude_filter="addons/wsg_foundation/data/*"\n' > "$OUT/ok_presets.cfg"
printf 'GDPC....res://addons/wsg_foundation/data/mobility.res....' > "$OUT/bad.pck"
printf 'GDPC....res://game/main.tscn....' > "$OUT/ok.pck"
run web_bad --only web --presets "$OUT/bad_presets.cfg" && { echo "world_check_test: a Web preset shipping the licensed data passed"; FAIL=1; }
run web_pck --only web --presets "$OUT/ok_presets.cfg" --web-pck "$OUT/bad.pck" && { echo "world_check_test: a Web pack holding mobility.res passed"; FAIL=1; }
run web_ok --only web --presets "$OUT/ok_presets.cfg" --web-pck "$OUT/ok.pck" || { echo "world_check_test: a clean Web preset and pack failed"; cat "$OUT/web_ok.log"; FAIL=1; }
# A rule the game does not wire fails ("not wired"), it is not skipped.
GAME=res://addons/wsg_foundation/world/world_game.gd
run unwired --only feet,sounds,joystick && { echo "world_check_test: an unwired game passed"; FAIL=1; }
grep -q "NOT WIRED" "$OUT/unwired.log" || { echo "world_check_test: unwired rules not reported as such"; FAIL=1; }
[ $FAIL = 0 ] && echo "WORLD CHECK TEST: PASS" || echo "WORLD CHECK TEST: FAIL"
exit $FAIL

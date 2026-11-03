#!/bin/sh
# wsg_world_check's own test: the foundation's demo world (tests/world_demo/world.gd) keeps every rule, and each fault
# a game could have (world.gd's BAD) fails the rule it breaks - and only that rule.
#   sh tests/world_check_test.sh
cd "$(dirname "$0")/.."
OUT="${TMPDIR:-/tmp}/wsg_world_check_test"
rm -rf "$OUT"
mkdir -p "$OUT"
RULES=feet,pose,officials,sounds,loading,joystick,web
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
for bad in loading pose officials feet sounds joystick; do
	run "$bad" --only $RULES --bad "$bad"
	code=$?
	broke=$(grep -E "^[a-z]+ +(FAIL|NOT WIRED)" "$OUT/$bad.log" | awk '{print $1}' | tr '\n' ' ')
	if [ $code = 0 ] || [ "$broke" != "$bad " ]; then
		echo "world_check_test: --bad $bad: exit $code, rules failed: '$broke' (only $bad should)"; FAIL=1
	else
		echo "world_check_test: --bad $bad caught: $(grep -E "^$bad " "$OUT/$bad.log" | cut -c21- | cut -c1-150)"
	fi
done
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

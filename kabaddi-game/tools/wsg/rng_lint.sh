#!/bin/sh
# Every random roll in gameplay goes through a seeded RandomNumberGenerator (WsgSim replays a failure from its seed;
# one bare randf and the replay is a different match - Hurling was bitten). Lists every bare randf/randi/randf_range/
# randi_range/randfn/randomize/shuffle/pick_random in the gameplay folders (a call on an object - rng.randf() - is
# fine; the Array ones, shuffle and pick_random, use the global generator, so they are not). A line can be let off
# with a comment saying why: "# wsg-rng-ok: <reason>" (cosmetic only: a crowd's twinkle).
#   sh <game>/tools/wsg/rng_lint.sh [<folder> ...]     (default: <game>/game)
HERE=$(cd "$(dirname "$0")" && pwd)
GAME=$(cd "$HERE/../.." && pwd)
[ $# -eq 0 ] && set -- "$GAME/game"
BAD=$(grep -rnE --include='*.gd' '(^|[^.a-zA-Z_])(randf|randi|randf_range|randi_range|randfn|randomize)\(|\.(shuffle|pick_random)\(' "$@" | grep -v 'wsg-rng-ok')
if [ -n "$BAD" ]; then
	echo "$BAD"
	echo "::error::rng_lint: $(printf '%s\n' "$BAD" | wc -l | tr -d ' ') unseeded random rolls in gameplay code: use the match's RandomNumberGenerator (or mark '# wsg-rng-ok: <why>')"
	exit 1
fi
echo "rng_lint: every random roll in $* goes through a seeded generator"

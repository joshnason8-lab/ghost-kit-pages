#!/bin/sh
# Is this game's copy of the shared foundation the current one? Compares its addons/wsg_foundation/ (not the licensed
# data/, not Godot's .import/.uid files) with the foundation's branch. A warning only, never a failure: a game
# updates when its own session (or the foundation's) runs tools/wsg/sync_foundation.sh and commits.
#   sh <game>/tools/wsg/check_foundation.sh      (CI: the game's workflow, after checkout)
HERE=$(cd "$(dirname "$0")" && pwd)
GAME=$(cd "$HERE/../.." && pwd)
REPO=$(git -C "$GAME" rev-parse --show-toplevel)
BRANCH=${FOUNDATION_BRANCH:-claude/shared-foundation}
if ! git -C "$REPO" fetch -q --depth=1 origin "$BRANCH" 2>/dev/null; then
	echo "check_foundation: could not fetch $BRANCH (skipped)"
	exit 0
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git -C "$REPO" archive FETCH_HEAD foundation/addons/wsg_foundation | tar -x -C "$TMP"
HAVE=$(cat "$GAME/addons/wsg_foundation/VERSION" 2>/dev/null || echo none)
LATEST=$(git -C "$REPO" rev-parse --short FETCH_HEAD)
DIFF=$(diff -rq -x data -x VERSION -x '*.import' -x '*.uid' "$TMP/foundation/addons/wsg_foundation" "$GAME/addons/wsg_foundation" 2>&1 | head -20)
if [ -n "$DIFF" ]; then
	echo "::warning::The shared foundation here ($HAVE) is behind $BRANCH ($LATEST): run tools/wsg/sync_foundation.sh"
	echo "$DIFF"
else
	echo "check_foundation: up to date with $BRANCH ($LATEST; VERSION $HAVE)"
fi
exit 0

#!/bin/sh
# Brings this game's copy of the shared foundation up to date with the foundation's branch (claude/shared-foundation,
# or FOUNDATION_BRANCH): run from the game's tools/wsg/ (vendor.sh puts it there), in the game's own checkout.
#   sh <game>/tools/wsg/sync_foundation.sh
# It replaces only what the foundation owns - addons/wsg_foundation/ (keeping the licensed data/ folder) and the
# foundation's scripts in tools/wsg/ - and never a file of the game's own (its link, its players, its tests, its
# workflow). addons/wsg_foundation/VERSION then names the foundation commit. Commit the result on the game's branch.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
GAME=$(cd "$HERE/../.." && pwd)
REPO=$(git -C "$GAME" rev-parse --show-toplevel)
BRANCH=${FOUNDATION_BRANCH:-claude/shared-foundation}
git -C "$REPO" fetch -q origin "$BRANCH"
COMMIT=$(git -C "$REPO" rev-parse --short FETCH_HEAD)
WAS=$(cat "$GAME/addons/wsg_foundation/VERSION" 2>/dev/null || echo none)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git -C "$REPO" archive FETCH_HEAD foundation | tar -x -C "$TMP"
FOUNDATION_COMMIT=$COMMIT sh "$TMP/foundation/tools/vendor.sh" "$GAME" > /dev/null
echo "sync_foundation: $GAME: foundation $WAS -> $COMMIT (from $BRANCH)"

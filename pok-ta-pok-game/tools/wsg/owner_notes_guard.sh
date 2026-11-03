#!/bin/sh
# The owner's notes are never deleted: every note id that was ever in tests/owner_notes/INDEX.json (its whole git
# history) must still be in it, with its file. A shallow checkout (CI's default) is deepened first.
#   sh <game>/tools/wsg/owner_notes_guard.sh [<notes dir, default: <game>/tests/owner_notes>]
HERE=$(cd "$(dirname "$0")" && pwd)
GAME=$(cd "$HERE/../.." && pwd)
DIR=${1:-$GAME/tests/owner_notes}
INDEX="$DIR/INDEX.json"
if [ ! -f "$INDEX" ]; then
	echo "::error::owner_notes_guard: no $INDEX"
	exit 1
fi
REPO=$(git -C "$DIR" rev-parse --show-toplevel)
REL=$(cd "$DIR" && git ls-files --full-name INDEX.json)
if [ -z "$REL" ]; then
	echo "owner_notes_guard: INDEX.json is not committed yet (nothing to compare)"
	exit 0
fi
if [ "$(git -C "$REPO" rev-parse --is-shallow-repository)" = true ]; then
	# (A shallow checkout - CI's default - cannot see INDEX.json's history: fetch it.)
	if ! git -C "$REPO" fetch -q --unshallow 2>/dev/null; then
		echo "::error::owner_notes_guard: a shallow checkout and its history could not be fetched (fetch-depth: 0)"
		exit 1
	fi
fi
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
for c in $(git -C "$REPO" log --format=%H -- "$REL"); do
	git -C "$REPO" show "$c:$REL" 2>/dev/null | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' >> "$TMP"
done
FAIL=0
for id in $(sort -u "$TMP"); do
	if ! grep -q "\"id\"[[:space:]]*:[[:space:]]*\"$id\"" "$INDEX"; then
		echo "::error::owner_notes_guard: the owner's note '$id' was in INDEX.json and is gone: notes are never deleted"
		FAIL=1
	fi
done
[ $FAIL = 0 ] && echo "owner_notes_guard: all $(sort -u "$TMP" | wc -l | tr -d ' ') notes ever listed are still there"
exit $FAIL

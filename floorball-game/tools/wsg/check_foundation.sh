#!/bin/sh
# Is this game's copy of the shared foundation good enough to build? (CI: the game's workflow, after checkout.)
#   sh <game>/tools/wsg/check_foundation.sh
# 1. FAILS (exit 1) if it lacks a commit the foundation marks required (foundation/REQUIRED on its branch): the game's
#    addons/wsg_foundation/VERSION must come from that commit or later, or its code must carry the commit's marker
#    line (a fix taken another way). A game that must ship without one sets
#    FOUNDATION_REQUIRED_SKIP="<commit>:<reason>[;<commit>:<reason>...]" - the log prints each reason.
# 2. WARNS (never fails) if it is behind the branch's latest: run tools/wsg/sync_foundation.sh.
#    A commit whose date is a UTC time (2026-11-03T12:00Z) is required from then: before it, a game without it only
#    warns (betas already in CI are not turned red mid-flight; sync it into the next one).
# FOUNDATION_REQUIRED_FILE: a manifest to use instead of the branch's (a test). FOUNDATION_NOW: the time to judge by
# (a test; default now, UTC).
HERE=$(cd "$(dirname "$0")" && pwd)
GAME=$(cd "$HERE/../.." && pwd)
REPO=$(git -C "$GAME" rev-parse --show-toplevel)
BRANCH=${FOUNDATION_BRANCH:-claude/shared-foundation}
ADDON="$GAME/addons/wsg_foundation"
HAVE=$(cat "$ADDON/VERSION" 2>/dev/null || echo none)
if ! git -C "$REPO" fetch -q origin "$BRANCH" 2>/dev/null; then
	echo "::error::check_foundation: could not fetch $BRANCH, so the required foundation commits cannot be checked"
	exit 1
fi
LATEST=$(git -C "$REPO" rev-parse --short FETCH_HEAD)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
if [ -n "$FOUNDATION_REQUIRED_FILE" ]; then
	cp "$FOUNDATION_REQUIRED_FILE" "$TMP/REQUIRED"
else
	git -C "$REPO" show FETCH_HEAD:foundation/REQUIRED > "$TMP/REQUIRED" 2>/dev/null || : > "$TMP/REQUIRED"
fi
FAIL=0
NOW=${FOUNDATION_NOW:-$(date -u +%Y-%m-%dT%H:%MZ)}
TAB=$(printf '\t')
# ("#from<TAB>" lines: required from a time, hidden from older copies of this script.)
sed "s/^#from$TAB//" "$TMP/REQUIRED" > "$TMP/REQUIRED.now"
while IFS="$TAB" read -r commit date file marker why; do
	case "$commit" in ''|'#'*) continue ;; esac
	ok=""
	if [ "$HAVE" != none ] && git -C "$REPO" merge-base --is-ancestor "$commit" "$HAVE" 2>/dev/null; then
		ok="(VERSION $HAVE has it)"
	elif [ -f "$ADDON/$file" ] && grep -qF -- "$marker" "$ADDON/$file"; then
		ok="(its code is here: $file)"
	fi
	if [ -n "$ok" ]; then
		echo "check_foundation: required $commit $ok"
		continue
	fi
	skip=$(printf '%s' "$FOUNDATION_REQUIRED_SKIP" | tr ';' '\n' | grep "^$commit:" | head -1 | cut -d: -f2-)
	if [ -n "$skip" ]; then
		echo "::warning::check_foundation: shipping WITHOUT required foundation $commit ($why). Reason given: $skip"
		continue
	fi
	case "$date" in
	*T*)
		if [ "$(expr "$NOW" \< "$date")" = 1 ]; then
			echo "::warning::check_foundation: this game's foundation ($HAVE) lacks $commit, REQUIRED FROM $date (now $NOW): $why Sync it into your next build (tools/wsg/sync_foundation.sh)."
			continue
		fi
		;;
	esac
	echo "::error::check_foundation: this game's foundation ($HAVE) lacks required $commit ($date): $why Run tools/wsg/sync_foundation.sh and commit."
	FAIL=1
done < "$TMP/REQUIRED.now"
git -C "$REPO" archive FETCH_HEAD foundation/addons/wsg_foundation | tar -x -C "$TMP"
DIFF=$(diff -rq -x data -x VERSION -x '*.import' -x '*.uid' "$TMP/foundation/addons/wsg_foundation" "$ADDON" 2>&1 | head -20)
if [ -n "$DIFF" ]; then
	echo "::warning::The shared foundation here ($HAVE) is behind $BRANCH ($LATEST): run tools/wsg/sync_foundation.sh"
	echo "$DIFF"
else
	echo "check_foundation: up to date with $BRANCH ($LATEST; VERSION $HAVE)"
fi
exit $FAIL

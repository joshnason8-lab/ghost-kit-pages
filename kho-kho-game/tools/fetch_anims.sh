#!/bin/sh
# Puts the game's baked animation clips (assets/models/anims/*.res: Mixamo-derived, so not in this public repository,
# the owner's decision of 2 November 2026) into place for this build, from the PRIVATE repository
# joshnason8-lab/world-stage-games-assets, folder kho-kho/mixamo-anims/. They go no further than the APK/AAB.
#   tools/fetch_anims.sh
# Credentials: $ASSETS_REPO_TOKEN (CI: read access to that repository), else the gh CLI's own login (a developer's
# computer). With neither, it says so and exits 0: the game still builds and runs, its players standing in their
# model's rest pose where a clip would play (ModelBody skips clips that are not there). With the token given but the
# clips out of reach, it fails: a beta without them would go out with its players frozen.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
DEST="$HERE/../assets/models/anims"
REPO=joshnason8-lab/world-stage-games-assets
DIR=kho-kho/mixamo-anims
mkdir -p "$DEST"
if [ -n "$ASSETS_REPO_TOKEN" ]; then
	URL="https://x-access-token:${ASSETS_REPO_TOKEN}@github.com/${REPO}.git"
elif gh auth status >/dev/null 2>&1; then
	URL="https://github.com/${REPO}.git"
	git config --global credential.helper '!gh auth git-credential' >/dev/null 2>&1 || true
else
	echo "fetch_anims: no ASSETS_REPO_TOKEN and no gh login: building without the animation clips"
	exit 0
fi
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
if ! git clone -q --depth 1 --filter=blob:none --sparse "$URL" "$WORK/repo" 2>/dev/null; then
	echo "fetch_anims: cannot read $REPO (token expired, or no access to it)"
	[ -n "$ASSETS_REPO_TOKEN" ] && exit 1
	exit 0
fi
git -C "$WORK/repo" sparse-checkout set "$DIR" >/dev/null 2>&1
n=$(ls "$WORK/repo/$DIR"/*.res 2>/dev/null | wc -l)
if [ "$n" -eq 0 ]; then
	echo "fetch_anims: no clips in $REPO/$DIR"
	[ -n "$ASSETS_REPO_TOKEN" ] && exit 1
	exit 0
fi
cp "$WORK/repo/$DIR"/*.res "$DEST/"
echo "fetch_anims: $n clips into assets/models/anims"

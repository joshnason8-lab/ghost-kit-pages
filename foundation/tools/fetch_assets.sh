#!/bin/sh
# Puts the licensed animation data into addons/wsg_foundation/data/ for this build, from the PRIVATE repository
# joshnason8-lab/world-stage-games-assets (release "mocap-source"). The data is baked here, in this build, and goes
# no further than the APK/AAB: it is never committed, cached or uploaded.
#   tools/fetch_assets.sh [addon dir]     (default: this foundation's addons/wsg_foundation)
# Credentials, in order: $ASSETS_REPO_TOKEN (CI: a fine-grained, read-only token for that one repository), else the
# gh CLI's own login (a developer's computer). With neither, it says so and exits 0: the game builds and runs on its
# own animation (forks, pull requests from forks, computers without access).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ADDON=${1:-$HERE/../addons/wsg_foundation}
DATA="$ADDON/data"
REPO=joshnason8-lab/world-stage-games-assets
TAG=mocap-source
ZIP=FBX_Mobility_27B_Pro.zip

if [ -z "$ASSETS_REPO_TOKEN" ] && ! gh auth status >/dev/null 2>&1; then
	echo "fetch_assets: no ASSETS_REPO_TOKEN and no gh login: building without the licensed animation (the game's own is used)"
	exit 0
fi
if [ -f "$DATA/mobility.res" ] && [ -z "$FORCE" ]; then
	echo "fetch_assets: $DATA already has the library (FORCE=1 to rebuild)"
	exit 0
fi
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
echo "fetch_assets: finding $ZIP on $REPO@$TAG"
if [ -n "$ASSETS_REPO_TOKEN" ]; then
	curl -fsSL -H "Authorization: Bearer $ASSETS_REPO_TOKEN" "https://api.github.com/repos/$REPO/releases/tags/$TAG" > "$WORK/release.json" || {
		echo "fetch_assets: the token cannot read $REPO (expired, or not given Contents: read on it): building without the licensed animation"
		exit 0
	}
	ID=$(python3 -c "import json,sys; print([a['id'] for a in json.load(open(sys.argv[1]))['assets'] if a['name']==sys.argv[2]][0])" "$WORK/release.json" "$ZIP")
	curl -fsSL -H "Authorization: Bearer $ASSETS_REPO_TOKEN" -H "Accept: application/octet-stream" -o "$WORK/$ZIP" "https://api.github.com/repos/$REPO/releases/assets/$ID"
else
	gh release download "$TAG" -R "$REPO" -p "$ZIP" -D "$WORK"
fi
echo "fetch_assets: unpacking"
mkdir -p "$WORK/mob"
unzip -q "$WORK/$ZIP" -d "$WORK/mob"
rm "$WORK/$ZIP"
SRC=$(dirname "$(find "$WORK/mob" -type d -name Animation | head -1)")
mkdir -p "$DATA"
"$HERE/bake_clips.sh" "$SRC" "$DATA"
echo "fetch_assets: done: $(ls "$DATA")"

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
if [ -d "$HERE/../addons/wsg_foundation" ]; then DEF="$HERE/../addons/wsg_foundation"; else DEF="$HERE/../../addons/wsg_foundation"; fi
ADDON=${1:-$DEF}
DATA="$ADDON/data"
REPO=joshnason8-lab/world-stage-games-assets
TAG=mocap-source
ZIP=FBX_Mobility_27B_Pro.zip
ACZIP=Actorcore.moves.zip

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
get() {   # get <asset name>: into $WORK; returns 1 if the release has no such asset
	if [ -n "$ASSETS_REPO_TOKEN" ]; then
		ID=$(python3 -c "import json,sys; a=[a['id'] for a in json.load(open(sys.argv[1]))['assets'] if a['name']==sys.argv[2]]; print(a[0] if a else '')" "$WORK/release.json" "$1")
		[ -n "$ID" ] || return 1
		curl -fsSL -H "Authorization: Bearer $ASSETS_REPO_TOKEN" -H "Accept: application/octet-stream" -o "$WORK/$1" "https://api.github.com/repos/$REPO/releases/assets/$ID"
	else
		gh release download "$TAG" -R "$REPO" -p "$1" -D "$WORK" || return 1
	fi
}
if [ -n "$ASSETS_REPO_TOKEN" ]; then
	curl -fsSL -H "Authorization: Bearer $ASSETS_REPO_TOKEN" "https://api.github.com/repos/$REPO/releases/tags/$TAG" > "$WORK/release.json" || {
		echo "fetch_assets: the token cannot read $REPO (expired, or not given Contents: read on it): building without the licensed animation"
		exit 0
	}
fi
get "$ZIP" || { echo "fetch_assets: no $ZIP on the release: building without it"; exit 0; }
echo "fetch_assets: unpacking"
mkdir -p "$WORK/mob" "$WORK/ac"
unzip -q "$WORK/$ZIP" -d "$WORK/mob"
rm "$WORK/$ZIP"
SRC=$(dirname "$(find "$WORK/mob" -type d -name Animation | head -1)")
AC=""
if get "$ACZIP"; then
	unzip -q "$WORK/$ACZIP" -d "$WORK/ac"
	rm "$WORK/$ACZIP"
	# The moves come as one zip of zips (one per motion).
	find "$WORK/ac" -name "*.zip" ! -path "*__MACOSX*" | while read -r z; do unzip -q -o "$z" -d "${z%.zip}"; done
	AC="$WORK/ac"
	# The takes' names only (docs/CATALOGUE.md: the game sessions choose from them; no animation leaves the build).
	echo "fetch_assets: ActorCore takes in the zip (names only): $(find "$WORK/ac" -iname "*.fbx" ! -path "*__MACOSX*" | wc -l)"
	find "$WORK/ac" -iname "*.fbx" ! -path "*__MACOSX*" -exec basename {} .fbx \; | sort -u | tr '\n' ' '
	echo
fi
mkdir -p "$DATA"
"$HERE/bake_clips.sh" "$SRC" "$DATA" "$AC"
# The crowd from the ActorCore crowd motions (the fans: crowd_src beside these tools).
if [ -n "$AC" ] && [ -d "$HERE/crowd_src" ]; then
	PROJ=$(cd "$ADDON/../.." && pwd)
	mkdir -p "$DATA/crowd"
	FANS=$(ls "$HERE/crowd_src" | sed -n 's/_rig\.json$//p' | tr '\n' ' ')
	godot --headless --path "$PROJ" --import >/dev/null 2>&1 || true
	godot --headless --path "$PROJ" -s "res://$(realpath --relative-to="$PROJ" "$HERE")/bake_crowd.gd" -- "$DATA/crowd" 450 "$HERE/crowd_src" "$HERE/crowd_src" $FANS
fi
echo "fetch_assets: done: $(ls "$DATA")"

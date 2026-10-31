#!/bin/sh
# Copies the foundation addon into a game (one command to adopt or to update):
#   foundation/tools/vendor.sh <game dir, e.g. hurling-game>
# Puts addons/wsg_foundation/ (code, shaders, the authored crowd) and tools/wsg/ (the bake and fetch scripts, and the Blender ones) in the
# game, adds the licensed data folder to the game's .gitignore, and records which foundation commit it came from.
# The licensed data itself comes at build time (tools/wsg/fetch_assets.sh, in CI with ASSETS_REPO_TOKEN).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
F=$(cd "$HERE/.." && pwd)
GAME=$(cd "$1" && pwd)
mkdir -p "$GAME/addons" "$GAME/tools/wsg"
rm -rf "$GAME/addons/wsg_foundation.new"
cp -r "$F/addons/wsg_foundation" "$GAME/addons/wsg_foundation.new"
rm -rf "$GAME/addons/wsg_foundation.new/data"
if [ -d "$GAME/addons/wsg_foundation/data" ]; then
	mv "$GAME/addons/wsg_foundation/data" "$GAME/addons/wsg_foundation.new/data"
fi
rm -rf "$GAME/addons/wsg_foundation"
mv "$GAME/addons/wsg_foundation.new" "$GAME/addons/wsg_foundation"
for f in sync_foundation.sh check_foundation.sh fetch_assets.sh bake_clips.sh bake_clips.gd bake_actorcore.gd bake_crowd.gd crowd_mocap.gd bake_character.sh bake_character.gd toonbody_to_scene.gd cloth_drape.gd cloth_weights.gd; do
	cp "$HERE/$f" "$GAME/tools/wsg/"
done
rm -rf "$GAME/tools/wsg/blender"
mkdir -p "$GAME/tools/wsg/blender"
cp "$HERE"/blender/*.py "$HERE"/blender/*.sh "$HERE"/blender/*.gd "$HERE"/blender/README.md "$GAME/tools/wsg/blender/"
rm -rf "$GAME/tools/wsg/crowd_src"
cp -r "$HERE/crowd_src" "$GAME/tools/wsg/crowd_src"
# (Their .import files name the foundation's path and its hash; the game has them under tools/wsg/, as Godot would rewrite them.)
for f in "$GAME"/tools/wsg/crowd_src/*.import; do
	[ -f "$f" ] || continue
	src=$(basename "$f" .import)
	old=$(printf 'res://tools/crowd_src/%s' "$src" | md5sum | cut -c1-32)
	new=$(printf 'res://tools/wsg/crowd_src/%s' "$src" | md5sum | cut -c1-32)
	sed -i -e "s#res://tools/crowd_src/#res://tools/wsg/crowd_src/#" -e "s#$old#$new#g" "$f"
done
grep -q "addons/wsg_foundation/data" "$GAME/.gitignore" 2>/dev/null || {
	printf '\n# Licensed animation data, baked at build time (tools/wsg/fetch_assets.sh): never committed.\naddons/wsg_foundation/data/\n' >> "$GAME/.gitignore"
}
if [ -n "$FOUNDATION_COMMIT" ]; then
	echo "$FOUNDATION_COMMIT" > "$GAME/addons/wsg_foundation/VERSION"
else
	(cd "$F" && git rev-parse --short HEAD 2>/dev/null) > "$GAME/addons/wsg_foundation/VERSION" || true
fi
echo "vendored the foundation into $GAME ($(cat "$GAME/addons/wsg_foundation/VERSION"))"

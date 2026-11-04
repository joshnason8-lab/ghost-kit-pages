#!/bin/sh
# Rebuilds assets/player/ (the players' model for the game) from the owner's model:
#   tools/player/build.sh [path/to/player.glb]
# Without a path it uses src/player.glb, downloading it from the owner's Google Drive link first if it is not there
# (34 MB: too big for the repository, so it is not committed). The sprint (clips/fast_run.json) is committed: no
# Mixamo files are needed. Needs godot (4.7) on the PATH, python3 with Pillow and numpy, and curl.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
GAME=$(cd "$HERE/../.." && pwd)
GLB=${1:-$HERE/src/player.glb}
if [ ! -f "$GLB" ]; then
	echo "downloading the model to $GLB"
	curl -sSL -o "$GLB" "https://drive.usercontent.google.com/download?id=1oanBoio6KVpuOcwgiglwNZZiayZHfRsQ&export=download&confirm=t"
fi
WORK=$(mktemp -d)
mkdir -p "$WORK/src" "$WORK/clips"
printf 'config_version=5\n[application]\nconfig/name="bake"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n' > "$WORK/project.godot"
cp "$HERE/mixamo_map.tres" "$HERE/bake.gd" "$WORK/"
cp "$HERE"/clips/*.json "$WORK/clips/"
cp "$HERE/src/player.glb.import" "$WORK/src/"
cp "$GLB" "$WORK/src/player.glb"
# Godot imports the model with the humanoid retarget (src/player.glb.import), and its texture comes out as
# src/player_texture_0.png.
godot --headless --path "$WORK" --import >/dev/null 2>&1 || true
godot --headless --path "$WORK" -s bake.gd -- "$GAME/assets/player"
python3 "$HERE/make_textures.py" "$WORK/src/player_texture_0.png" "$GAME/assets/player"
rm -rf "$WORK"

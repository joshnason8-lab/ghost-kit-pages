#!/bin/sh
# Bakes a rigged character onto the World Stage Games rig (bake_character.gd says what it does).
#   tools/bake_character.sh <model.glb|.fbx> <out dir> <prefix> [tris_hi] [tris_lo]
# Needs godot 4.7 on the PATH. Works in a scratch project; writes <out>/<prefix>_hi.res, _lo.res, _rig.json.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ADDON=$(cd "$HERE/../addons/wsg_foundation" && pwd)
MODEL=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
OUT=$(mkdir -p "$2" && cd "$2" && pwd)
WORK=$(mktemp -d)
mkdir -p "$WORK/src" "$WORK/addons"
printf 'config_version=5\n[application]\nconfig/name="bake"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n' > "$WORK/project.godot"
cp -r "$ADDON" "$WORK/addons/wsg_foundation"
rm -rf "$WORK/addons/wsg_foundation/data"
cp "$HERE/bake_character.gd" "$WORK/"
EXT="${MODEL##*.}"
cp "$MODEL" "$WORK/src/model.$EXT"
godot --headless --path "$WORK" --import >/dev/null 2>&1 || true
godot --headless --path "$WORK" -s bake_character.gd -- "res://src/model.$EXT" "$OUT" "$3" ${4:-6000} ${5:-2000}
rm -rf "$WORK"

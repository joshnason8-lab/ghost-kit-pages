#!/bin/sh
# A character's light mesh, clean (Blender's decimation: symmetric, hands and head kept denser, the surface kept),
# for any game:   tools/blender/make_lod.sh <godot project> <hi.res> <out lo.res> <triangles> [old lo.res]
# The detailed mesh is a foundation character's (tools/bake_character.sh: the rig's T, skinned); the light one is
# skinned from its surface. With an old light mesh, both are measured against the detailed surface.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
PROJ=$(cd "$1" && pwd)
WORK=$(mktemp -d)
mkdir -p "$PROJ/.wsg_blender"
cp "$HERE/export_obj.gd" "$HERE/lod_from_obj.gd" "$PROJ/.wsg_blender/"
godot --headless --path "$PROJ" -s res://.wsg_blender/export_obj.gd -- "$2" "$WORK/hi.obj" | grep export_obj
CMP=""
if [ -n "$5" ]; then
	godot --headless --path "$PROJ" -s res://.wsg_blender/export_obj.gd -- "$5" "$WORK/old.obj" | grep export_obj
	CMP="--compare $WORK/old.obj"
fi
blender -b --python "$HERE/decimate_lod.py" -- --in "$WORK/hi.obj" --out "$WORK/lo.obj" --tris "$4" $CMP | grep decimate_lod
godot --headless --path "$PROJ" -s res://.wsg_blender/lod_from_obj.gd -- "$2" "$WORK/lo.obj" "$(realpath -m "$3")" | grep lod_from_obj
rm -rf "$PROJ/.wsg_blender" "$WORK"

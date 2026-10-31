#!/bin/sh
# A tangent-space normal map from a detailed mesh onto a light one, for any game:
#   tools/blender/bake_normals.sh <godot project> <hi.res> <lo.res> <out.png> [size 2048] [cage 0.01] [ray 0.03]
# The meshes are Godot resources in the same pose (a character's: both from tools/bake_character.sh, the light one a
# cut of the detailed one - a different model's surface does not match and the map is noise). Needs godot 4.7 and
# blender 4.x (headless; on Ubuntu `apt-get install blender`) on the PATH. Writes the PNG (OpenGL convention, green
# up: Godot's); give the light mesh tangents (SurfaceTool.generate_tangents) and the material the map.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
PROJ=$(cd "$1" && pwd)
WORK=$(mktemp -d)
mkdir -p "$PROJ/.wsg_blender"
cp "$HERE/export_obj.gd" "$PROJ/.wsg_blender/"
godot --headless --path "$PROJ" -s res://.wsg_blender/export_obj.gd -- "$2" "$WORK/hi.obj"
godot --headless --path "$PROJ" -s res://.wsg_blender/export_obj.gd -- "$3" "$WORK/lo.obj"
rm -rf "$PROJ/.wsg_blender"
blender -b --python "$HERE/bake_normals.py" -- --high "$WORK/hi.obj" --low "$WORK/lo.obj" --out "$(realpath -m "$4")" \
	--size "${5:-2048}" --cage "${6:-0.01}" --ray "${7:-0.03}" | grep bake_normals
rm -rf "$WORK"

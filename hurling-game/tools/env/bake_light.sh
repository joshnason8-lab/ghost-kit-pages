#!/bin/sh
# The venues' baked light (Low and Medium, GL Compatibility): each stadium exported by bake_light.tscn, baked in
# Blender's Cycles (the shared foundation's tools/wsg/blender/bake_light.py), the maps into assets/env/light.
#   tools/env/bake_light.sh [samples]
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
PROJ=$(cd "$HERE/../.." && pwd)
OUT=$(mktemp -d)
godot --headless --path "$PROJ" res://tools/env/bake_light.tscn -- "$OUT"
for j in "$OUT"/*.json; do
	b=${j%.json}
	blender -b --python "$PROJ/tools/wsg/blender/bake_light.py" -- --base "$b" --samples "${1:-64}"
	n=$(basename "$b")
	cp "$b.json" "$b"_light.png "$b"_ground.png "$PROJ/assets/env/light/"
done
rm -rf "$OUT"

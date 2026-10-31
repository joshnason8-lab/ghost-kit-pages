#!/bin/sh
# Puts every body in assets/characters/bodies/bodies.json (the owner's Meshy players and referees) on the shared
# foundation's rig: krb_to_scene.gd turns each packed body into a rigged scene facing +Z (kit regions in UV2), and
# tools/wsg/bake_character.sh bakes it into assets/foundation/<name>_hi.res, _lo.res, _rig.json (the owner's meshes,
# no animation). Run from the game's folder: sh tools/rig/bake_foundation.sh [name ...]
set -e
GAME=$(cd "$(dirname "$0")/../.." && pwd)
WORK=$(mktemp -d)
NAMES="$*"
if [ -z "$NAMES" ]; then
	NAMES=$(python3 -c "import json;print(' '.join(e['file'].rsplit('.',1)[0] for e in json.load(open('$GAME/assets/characters/bodies/bodies.json'))))")
fi
for n in $NAMES; do
	godot --headless --path "$GAME" -s tools/rig/krb_to_scene.gd -- "res://assets/characters/bodies/$n.krb" "$WORK/$n.scn" 2>&1 | grep -v "leaked\|at: " || true
	sh "$GAME/tools/wsg/bake_character.sh" "$WORK/$n.scn" "$GAME/assets/foundation" "$n" 6000 2000 2>&1 | grep -v "leaked\|at: \|^{" || true
done
rm -rf "$WORK"

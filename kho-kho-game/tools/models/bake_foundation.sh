#!/bin/sh
# The owner's athlete baked onto the World Stage Games shared rig (Medium and High: game/foundation_link.gd):
#   tools/models/bake_foundation.sh            (from kho-kho-game/; needs godot 4.7 on the PATH)
# From the committed model (assets/models/player.glb: the owner's source is not in the repository): its full mesh
# (player_lod0, 3,600 triangles) as the near bodies' mesh and cut to 1,400 for the far ones, the same UVs (the 2048 px
# texture, the kit recoloured by ModelBody's shader). Writes assets/foundation/player_hi.res, player_lo.res,
# player_rig.json - the owner's mesh only, no animation.
set -e
cd "$(dirname "$0")/../.."
WORK=$(mktemp -d)
godot --headless --path . -s tools/models/player_for_rig.gd -- "$WORK/player.scn"
sh tools/wsg/bake_character.sh "$WORK/player.scn" assets/foundation player 3600 1400
rm -rf "$WORK"

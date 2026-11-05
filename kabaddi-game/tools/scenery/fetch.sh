#!/usr/bin/env bash
# Fetches the models the grounds' scenery is made from, out of the lead session's shared assets (branch
# claude/shared-assets, folder shared-assets/), into assets/scenery/src/. They are not committed: what the game loads
# is made from them by tools/scenery/convert.tscn (each model's mesh and textures), and that is. Only what the game
# draws: not the trees' cut-down models (Low draws every tree as a cut-out) nor the Jagannath tower's full one (it stands
# 850 m off, cut down on every level). The skies, surfaces and the water's normal map come from the same place and are
# used as they are (assets/scenery/skies, surfaces, water).
#   tools/scenery/fetch.sh && godot --headless --path . res://tools/scenery/convert.tscn
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
proj=$(cd "$here/../.." && pwd)
models=(
	trees/rain_tree trees/rain_tree_card
	trees/coconut_palm trees/coconut_palm_card
	trees/island_tree_a_card trees/island_tree_b_card
	foliage/dry_grass_tall_card
	seating/monobloc_chair seating/monobloc_chair_low seating/folding_stool seating/folding_stool_low
	props/scorers_table props/scorers_table_low
	buildings/city_apartments buildings/city_apartments_low
	buildings/indian_village_temple buildings/indian_village_temple_low
	buildings/jagannath_tower_low
)
git -C "$proj" fetch origin claude/shared-assets
for m in "${models[@]}"; do
	mkdir -p "$proj/assets/scenery/src/$(dirname "$m")"
	git -C "$proj" show "origin/claude/shared-assets:shared-assets/$m.glb" > "$proj/assets/scenery/src/$m.glb"
done
echo "fetch.sh: ${#models[@]} models in assets/scenery/src"

#!/usr/bin/env bash
# Bakes the grounds' lighting into assets/grounds/<id>/ (Godot's LightmapGI): the court, floor, stands, roofs and
# trees get their light from the sky, the sun's bounce, and the floodlights and roof lamps, with soft shadows and the
# darkening in corners, at no cost on the phone. The players stay lit live.
#
# Godot's lightmapper runs only from the editor, on a Vulkan device. Without a GPU, Mesa's software one works:
#   apt-get install mesa-vulkan-drivers xvfb
# So this works on a copy of the project: builds the scenes (make_scenes.tscn), turns on addon/ there, runs the
# editor (under xvfb) to bake them, and copies each ground's scene, bake and lightmap back.
#   tools/bake_lighting/bake.sh [dome stadium village monsoon beach]     (BAKE_QUALITY=low|medium|high, high by default)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
proj=$(cd "$here/../.." && pwd)
grounds=("$@")
[ ${#grounds[@]} -eq 0 ] && grounds=(dome stadium village monsoon beach)
godot=${GODOT:-godot}
work=$(mktemp -d "${TMPDIR:-/tmp}/bake_lighting.XXXXXX")
trap 'rm -rf "$work"' EXIT
tar -C "$proj" --exclude=./assets/meshy --exclude=./build -cf - . | tar -C "$work" -xf -
"$godot" --headless --path "$work" --import > /dev/null 2>&1 || true   # the surfaces' textures, before they are used
"$godot" --headless --path "$work" res://tools/bake_lighting/make_scenes.tscn -- "${grounds[@]}" "quality=${BAKE_QUALITY:-high}"
mkdir -p "$work/addons"
cp -r "$here/addon" "$work/addons/bake_lighting"
printf '\n[editor_plugins]\n\nenabled=PackedStringArray("res://addons/bake_lighting/plugin.cfg")\n' >> "$work/project.godot"
: > "$work/bake_list.txt"
for g in "${grounds[@]}"; do echo "res://assets/grounds/$g/$g.tscn" >> "$work/bake_list.txt"; done
icd=${VK_ICD_FILENAMES:-}
[ -z "$icd" ] && [ -f /usr/share/vulkan/icd.d/lvp_icd.json ] && ! command -v nvidia-smi >/dev/null && icd=/usr/share/vulkan/icd.d/lvp_icd.json
VK_ICD_FILENAMES=$icd xvfb-run -a -s "-screen 0 1600x900x24" "$godot" --path "$work" -e \
	--rendering-driver vulkan --rendering-method forward_plus 2>&1 | grep --line-buffered -v "^ALSA\|ALSA lib" \
	| grep --line-buffered -i "bake\|error" || true
for g in "${grounds[@]}"; do
	if [ ! -f "$work/assets/grounds/$g/$g.lmbake" ]; then
		echo "bake.sh: $g was not baked" >&2
		exit 1
	fi
	mkdir -p "$proj/assets/grounds/$g"
	rm -f "$proj/assets/grounds/$g/$g"*.exr "$proj/assets/grounds/$g/$g"*.exr.import
	cp "$work/assets/grounds/$g/"* "$proj/assets/grounds/$g/"
	ls -la "$proj/assets/grounds/$g"
done

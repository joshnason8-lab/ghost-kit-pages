#!/bin/sh
# Bakes the licensed motion capture into the clip library the addon loads (LICENSED OUTPUT: never commit it).
#   tools/bake_clips.sh <unzipped FBX_Mobility_27B_Pro dir> <out dir, e.g. addons/wsg_foundation/data>
# Needs godot 4.7 on the PATH. Works in a scratch project, which it deletes.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ADDON=$(cd "$HERE/../addons/wsg_foundation" && pwd)
SRC=$(cd "$1" && pwd)
OUT=$(mkdir -p "$2" && cd "$2" && pwd)
WORK=$(mktemp -d)
mkdir -p "$WORK/src/ipc" "$WORK/src/rm" "$WORK/src/aim" "$WORK/src/ref" "$WORK/addons"
printf 'config_version=5\n[application]\nconfig/name="clips"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n' > "$WORK/project.godot"
cp -r "$ADDON" "$WORK/addons/wsg_foundation"
rm -rf "$WORK/addons/wsg_foundation/data"
cp "$HERE/bake_clips.gd" "$WORK/"
cp "$SRC"/Animation/IPC/*.fbx "$WORK/src/ipc/"
cp "$SRC"/Animation/Root_Motion/*.fbx "$WORK/src/rm/"
cp "$SRC"/Animation/Aim_Offsets/*.fbx "$WORK/src/aim/"
cp "$SRC"/MotusMan_v55/MotusMan_v55.fbx "$WORK/src/ref/"
echo "importing $(ls "$WORK"/src/*/ | wc -l) clips (a few minutes)"
godot --headless --path "$WORK" --import >/dev/null 2>&1 || true
godot --headless --path "$WORK" --import >/dev/null 2>&1 || true
godot --headless --path "$WORK" -s bake_clips.gd -- "$OUT"
rm -rf "$WORK"

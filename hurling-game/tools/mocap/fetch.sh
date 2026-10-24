#!/bin/sh
# The CMU motion-capture clips the game uses (tools/mocap/bvh_clip.py CLIPS), from the GitHub mirror of the BVH
# conversion (mocap.cs.cmu.edu's own certificate chain is incomplete), into a scratch directory; then the game's
# clips rebuilt from them into assets/player/cmu.json. The BVH files are not kept in the repository.
#   tools/mocap/fetch.sh <scratch dir>
set -e
out="$1"
mkdir -p "$out"
for id in 35_01 35_17; do
  s=$(printf "%03d" "${id%%_*}")
  curl -sSf -o "$out/$id.bvh" "https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/data/$s/$id.bvh"
done
python3 "$(dirname "$0")/bvh_clip.py" --all "$out"

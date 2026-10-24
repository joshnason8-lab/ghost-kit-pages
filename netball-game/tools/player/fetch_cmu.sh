#!/bin/sh
# Rebuilds assets/player/mocap.json (the players' motion-capture moves) from the CMU library:
#   tools/player/fetch_cmu.sh [scratch_dir]
# Downloads the CMU clips the game uses (BVH, Bruce Hahne's conversion, from the una-dinosauria/cmu-mocap mirror on
# GitHub: mocap.cs.cmu.edu's own certificate chain is incomplete) into scratch_dir (not the repository: megabytes),
# then runs cmu_bvh.py. Needs curl, python3 and numpy.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$(mktemp -d)}
mkdir -p "$OUT"
for c in 102_27 16_08; do
	s=${c%_*}
	n=$(echo "$s" | sed 's/^0*//')
	S=$(printf %03d "$n")
	[ -s "$OUT/$c.bvh" ] || curl -sSfL -o "$OUT/$c.bvh" "https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/data/$S/$c.bvh"
done
python3 -I "$HERE/cmu_bvh.py" "$OUT"

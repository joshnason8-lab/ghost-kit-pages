#!/usr/bin/env bash
# Builds the HD pack (Ultra graphics content, game/ultra.gd) and its manifest:
#   build/hurling-heroes-hd-<PACK>.pck and build/hurling-heroes-hd-<PACK>.json ({pack, size, sha256, source}).
# "source" is a hash of everything the pack is made from (the files under ultra/, their import settings, the Godot
# version), so the workflow uploads a new pack only when it has changed. Run from hurling-game/, after an import.
#   tools/ultra/build_pack.sh            the pack and manifest
#   tools/ultra/build_pack.sh --source   only print the source hash
set -euo pipefail
PACK=$(sed -n 's/^const PACK := \([0-9]*\).*/\1/p' game/ultra.gd)
python3 tools/ultra/fetch.py > /dev/null
SOURCE=$( (godot --version --headless 2>/dev/null | head -1; echo "pack $PACK"; \
  find ultra -type f ! -name '*.uid' | LC_ALL=C sort | xargs sha256sum) | sha256sum | cut -c1-64)
if [ "${1:-}" = "--source" ]; then echo "$SOURCE"; exit 0; fi
python3 tools/ultra/pack_preset.py
mkdir -p build
OUT=build/hurling-heroes-hd-$PACK.pck
godot --headless --path . --export-pack "Android HD pack" "$OUT"
SIZE=$(stat -c %s "$OUT")
SHA=$(sha256sum "$OUT" | cut -c1-64)
printf '{"pack": %s, "size": %s, "sha256": "%s", "source": "%s"}\n' "$PACK" "$SIZE" "$SHA" "$SOURCE" > build/hurling-heroes-hd-$PACK.json
cat build/hurling-heroes-hd-$PACK.json

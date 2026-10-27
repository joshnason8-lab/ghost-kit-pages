#!/bin/sh
# Builds the pages from the game branches, then zips the theme to dist/world-stage-games-website.zip (ready for
# Appearance > Themes > Add New > Upload). Run from the repository root: sh studio-website/tools/package.sh
set -e
cd "$(dirname "$0")/.."
python3 tools/build_content.py
mkdir -p dist
rm -f dist/world-stage-games-website.zip dist/ghost-kit-theme.zip
(cd theme && zip -qr -X ../dist/world-stage-games-website.zip world-stage-games -x '*.DS_Store')
ls -l dist/world-stage-games-website.zip

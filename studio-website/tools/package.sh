#!/bin/sh
# Builds the pages from the game branches, then zips the theme to dist/ghost-kit-theme.zip (ready for Appearance >
# Themes > Add New > Upload). Run from the repository root: sh studio-website/tools/package.sh
set -e
cd "$(dirname "$0")/.."
python3 tools/build_content.py
mkdir -p dist
rm -f dist/ghost-kit-theme.zip
(cd theme && zip -qr -X ../dist/ghost-kit-theme.zip ghost-kit -x '*.DS_Store')
ls -l dist/ghost-kit-theme.zip

#!/usr/bin/env bash
# Renders the itch.io screenshots (assets/screenshots/, the screen at 2x) from the frame dump's scenes.
# The cover is separate: tools/make_cover.py from scene 2.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p assets/screenshots
shots=(01-new-farm 02-farm 03-rats)
for n in 1 2 3; do
	odin test src/game -collection:tggd=src -define:DUMP_SCENE=$n -define:DUMP_PLAY="$tmp/$n.ppm" >/dev/null 2>&1
	python3 -I -c 'import sys; from PIL import Image; im = Image.open(sys.argv[1]); im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(sys.argv[2])' "$tmp/$n.ppm" "assets/screenshots/${shots[$((n - 1))]}.png"
	echo "assets/screenshots/${shots[$((n - 1))]}.png"
done

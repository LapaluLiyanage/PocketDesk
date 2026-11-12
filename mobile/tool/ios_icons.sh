#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Renders every size in ios/Runner/Assets.xcassets/AppIcon.appiconset from one
# SVG (default: ../packaging/icons/pocketdesk-ios.svg). Runs on macOS (the CI
# runner): needs `sips` (built in) and `rsvg-convert` (brew install librsvg).
# The file names already in the folder say which sizes are needed.
set -euo pipefail
cd "$(dirname "$0")/.."
svg="${1:-../packaging/icons/pocketdesk-ios.svg}"
set_dir=ios/Runner/Assets.xcassets/AppIcon.appiconset
master="$(mktemp -d)/master.png"

# One 1024px opaque master; every other size is scaled from it.
rsvg-convert -w 1024 -h 1024 -b '#ffffff' "$svg" -o "$master"

for f in "$set_dir"/Icon-App-*.png; do
  base=$(basename "$f" .png)            # Icon-App-83.5x83.5@2x
  size=${base#Icon-App-}                # 83.5x83.5@2x
  pt=${size%%x*}                        # 83.5
  scale=${size##*@}; scale=${scale%x}   # 2
  px=$(awk -v p="$pt" -v s="$scale" 'BEGIN { printf "%d", p * s + 0.5 }')
  sips -z "$px" "$px" "$master" --out "$f" >/dev/null
  echo "$base -> ${px}px"
done

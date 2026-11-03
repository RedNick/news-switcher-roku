#!/usr/bin/env bash
# Writes the app's version (for example "v1.0.7") in the bottom-right corner
# of the home screen icons, so you can tell at a glance which build is
# installed.
#
# It reads the version from the manifest in the project root and changes the
# icons in the folder you give it, so point it at a copy of images/, never
# at the originals. Needs ImageMagick (the `convert` command).
#
# Usage: tools/stamp-version-on-icons.sh <folder holding the icon PNGs>
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
icons_folder="$1"

read_manifest_value() {
  grep "^$1=" "$project_root/manifest" | cut -d= -f2
}
app_version="v$(read_manifest_value major_version).$(read_manifest_value minor_version).$(read_manifest_value build_version)"

# Icon file, text size and gap from the edges, scaled to each icon's size.
stamp_icon() {
  local icon_file="$icons_folder/$1"
  local text_size="$2"
  local edge_gap="$3"
  convert "$icon_file" \
    -gravity southeast \
    -font DejaVu-Sans-Bold -pointsize "$text_size" \
    -fill '#FFD24A' -annotate "+${edge_gap}+${edge_gap}" "$app_version" \
    -depth 8 "PNG24:$icon_file"
}

stamp_icon icon_focus_hd.png 18 10
stamp_icon icon_focus_fhd.png 32 18

echo "Stamped $app_version on the icons in $icons_folder"

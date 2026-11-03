#!/usr/bin/env bash
# Packs the app into a zip that can be sideloaded onto a Roku in developer
# mode, or uploaded to the Roku developer dashboard as a beta channel.
#
# The app's version is written onto the home screen icons in the zip (the
# originals in images/ are left alone). That needs ImageMagick; without it
# the icons are packed as they are, unless REQUIRE_VERSION_ON_ICONS=1 is set,
# in which case the build fails instead.
#
# Usage: tools/build-zip.sh            -> writes dist/hourly-news-switcher.zip
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
output_zip="$project_root/dist/hourly-news-switcher.zip"
staging_folder="$project_root/dist/staging"

rm -rf "$staging_folder" "$output_zip"
mkdir -p "$staging_folder"

cd "$project_root"
cp -r manifest channels.json source components images "$staging_folder/"

if command -v convert >/dev/null; then
  tools/stamp-version-on-icons.sh "$staging_folder/images"
elif [ "${REQUIRE_VERSION_ON_ICONS:-0}" = "1" ]; then
  echo "ImageMagick isn't installed, so the version can't be added to the icons." >&2
  exit 1
else
  echo "ImageMagick isn't installed: packing the icons without the version on them."
fi

# Roku expects the manifest at the top level of the zip, not inside a folder.
cd "$staging_folder"
zip -q -r "$output_zip" manifest channels.json source components images

echo "Built $output_zip"

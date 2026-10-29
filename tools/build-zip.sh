#!/usr/bin/env bash
# Packs the app into a zip that can be sideloaded onto a Roku in developer
# mode, or uploaded to the Roku developer dashboard as a beta channel.
#
# Usage: tools/build-zip.sh            -> writes dist/hourly-news-switcher.zip
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
output_zip="$project_root/dist/hourly-news-switcher.zip"

mkdir -p "$project_root/dist"
rm -f "$output_zip"

# Roku expects the manifest at the top level of the zip, not inside a folder.
cd "$project_root"
zip -q -r "$output_zip" manifest channels.json source components images

echo "Built $output_zip"

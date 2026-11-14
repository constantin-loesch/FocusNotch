#!/bin/bash
# Renders the logo and creates Resources/AppIcon.icns and docs/images/logo.png from it.
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/common.sh
pick_sdk
stage_sources

swiftc -swift-version 5 -sdk "$SDK" -target $TARGET -module-name Icon -o build/make-icon \
  "$SRC"/tools/Icon/*.swift "$SRC"/Sources/Shared/*.swift $(app_sources_without_main)
build/make-icon build/logo-1024.png

ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
  sips -z $SIZE $SIZE build/logo-1024.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  sips -z $((SIZE*2)) $((SIZE*2)) build/logo-1024.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
sips -z 512 512 build/logo-1024.png --out docs/images/logo.png >/dev/null
echo "Done: Resources/AppIcon.icns, docs/images/logo.png"

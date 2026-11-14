#!/bin/bash
# Renders the README images into docs/images (with demo data; your real data stays untouched).
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/common.sh
pick_sdk
stage_sources

swiftc -swift-version 5 -sdk "$SDK" -target $TARGET -module-name Screenshots -o build/screenshots \
  "$SRC"/tools/Screenshots/main.swift "$SRC"/tools/Icon/AppIconView.swift "$SRC"/Sources/Shared/*.swift $(app_sources_without_main) \
  "$SRC"/Sources/FocusNotchWidget/WidgetViews.swift "$SRC"/Sources/FocusNotchWidget/TimerIntents.swift

TMP=$(mktemp -d)
FOCUSNOTCH_SHARED_DIR="$TMP" build/screenshots docs/images
rm -rf "$TMP"
defaults delete screenshots >/dev/null 2>&1 || true

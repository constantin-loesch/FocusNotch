#!/bin/bash
# Rendert die README-Bilder nach docs/images (mit Demo-Daten, echte Daten bleiben unberührt).
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/common.sh
pick_sdk

swiftc -swift-version 5 -sdk "$SDK" -target $TARGET -module-name Screenshots -o build/screenshots \
  tools/Screenshots/main.swift Sources/Shared/*.swift $(app_sources_without_main) \
  Sources/FocusNotchWidget/WidgetViews.swift Sources/FocusNotchWidget/TimerIntents.swift

TMP=$(mktemp -d)
FOCUSNOTCH_SHARED_DIR="$TMP" build/screenshots docs/images
rm -rf "$TMP"
defaults delete screenshots >/dev/null 2>&1 || true

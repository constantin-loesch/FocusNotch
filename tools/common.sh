#!/bin/bash
# Gemeinsame Helfer für build.sh und die Werkzeuge in tools/.

TARGET=arm64-apple-macos14.0
SDK_DIR=/Library/Developer/CommandLineTools/SDKs

# Wählt ein macOS-SDK, das zum installierten Swift-Compiler passt (Ergebnis in $SDK).
pick_sdk() {
  mkdir -p build
  echo 'import SwiftUI' > build/sdkcheck.swift
  SDK=""
  for CANDIDATE in $(xcrun --show-sdk-path 2>/dev/null) $(ls -d "$SDK_DIR"/MacOSX[0-9]*.sdk 2>/dev/null | sort -rV); do
    if swiftc -typecheck -sdk "$CANDIDATE" -target $TARGET build/sdkcheck.swift 2>/dev/null; then SDK="$CANDIDATE"; break; fi
  done
  rm -f build/sdkcheck.swift
  [ -n "$SDK" ] || { echo "Kein passendes macOS-SDK gefunden"; exit 1; }
}

# App-Quellen ohne main.swift (für Werkzeuge mit eigenem Einstiegspunkt)
app_sources_without_main() {
  ls Sources/FocusNotch/*.swift | grep -v '/main.swift$'
}

#!/bin/bash
# Shared helpers for build.sh and the tools in tools/.

TARGET=arm64-apple-macos14.0
SDK_DIR=/Library/Developer/CommandLineTools/SDKs

# Picks a macOS SDK that matches the installed Swift compiler (result in $SDK).
pick_sdk() {
  mkdir -p build
  echo 'import SwiftUI' > build/sdkcheck.swift
  SDK=""
  for CANDIDATE in $(xcrun --show-sdk-path 2>/dev/null) $(ls -d "$SDK_DIR"/MacOSX[0-9]*.sdk 2>/dev/null | sort -rV); do
    if swiftc -typecheck -sdk "$CANDIDATE" -target $TARGET build/sdkcheck.swift 2>/dev/null; then SDK="$CANDIDATE"; break; fi
  done
  rm -f build/sdkcheck.swift
  [ -n "$SDK" ] || { echo "No matching macOS SDK found"; exit 1; }
}

# Copies the sources to a temporary folder outside the project (result in $SRC).
# Synced folders (e.g. an iCloud Desktop) touch files while swiftc runs, which aborts the build.
stage_sources() {
  SRC=$(mktemp -d)/src
  mkdir -p "$SRC"
  cp -R Sources tools "$SRC/"
  trap 'rm -rf "$(dirname "$SRC")"' EXIT
}

# App sources without main.swift (for tools with their own entry point)
app_sources_without_main() {
  ls "$SRC"/Sources/FocusNotch/*.swift | grep -v '/main.swift$'
}

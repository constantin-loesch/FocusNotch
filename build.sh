#!/bin/bash
# Baut "Pomodoro Island.app" in diesem Ordner.
set -euo pipefail
cd "$(dirname "$0")"

# Passendes SDK zum installierten Compiler wählen (neuestes, das baut)
SDK_DIR=/Library/Developer/CommandLineTools/SDKs
mkdir -p build
for SDK in $(xcrun --show-sdk-path 2>/dev/null) $(ls -d "$SDK_DIR"/MacOSX[0-9]*.sdk 2>/dev/null | sort -rV); do
  if swiftc -O -swift-version 5 -sdk "$SDK" -target arm64-apple-macos14.0 \
       -o build/PomodoroIsland Sources/PomodoroIsland/*.swift 2>/dev/null; then
    echo "Gebaut mit SDK: $SDK"; BUILT=1; break
  fi
done
[ "${BUILT:-0}" = 1 ] || { echo "Build fehlgeschlagen"; exit 1; }

APP="Pomodoro Island.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/PomodoroIsland "$APP/Contents/MacOS/PomodoroIsland"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Pomodoro Island</string>
  <key>CFBundleDisplayName</key><string>Pomodoro Island</string>
  <key>CFBundleIdentifier</key><string>de.constantin.pomodoroisland</string>
  <key>CFBundleExecutable</key><string>PomodoroIsland</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP" >/dev/null
echo "Fertig: $APP"

#!/bin/bash
# Baut FocusNotch.app (inkl. Desktop-Widget) in diesem Ordner.
#   ./build.sh          → bauen
#   ./build.sh install  → bauen, nach /Applications kopieren und starten
set -euo pipefail
cd "$(dirname "$0")"

TARGET=arm64-apple-macos14.0
SDK_DIR=/Library/Developer/CommandLineTools/SDKs
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
mkdir -p build

# SDK wählen, das zum installierten Swift-Compiler passt
echo 'import SwiftUI' > build/sdkcheck.swift
SDK=""
for CANDIDATE in $(xcrun --show-sdk-path 2>/dev/null) $(ls -d "$SDK_DIR"/MacOSX[0-9]*.sdk 2>/dev/null | sort -rV); do
  if swiftc -typecheck -sdk "$CANDIDATE" -target $TARGET build/sdkcheck.swift 2>/dev/null; then SDK="$CANDIDATE"; break; fi
done
[ -n "$SDK" ] || { echo "Kein passendes macOS-SDK gefunden"; exit 1; }
echo "SDK: $SDK"

FLAGS=(-O -swift-version 5 -sdk "$SDK" -target $TARGET)
echo "Baue App…"
swiftc "${FLAGS[@]}" -module-name FocusNotch -o build/FocusNotch \
  Sources/Shared/*.swift Sources/FocusNotch/*.swift
echo "Baue Widget…"
swiftc "${FLAGS[@]}" -parse-as-library -application-extension -module-name FocusNotchWidget -o build/FocusNotchWidget \
  Sources/Shared/*.swift Sources/FocusNotchWidget/*.swift

APP="FocusNotch.app"
WEX="$APP/Contents/PlugIns/FocusNotchWidget.appex"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$WEX/Contents/MacOS"
cp build/FocusNotch "$APP/Contents/MacOS/FocusNotch"
cp build/FocusNotchWidget "$WEX/Contents/MacOS/FocusNotchWidget"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>FocusNotch</string>
  <key>CFBundleDisplayName</key><string>FocusNotch</string>
  <key>CFBundleIdentifier</key><string>de.constantin.focusnotch</string>
  <key>CFBundleExecutable</key><string>FocusNotch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.1</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleURLTypes</key>
  <array><dict>
    <key>CFBundleURLName</key><string>de.constantin.focusnotch</string>
    <key>CFBundleURLSchemes</key><array><string>focusnotch</string></array>
  </dict></array>
</dict></plist>
PLIST

cat > "$WEX/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>FocusNotchWidget</string>
  <key>CFBundleDisplayName</key><string>FocusNotch</string>
  <key>CFBundleIdentifier</key><string>de.constantin.focusnotch.widget</string>
  <key>CFBundleExecutable</key><string>FocusNotchWidget</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleShortVersionString</key><string>1.1</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSExtension</key><dict>
    <key>NSExtensionPointIdentifier</key><string>com.apple.widgetkit-extension</string>
  </dict>
</dict></plist>
PLIST

# Datei-Attribute entfernen (sonst verweigert codesign), dann erst Widget, dann App signieren
xattr -cr "$APP"
codesign --force --sign - --entitlements Sources/FocusNotchWidget/FocusNotchWidget.entitlements "$WEX"
codesign --force --sign - "$APP"
echo "Fertig: $APP"

if [ "${1:-}" = "install" ]; then
  pkill -x FocusNotch 2>/dev/null || true
  rm -rf "/Applications/$APP"
  cp -R "$APP" /Applications/
  "$LSREGISTER" -u "$PWD/$APP" 2>/dev/null || true  # Kopie im Projektordner abmelden (sonst doppeltes Widget)
  "$LSREGISTER" -f "/Applications/$APP"
  open "/Applications/$APP"
  echo "Installiert: /Applications/$APP"
fi

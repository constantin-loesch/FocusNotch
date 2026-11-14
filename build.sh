#!/bin/bash
# Builds FocusNotch.app (including the desktop widget) in this folder.
#   ./build.sh          → build
#   ./build.sh install  → build, copy to /Applications and launch
set -euo pipefail
cd "$(dirname "$0")"

source tools/common.sh
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
pick_sdk
stage_sources
echo "SDK: $SDK"
VERSION=$(cat VERSION)
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo 1)

FLAGS=(-O -swift-version 5 -sdk "$SDK" -target $TARGET)
echo "Building app…"
swiftc "${FLAGS[@]}" -module-name FocusNotch -o build/FocusNotch \
  "$SRC"/Sources/Shared/*.swift "$SRC"/Sources/FocusNotch/*.swift
echo "Building widget…"
swiftc "${FLAGS[@]}" -parse-as-library -application-extension -module-name FocusNotchWidget -o build/FocusNotchWidget \
  -Xlinker -e -Xlinker _NSExtensionMain \
  "$SRC"/Sources/Shared/*.swift "$SRC"/Sources/FocusNotchWidget/*.swift

# Assemble and sign outside the project folder (sync services like iCloud add metadata that codesign rejects)
APP_NAME="FocusNotch.app"
APP="$(dirname "$SRC")/$APP_NAME"
WEX="$APP/Contents/PlugIns/FocusNotchWidget.appex"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$WEX/Contents/MacOS"
cp build/FocusNotch "$APP/Contents/MacOS/FocusNotch"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp build/FocusNotchWidget "$WEX/Contents/MacOS/FocusNotchWidget"
python3 tools/make_intents_metadata.py build/FocusNotchWidget "$WEX/Contents/Resources/Metadata.appintents"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>FocusNotch</string>
  <key>CFBundleDisplayName</key><string>FocusNotch</string>
  <key>CFBundleIdentifier</key><string>de.constantin.focusnotch</string>
  <key>CFBundleExecutable</key><string>FocusNotch</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
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
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSExtension</key><dict>
    <key>NSExtensionPointIdentifier</key><string>com.apple.widgetkit-extension</string>
  </dict>
</dict></plist>
PLIST

# Strip extended attributes (codesign refuses otherwise), then sign the widget first, then the app
xattr -cr "$APP"
codesign --force --sign - --entitlements "$SRC"/Sources/FocusNotchWidget/FocusNotchWidget.entitlements "$WEX"
codesign --force --sign - "$APP"
rm -rf "$APP_NAME"
ditto --norsrc --noextattr "$APP" "$APP_NAME"
echo "Done: $APP_NAME"

if [ "${1:-}" = "install" ]; then
  pkill -x FocusNotch 2>/dev/null || true
  rm -rf "/Applications/$APP_NAME"
  ditto --norsrc --noextattr "$APP" "/Applications/$APP_NAME"
  "$LSREGISTER" -u "$PWD/$APP_NAME" 2>/dev/null || true  # unregister the copy in the project folder (avoids a duplicate widget)
  "$LSREGISTER" -f "/Applications/$APP_NAME"
  open "/Applications/$APP_NAME"
  echo "Installed: /Applications/$APP_NAME"
fi

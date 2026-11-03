#!/bin/bash
# FocusNotch installer: downloads the latest release from GitHub and installs it.
#
#   curl -fsSL https://raw.githubusercontent.com/constantin-loesch/FocusNotch/main/install.sh | bash
#
# Uninstall:
#   curl -fsSL https://raw.githubusercontent.com/constantin-loesch/FocusNotch/main/install.sh | bash -s -- --uninstall
set -euo pipefail

REPO="constantin-loesch/FocusNotch"
APP="FocusNotch.app"
URL="${FOCUSNOTCH_ZIP_URL:-https://github.com/$REPO/releases/latest/download/FocusNotch.zip}"  # override for testing only
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
fail() { printf "\033[31mError:\033[0m %s\n" "$1" >&2; exit 1; }

# Destination: /Applications, or ~/Applications without admin rights
if [ -w /Applications ]; then DEST=/Applications; else DEST="$HOME/Applications"; mkdir -p "$DEST"; fi

if [ "${1:-}" = "--uninstall" ]; then
  bold "Removing FocusNotch…"
  pkill -x FocusNotch 2>/dev/null || true
  for D in /Applications "$HOME/Applications"; do
    [ -d "$D/$APP" ] && "$LSREGISTER" -u "$D/$APP" 2>/dev/null; rm -rf "${D:?}/$APP"
  done
  rm -rf "$HOME/Library/Application Support/FocusNotch"
  echo "Removed. Your statistics are kept (delete them with: defaults delete de.constantin.focusnotch)."
  exit 0
fi

# Requirements
[ "$(uname -s)" = "Darwin" ] || fail "FocusNotch only runs on macOS."
[ "$(uname -m)" = "arm64" ] || fail "FocusNotch requires a Mac with Apple silicon."
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[ "$MAJOR" -ge 14 ] || fail "FocusNotch requires macOS 14 (Sonoma) or later."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

bold "Downloading FocusNotch…"
curl -fL --progress-bar "$URL" -o "$TMP/FocusNotch.zip" || fail "Download failed ($URL)."
ditto -x -k "$TMP/FocusNotch.zip" "$TMP" || fail "Could not unpack the archive."
[ -d "$TMP/$APP" ] || fail "$APP is missing from the archive."

bold "Installing to $DEST…"
pkill -x FocusNotch 2>/dev/null || true
sleep 0.5
rm -rf "${DEST:?}/$APP"
ditto "$TMP/$APP" "$DEST/$APP"
xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true
"$LSREGISTER" -f "$DEST/$APP"

open "$DEST/$APP"
VERSION=$(defaults read "$DEST/$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "?")
echo
bold "✓ FocusNotch $VERSION is installed and running – look at the notch."
echo "  Widget: right-click the desktop → \"Edit Widgets…\" → \"FocusNotch\"."
echo "  Autostart: expand the island → gear → \"Launch at login\"."

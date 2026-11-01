#!/bin/bash
# FocusNotch-Installer: lädt die neueste Version von GitHub und installiert sie.
#
#   curl -fsSL https://raw.githubusercontent.com/constantin-loesch/FocusNotch/main/install.sh | bash
#
# Deinstallieren:
#   curl -fsSL https://raw.githubusercontent.com/constantin-loesch/FocusNotch/main/install.sh | bash -s -- --uninstall
set -euo pipefail

REPO="constantin-loesch/FocusNotch"
APP="FocusNotch.app"
URL="${FOCUSNOTCH_ZIP_URL:-https://github.com/$REPO/releases/latest/download/FocusNotch.zip}"  # Umlenkung nur zum Testen
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
fail() { printf "\033[31mFehler:\033[0m %s\n" "$1" >&2; exit 1; }

# Zielordner: /Applications, sonst ~/Applications (ohne Admin-Rechte)
if [ -w /Applications ]; then DEST=/Applications; else DEST="$HOME/Applications"; mkdir -p "$DEST"; fi

if [ "${1:-}" = "--uninstall" ]; then
  bold "FocusNotch wird entfernt…"
  pkill -x FocusNotch 2>/dev/null || true
  for D in /Applications "$HOME/Applications"; do
    [ -d "$D/$APP" ] && "$LSREGISTER" -u "$D/$APP" 2>/dev/null; rm -rf "${D:?}/$APP"
  done
  rm -rf "$HOME/Library/Application Support/FocusNotch"
  echo "Entfernt. Deine Statistik bleibt erhalten (löschen: defaults delete de.constantin.focusnotch)."
  exit 0
fi

# Voraussetzungen
[ "$(uname -s)" = "Darwin" ] || fail "FocusNotch läuft nur auf macOS."
[ "$(uname -m)" = "arm64" ] || fail "FocusNotch braucht einen Mac mit Apple Silicon."
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[ "$MAJOR" -ge 14 ] || fail "FocusNotch braucht macOS 14 (Sonoma) oder neuer."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

bold "FocusNotch wird heruntergeladen…"
curl -fL --progress-bar "$URL" -o "$TMP/FocusNotch.zip" || fail "Download fehlgeschlagen ($URL)."
ditto -x -k "$TMP/FocusNotch.zip" "$TMP" || fail "Archiv konnte nicht entpackt werden."
[ -d "$TMP/$APP" ] || fail "Im Archiv fehlt $APP."

bold "Installiere nach $DEST…"
pkill -x FocusNotch 2>/dev/null || true
sleep 0.5
rm -rf "${DEST:?}/$APP"
ditto "$TMP/$APP" "$DEST/$APP"
xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true
"$LSREGISTER" -f "$DEST/$APP"

open "$DEST/$APP"
VERSION=$(defaults read "$DEST/$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "?")
echo
bold "✓ FocusNotch $VERSION ist installiert und läuft – schau oben an die Notch."
echo "  Widget: Rechtsklick auf den Schreibtisch → „Widgets bearbeiten…“ → „FocusNotch“."
echo "  Autostart: Island aufklappen → Zahnrad → „Beim Login starten“."

#!/bin/bash
# Baut FocusNotch, packt es als FocusNotch.zip und veröffentlicht ein GitHub-Release (v<VERSION>).
# Voraussetzung: GitHub-CLI angemeldet (gh auth login).
#   ./tools/release.sh            → Release erstellen
#   ./tools/release.sh --zip-only → nur build/FocusNotch.zip erzeugen
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
TAG="v$VERSION"

./build.sh
rm -f build/FocusNotch.zip
ditto -c -k --keepParent FocusNotch.app build/FocusNotch.zip
echo "Archiv: build/FocusNotch.zip ($(du -h build/FocusNotch.zip | cut -f1))"
[ "${1:-}" = "--zip-only" ] && exit 0

command -v gh >/dev/null || { echo "GitHub-CLI fehlt: brew install gh"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Bitte zuerst anmelden: gh auth login"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Es gibt nicht committete Änderungen – bitte erst committen."; exit 1; }
git push

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "Release $TAG existiert schon – lade das Archiv neu hoch."
  gh release upload "$TAG" build/FocusNotch.zip --clobber
else
  gh release create "$TAG" build/FocusNotch.zip --title "FocusNotch $VERSION" --notes "$(cat <<NOTES
**Installieren** – im Terminal ausführen:

\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/constantin-loesch/FocusNotch/main/install.sh | bash
\`\`\`

Voraussetzungen: macOS 14 oder neuer, Apple Silicon.
NOTES
)"
fi
echo "Fertig: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/$TAG"

#!/bin/bash
# Builds FocusNotch, packs it as FocusNotch.zip and publishes a GitHub release (v<VERSION>).
# Requires a logged-in GitHub CLI (gh auth login).
#   ./tools/release.sh            → create the release
#   ./tools/release.sh --zip-only → only create build/FocusNotch.zip
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
TAG="v$VERSION"

./build.sh
rm -f build/FocusNotch.zip
ditto -c -k --norsrc --noextattr --keepParent FocusNotch.app build/FocusNotch.zip
echo "Archive: build/FocusNotch.zip ($(du -h build/FocusNotch.zip | cut -f1))"
[ "${1:-}" = "--zip-only" ] && exit 0

command -v gh >/dev/null || { echo "GitHub CLI missing: brew install gh"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Please log in first: gh auth login"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "There are uncommitted changes – please commit first."; exit 1; }
git push

NOTES=$(cat <<'NOTES'
**Install** – run in Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/constantin-loesch/FocusNotch/main/install.sh | bash
```

Requirements: macOS 14 or later, Apple silicon.
NOTES
)

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "Release $TAG already exists – re-uploading the archive and notes."
  gh release upload "$TAG" build/FocusNotch.zip --clobber
  gh release edit "$TAG" --title "FocusNotch $VERSION" --notes "$NOTES"
else
  gh release create "$TAG" build/FocusNotch.zip --title "FocusNotch $VERSION" --notes "$NOTES"
fi
echo "Done: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/$TAG"

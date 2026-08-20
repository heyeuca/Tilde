#!/bin/bash
# Packages Tilde.app into a drag-to-install DMG.
#
#   scripts/make_dmg.sh <path/to/Tilde.app> <output.dmg>
#
# The volume contains the app and an /Applications symlink — the standard
# macOS install experience. Signing and notarization are separate steps
# (see .github/workflows/release.yml).

set -euo pipefail

APP="${1:?usage: make_dmg.sh <Tilde.app> <output.dmg>}"
OUT="${2:?usage: make_dmg.sh <Tilde.app> <output.dmg>}"

if [[ ! -d "$APP" ]]; then
    echo "error: $APP is not a directory" >&2
    exit 1
fi

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$OUT"
hdiutil create \
    -volname "Tilde" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$OUT"

echo "created $OUT ($(du -h "$OUT" | cut -f1 | tr -d ' '))"

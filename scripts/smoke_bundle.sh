#!/bin/bash
# Builds an UNSIGNED, UNSANDBOXED Tilde.app for local smoke testing on a
# machine with only the Command Line Tools (no xcodebuild).
#
# NOT a release artifact: no code signing, no sandbox, no asset catalog —
# real builds and sandbox behavior are verified per docs/VERIFY.md on the
# Xcode device. Used directly and by Tests/ui_smoke.sh.
#
# Usage: scripts/smoke_bundle.sh [output-dir]   (default /tmp/TildeSmoke)

set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-/tmp/TildeSmoke}"
APP="$OUT/Tilde.app"
TARGET="arm64-apple-macos14.0"
[[ "$(uname -m)" == "x86_64" ]] && TARGET="x86_64-apple-macos14.0"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

xcrun swiftc -O -target "$TARGET" -sdk "$(xcrun --show-sdk-path)" \
    -swift-version 5 -default-isolation MainActor \
    -enable-upcoming-feature MemberImportVisibility \
    -parse-as-library \
    -o "$APP/Contents/MacOS/Tilde" \
    Tilde/App/*.swift Tilde/Document/*.swift Tilde/Editor/*.swift \
    Tilde/Reader/*.swift Tilde/Settings/*.swift \
    2> >(grep -v -i "warning" >&2 || true)

# String Catalogs: xcodebuild compiles these into <lang>.lproj/*.strings;
# without it, do the same by hand so localization is testable here
# (launch with `-AppleLanguages '(ko)'` to try a language).
scripts/compile_xcstrings.py "$APP/Contents/Resources" Tilde/*.xcstrings

# The repo Info.plist holds only the document/UTI declarations (Xcode
# generates the identity keys at build time), so fill those in here.
cp Tilde/Info.plist "$APP/Contents/Info.plist"
for entry in \
    "CFBundleExecutable string Tilde" \
    "CFBundleIdentifier string local.tilde.smoke" \
    "CFBundleName string Tilde" \
    "CFBundleDevelopmentRegion string en" \
    "CFBundlePackageType string APPL" \
    "CFBundleShortVersionString string 0.0-smoke" \
    "LSMinimumSystemVersion string 14.0"; do
    key="${entry%% *}"; rest="${entry#* }"
    /usr/libexec/PlistBuddy -c "Add :$key ${rest}" "$APP/Contents/Info.plist" >/dev/null 2>&1 \
        || /usr/libexec/PlistBuddy -c "Set :$key ${rest#* }" "$APP/Contents/Info.plist"
done

echo "$APP"

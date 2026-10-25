#!/bin/zsh
# Builds Copaste in Release and packages it for a GitHub release and the Homebrew cask:
#   build/Copaste-<version>.dmg   drag-to-Applications disk image
#   build/Copaste-<version>.zip   the same app, for `brew install --cask`
#
#   scripts/make_release.sh
#
# The app is signed with the first "Apple Development" identity (set SIGN_IDENTITY to use another), so macOS keeps
# the Accessibility permission across updates. Without an identity it falls back to ad-hoc signing.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT=$PWD
BUILD="$ROOT/build"
DERIVED="$BUILD/DerivedData"
APP="$DERIVED/Build/Products/Release/Copaste.app"

echo "→ Building Copaste (Release)…"
xcodebuild -project Copaste.xcodeproj -scheme Copaste -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" -quiet build
[[ -d "$APP" ]] || { echo "✗ Build finished but $APP is missing" >&2; exit 1; }

IDENTITY=${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | grep -m1 "Apple Development" | awk '{print $2}')}
echo "→ Signing with ${IDENTITY:-ad hoc}…"
codesign --force --deep --options runtime --timestamp=none --sign "${IDENTITY:--}" "$APP"
codesign --verify --deep --strict "$APP"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$BUILD/Copaste-$VERSION.dmg"
ZIP="$BUILD/Copaste-$VERSION.zip"

echo "→ Packaging Copaste $VERSION…"
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Copaste.app"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG" "$ZIP"
hdiutil create -volname "Copaste $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" -quiet
hdiutil verify "$DMG" -quiet
ditto -c -k --keepParent "$APP" "$ZIP"

echo "✓ $DMG ($(du -h "$DMG" | cut -f1))"
echo "✓ $ZIP ($(du -h "$ZIP" | cut -f1))"
echo "  sha256 (for the cask): $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"

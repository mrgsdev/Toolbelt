#!/bin/bash
# Builds Toolbelt in Release and packs build/Toolbelt-<version>.dmg and build/Toolbelt-<version>.zip.
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT=Toolbelt.xcodeproj
SCHEME=Toolbelt
BUILD=build

VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ MARKETING_VERSION = / { print $2; exit }')
VERSION=${VERSION:-1.0}

rm -rf "$BUILD"
mkdir -p "$BUILD"

echo "→ Сборка Toolbelt $VERSION (Release, Apple Silicon + Intel)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$BUILD" \
  ONLY_ACTIVE_ARCH=NO -quiet build

APP="$BUILD/Build/Products/Release/Toolbelt.app"

echo "→ Toolbelt-$VERSION.dmg"
STAGE="$BUILD/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Toolbelt" -srcfolder "$STAGE" -ov -format UDZO "$BUILD/Toolbelt-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"

echo "→ Toolbelt-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$BUILD/Toolbelt-$VERSION.zip"

echo "Готово:"
ls -lh "$BUILD"/Toolbelt-"$VERSION".*

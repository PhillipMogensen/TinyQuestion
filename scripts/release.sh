#!/usr/bin/env bash
# Build a Release universal binary and wrap it in a DMG.
#
#   usage: scripts/release.sh <version>
#   e.g.   scripts/release.sh 0.1.0
#
# Output: dist/TinyQuestion-<version>.dmg
#
# This produces an *unsigned* DMG (ad-hoc signed only). End users will see a
# Gatekeeper warning on first launch — the README explains the workaround.
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <version>   (e.g. $0 0.1.0)" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="TinyQuestion"
BUILD_DIR="$REPO_ROOT/build/release"
DIST_DIR="$REPO_ROOT/dist"
APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

echo "==> Regenerating Xcode project"
xcodegen generate >/dev/null

echo "==> Cleaning previous Release build"
rm -rf "$BUILD_DIR"
mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

echo "==> Building Release (universal arm64 + x86_64)"
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  build 2>&1 | tail -3

if [[ ! -d "$APP_PATH" ]]; then
  echo "build failed: $APP_PATH not found" >&2
  exit 1
fi

echo "==> Verifying universal binary"
file "$APP_PATH/Contents/MacOS/$APP_NAME" | sed 's/^/    /'

echo "==> Building DMG"
create-dmg \
  --volname "$APP_NAME $VERSION" \
  --window-pos 200 120 \
  --window-size 600 380 \
  --icon-size 128 \
  --icon "$APP_NAME.app" 165 180 \
  --app-drop-link 435 180 \
  --hide-extension "$APP_NAME.app" \
  --no-internet-enable \
  "$DMG_PATH" \
  "$APP_PATH" >/dev/null

SIZE="$(du -h "$DMG_PATH" | awk '{print $1}')"
echo ""
echo "==> Done"
echo "    DMG: $DMG_PATH ($SIZE)"

#!/bin/bash
# Builds a Release copy of TrackHot and zips it for a GitHub release.
# Output: build/TrackHot-<version>.zip
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"

# Use full Xcode even if xcode-select points at the Command Line Tools.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

rm -rf "$BUILD_DIR"

# Ad-hoc signing ("-") keeps the bundle identity intact so macOS can match the
# Accessibility grant. Don't swap this for CODE_SIGNING_ALLOWED=NO: that strips
# the identity and the permission can never be granted.
xcodebuild \
  -project "$ROOT/TrackHot.xcodeproj" \
  -scheme TrackHot \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" \
  build

APP="$BUILD_DIR/DerivedData/Build/Products/Release/TrackHot.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ZIP="$BUILD_DIR/TrackHot-$VERSION.zip"

codesign --verify --deep --strict "$APP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Built $ZIP"

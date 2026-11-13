#!/bin/bash
# Builds dist/Buzz.app, dist/buzz-<version>.dmg and dist/buzz-macos.tar.gz.
#
#   Scripts/build-dmg.sh
#   VERSION=0.2.0 Scripts/build-dmg.sh
#   CODESIGN_IDENTITY="Developer ID Application: ..." Scripts/build-dmg.sh
#
# Without CODESIGN_IDENTITY the app is ad-hoc signed: fine on this Mac, but other
# Macs will show a Gatekeeper warning until it is Developer ID signed and notarized.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="buzz"
DISPLAY_NAME="Buzz"
BUNDLE_ID="${BUNDLE_ID:-io.github.2c2c.buzz}"
VERSION="${VERSION:-0.1.2}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

DIST="dist"
APP="$DIST/$DISPLAY_NAME.app"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
ICON="Resources/AppIcon.icns"

# Universal build when the toolchain supports it, otherwise this Mac's architecture.
ARCH_FLAGS=(--arch arm64 --arch x86_64)
if ! swift build -c release "${ARCH_FLAGS[@]}"; then
  echo "Universal build failed; building for this Mac's architecture only." >&2
  ARCH_FLAGS=()
  swift build -c release
fi
BIN="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/$APP_NAME"

if [[ ! -f "$ICON" ]]; then
  echo "Generating app icon"
  WORK="$(mktemp -d)"
  swift Scripts/make-icon.swift "$WORK/icon-1024.png"
  ICONSET="$WORK/AppIcon.iconset"
  mkdir -p "$ICONSET" Resources
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$ICON"
  rm -rf "$WORK"
fi

rm -rf "$APP" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP"
fi
codesign --verify --strict "$APP"

STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$DISPLAY_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

# Tarball for the curl | sh installer. A fixed name keeps the "latest release" URL stable.
TARBALL="$DIST/$APP_NAME-macos.tar.gz"
COPYFILE_DISABLE=1 tar -czf "$TARBALL" -C "$DIST" "$DISPLAY_NAME.app"

echo "Built $APP"
echo "Built $DMG"
echo "Built $TARBALL"

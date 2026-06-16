#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Prompt Now"
EXECUTABLE_NAME="PromptNow"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.promptnow.PromptNow}"
APP_CATEGORY="${APP_CATEGORY:-public.app-category.productivity}"
COPYRIGHT="${COPYRIGHT:-Copyright © 2026 Prompt Now. All rights reserved.}"
APP_STORE="${APP_STORE:-0}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ENTITLEMENTS="${ENTITLEMENTS:-}"

cd "$ROOT_DIR"

swift_build_args=(build -c "$BUILD_CONFIG")
if [[ "$APP_STORE" == "1" ]]; then
  swift_build_args+=(-Xswiftc -DAPP_STORE)
  ENTITLEMENTS="${ENTITLEMENTS:-$ROOT_DIR/packaging/macos/PromptNow.mas.entitlements}"
fi

swift "${swift_build_args[@]}" >&2

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/$BUILD_CONFIG/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

for bundle in ".build/$BUILD_CONFIG"/*.bundle ".build/$(uname -m)-apple-macosx/$BUILD_CONFIG"/*.bundle; do
  if [[ -d "$bundle" ]]; then
    cp -R "$bundle" "$RESOURCES_DIR/"
  fi
done

if command -v iconutil >/dev/null 2>&1 && [[ -f "$ROOT_DIR/scripts/generate-app-icon.swift" ]]; then
  ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
  rm -rf "$ICONSET_DIR"
  swift "$ROOT_DIR/scripts/generate-app-icon.swift" "$ICONSET_DIR"
  iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
  rm -rf "$ICONSET_DIR"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_IDENTIFIER</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>$APP_CATEGORY</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>$COPYRIGHT</string>
  <key>NSSupportsAutomaticTermination</key>
  <true/>
  <key>NSSupportsSuddenTermination</key>
  <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  codesign_args=(--force --deep --sign "$SIGN_IDENTITY")
  if [[ -n "$ENTITLEMENTS" ]]; then
    codesign_args+=(--entitlements "$ENTITLEMENTS")
  fi
  if [[ "$SIGN_IDENTITY" != "-" ]]; then
    codesign_args+=(--timestamp)
  fi
  codesign "${codesign_args[@]}" "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
PACKAGE_PATH="$DIST_DIR/PromptNow-$VERSION-mas.pkg"

if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  echo "SIGN_IDENTITY is required, for example: 3rd Party Mac Developer Application: Your Name (TEAMID)" >&2
  exit 64
fi

if [[ -z "${INSTALLER_IDENTITY:-}" ]]; then
  echo "INSTALLER_IDENTITY is required, for example: 3rd Party Mac Developer Installer: Your Name (TEAMID)" >&2
  exit 64
fi

APP_PATH="$(
  APP_STORE=1 \
  VERSION="$VERSION" \
  BUILD_NUMBER="$BUILD_NUMBER" \
  DIST_DIR="$DIST_DIR" \
  SIGN_IDENTITY="$SIGN_IDENTITY" \
  "$ROOT_DIR/scripts/build-app.sh"
)"

rm -f "$PACKAGE_PATH"
productbuild \
  --component "$APP_PATH" /Applications \
  --sign "$INSTALLER_IDENTITY" \
  "$PACKAGE_PATH"

echo "$PACKAGE_PATH"

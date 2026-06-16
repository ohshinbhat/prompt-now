#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
ARCHIVE_NAME="PromptNow-$VERSION-macos.zip"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
ARCHIVE_PATH="$DIST_DIR/$ARCHIVE_NAME"

APP_PATH="$(VERSION="$VERSION" DIST_DIR="$DIST_DIR" "$ROOT_DIR/scripts/build-app.sh")"

rm -f "$ARCHIVE_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ARCHIVE_PATH"

SHA256="$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')"
LOCAL_CASK_PATH="$DIST_DIR/prompt-now.rb"
LOCAL_TAP_DIR="$DIST_DIR/homebrew-local"
LOCAL_TAP_CASK_PATH="$LOCAL_TAP_DIR/Casks/prompt-now.rb"

write_cask() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<CASK
cask "prompt-now" do
  version "$VERSION"
  sha256 "$SHA256"

  url "file://$ARCHIVE_PATH"
  name "Prompt Now"
  desc "Menu bar reminder for returning to Codex or Claude prompts"
  homepage "https://github.com/OWNER/prompt-now"

  depends_on macos: ">= :ventura"

  app "Prompt Now.app"

  zap trash: [
    "~/Library/Preferences/com.promptnow.PromptNow.plist",
  ]
end
CASK
}

write_cask "$LOCAL_CASK_PATH"
rm -rf "$LOCAL_TAP_DIR"
write_cask "$LOCAL_TAP_CASK_PATH"
git -C "$LOCAL_TAP_DIR" init --quiet
git -C "$LOCAL_TAP_DIR" add Casks/prompt-now.rb
git -C "$LOCAL_TAP_DIR" \
  -c user.name="Prompt Now Packager" \
  -c user.email="prompt-now@example.invalid" \
  commit --quiet -m "Add Prompt Now cask"

printf 'archive=%s\n' "$ARCHIVE_PATH"
printf 'sha256=%s\n' "$SHA256"
printf 'local_cask=%s\n' "$LOCAL_CASK_PATH"
printf 'local_tap=%s\n' "$LOCAL_TAP_DIR"
printf 'tap_command=brew tap prompt-now/local file://%s\n' "$LOCAL_TAP_DIR"
printf 'install_command=brew install --cask prompt-now/local/prompt-now\n'

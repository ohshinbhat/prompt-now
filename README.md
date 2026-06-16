# Prompt Now

A tiny native macOS menu bar app that brings your last Codex or Claude desktop window back after a timer so you remember to review changes and prompt again.

## Build

```sh
swift run PromptNowCoreCheck
./scripts/build-app.sh
```

The packaged app is created at:

```text
dist/Prompt Now.app
```

## Run During Development

```sh
swift run PromptNow
```

The app lives in the menu bar, shows the countdown, and can be turned off from its menu.

When run with `swift run`, macOS notifications and Launch at Login are skipped because those APIs require a real `.app` bundle. Use `./scripts/build-app.sh` for the full menu bar app.

## Homebrew

Generate a Homebrew-ready zip and local cask:

```sh
./scripts/package-homebrew.sh
```

The script prints the archive path, SHA-256, generated local tap, and install commands:

```sh
brew tap prompt-now/local file:///absolute/path/to/dist/homebrew-local
brew install --cask prompt-now/local/prompt-now
```

For a public tap, publish the generated `PromptNow-<version>-macos.zip` on GitHub Releases, then update `Casks/prompt-now.rb` with your GitHub owner/repo and the printed SHA-256.

## Mac App Store

The App Store build uses the sandbox entitlement at `packaging/macos/PromptNow.mas.entitlements` and compiles with `APP_STORE=1`, which disables the Accessibility window-raising path. It still focuses the last Codex or Claude app through public workspace APIs.

Build a package for upload:

```sh
SIGN_IDENTITY="3rd Party Mac Developer Application: Your Name (TEAMID)" \
INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Your Name (TEAMID)" \
BUNDLE_IDENTIFIER="com.yourcompany.PromptNow" \
VERSION="0.1.0" \
BUILD_NUMBER="1" \
./scripts/build-mas-pkg.sh
```

Before submission, create the matching bundle ID and app record in App Store Connect, replace the placeholder bundle identifier, and verify the final app metadata, screenshots, privacy answers, and review notes for the app's reminder and cross-app focus behavior.

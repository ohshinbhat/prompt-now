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

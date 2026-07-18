# Papercuts

## 2026-07-18 16:39 — Sonnet 5
Owner reported another macOS keychain prompt from AI Status Bar, hours after this morning's fix (re-signing ~/Applications/AIStatusBar.app with the Developer ID cert). Root cause: `build.sh` (local dev/test build) still ad-hoc signed (`codesign --sign -`), so every local rebuild got a fresh, hash-pinned code identity that invalidates prior Keychain "Always Allow" grants — separate from the release path in `release.sh`, which already used the Developer ID cert. Fixed `build.sh` to sign with the same Developer ID Application cert (hardened runtime, falls back to ad-hoc if no cert present, e.g. CI). Verified: rebuilt binary's CDHash now matches the installed release build exactly, confirming a stable, reproducible identity across rebuilds.

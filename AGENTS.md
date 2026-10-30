# AGENTS.md

Guidance for AI coding agents working in this repo. See `README.md` for user-facing docs.

## Project

QRnesto is a native macOS and iOS app (SwiftUI, Swift 5.9+, macOS 13+, iOS 16+) that reads QR codes and decodes them into labelled fields. It is a Swift package with two targets:

- `QRCore` (library): `QRDecoder` finds QR codes with Vision; `PayloadParser` turns a raw payload into labelled fields.
- `QRnesto` (executable): SwiftUI app, camera session, screen capture and app state.

The iOS app lives in `iOS/`: `iOS/QRnesto.xcodeproj` (target and scheme `QRnesto-iOS`) builds the sources in `iOS/QRnesto/` and depends on the `QRCore` product of the local package. It uses a synchronized folder, so new files in `iOS/QRnesto/` are picked up without editing the project. The Mac app has no Xcode project and builds with the Swift toolchain only; the iOS app needs full Xcode.

## Commands

| Task | Command |
|---|---|
| Debug build | `swift build` (or `make debug`) |
| Release build | `swift build -c release` (or `make build`) |
| Build `.app` bundle into `./build` | `make app` |
| Rebuild and launch | `make run` |
| Build and launch iOS app in Simulator | `make ios-sim` (`SIM="iPhone 17"` picks the device) |
| Build, install and launch on a connected iPhone | `make ios-device` (`make ios-help` for setup) |
| Tests | `swift test` (no tests exist yet) |
| Clean | `make clean` |
| All targets | `make help` |

Before finishing a change, make sure `swift build` succeeds, and `make ios-sim` too if you touched `QRCore` or `iOS/`. Run `swift test` too once tests exist.

## Conventions

- Keep decoding and parsing logic in `QRCore`, with no UI or AppKit dependencies, so it stays testable. UI, camera and screen-capture code belong in `QRnesto`.
- New payload types go in `PayloadParser`, recognised by prefix, with plain text as the fallback. Add a matching row to the content table in `README.md`.
- Mark sensitive fields (passwords, OTP secrets) with `secret: true` so the UI hides them until the user clicks Show.
- Never open links automatically. The user chooses when to open one.
- Match the surrounding style: small files, minimal comments, no new dependencies unless needed.
- App-layer changes usually need doing twice: `Sources/QRnesto` (AppKit) and `iOS/QRnesto` (UIKit). Keep shared logic in `QRCore`, which must keep building for both platforms.
- The iOS `Info.plist` is generated from `INFOPLIST_KEY_*` build settings in the Xcode project; add iOS usage descriptions there.
- `scripts/build_app.sh` generates `Info.plist` inline. Add new usage-description keys there (for example for a new permission), and update the Permissions table in `README.md`.
- Don't commit `.build/` or `build/`. Both are in `.gitignore`.

## Testing notes

- Add tests under `Tests/QRCoreTests` and a `.testTarget` in `Package.swift`.
- The package is macOS-only, so it will not build on Linux.
- Camera and screen capture need macOS permissions. Verify them manually with `make run`.

## Git and PRs

- Never commit or push directly to `main`. Always work on a branch and open a PR.
- Open PRs from a `feature/`, `bugfix/` or `hotfix/` branch, not from `main`.
- The only author name to use is `douernesto`, in files, commit authorship and PRs.

# QRnesto

A native macOS app that reads QR codes and decodes their content into readable, structured fields.

## Features

- **Four ways to scan**
  - Drop an image file onto the window, or use **Open…** (⌘O)
  - **Paste** an image from the clipboard (⇧⌘V)
  - **Capture Screen** to drag a region of your screen (⇧⌘C)
  - **Use Camera** for live scanning (⌘K)
- Finds every QR code in an image, including light-on-dark (inverted) codes.
- Decodes the payload into labelled fields, each with a copy button:

  | Content | Fields shown | Action |
  |---|---|---|
  | Web link | URL, host, path, query parameters | Open in Browser |
  | Wi‑Fi | Network, security, password (hidden until you click Show), hidden flag | |
  | Contact (vCard, MECARD) | Name, organisation, title, phone, email, URL, address, note, birthday | |
  | Calendar event | Title, start, end, location, description | |
  | One-time password (`otpauth://`) | Type, account, issuer, secret (hidden until you click Show) | |
  | Email (`mailto:`, `MATMSG:`) | To, subject, body | Compose Email |
  | SMS, phone, geo | Number and message, or coordinates | Open in Maps (geo) |
  | JSON | Pretty-printed | |
  | Anything else | Plain text | |

- **Show raw** and **Copy raw** are available for every result.
- Links are never opened automatically. You choose when to open one.

## Requirements

- macOS 13 or later
- Swift 5.9+ toolchain. The Xcode Command Line Tools are enough; full Xcode is not required.
- Intel or Apple Silicon. `make app` builds for the Mac you run it on; `make universal` builds both.
- A camera, and permission to use it, for live scanning. Screen capture needs Screen Recording permission.

Run `make check` to verify these before building. `make app` runs the same check first.

## Quick start

```sh
make run
```

This builds `build/QRnesto.app`, stops any running copy, and launches the new build.

The app is ad-hoc signed. If macOS blocks it on another Mac, right-click the app in Finder and choose **Open**.

## Make targets

Run `make help` for the full list.

| Command | What it does |
|---|---|
| `make run` | Stop any running copy, rebuild, and launch |
| `make app` | Build the signed `.app` for this Mac (Intel or Apple Silicon) into `./build` |
| `make universal` | Build a universal (Apple Silicon + Intel) `.app` into `./build` |
| `make build` / `make debug` | Compile the release or debug binary only |
| `make install` | Copy the app to `/Applications` (override with `INSTALL_DIR=~/Applications`) |
| `make uninstall` | Remove the installed copy |
| `make quit` | Stop the running app |
| `make logs` | Stream the app's log output |
| `make crash-report` | Print the latest crash report's exception and stack |
| `make clean` | Delete `.build/` and `build/` |

## Permissions

| Feature | Permission | Where to change it |
|---|---|---|
| Use Camera | Camera | System Settings › Privacy & Security › Camera |
| Capture Screen | Screen Recording | System Settings › Privacy & Security › Screen & System Audio Recording |

macOS asks the first time you use each feature. The app only sees the camera or screen while you use that feature. Rebuilding the app changes its signature, so macOS may ask again after a rebuild.

## Project layout

```
Package.swift                 Swift package: QRCore library + QRnesto app
scripts/build_app.sh          Wraps the binary into QRnesto.app with an Info.plist and icon, and signs it
scripts/check_env.sh          Checks that this Mac can build the app (make check)
Makefile                      Developer commands
Resources/AppIcon.png         1024x1024 app icon, converted to .icns at build time
Sources/
  QRCore/
    QRDecoder.swift           Finds QR codes in images and camera frames (Vision)
    PayloadParser.swift       Turns a raw payload into labelled fields
  QRnesto/
    QRnestoApp.swift         App entry point and menu commands
    ScannerModel.swift        State: image, results, camera, screen capture
    CameraScanner.swift       AVFoundation camera session and preview
    ContentView.swift         SwiftUI window
```

## How it works

- `QRDecoder` uses Apple's Vision framework (`VNDetectBarcodesRequest`). If nothing is found, it retries on a colour-inverted copy of the image. A payload that is not valid text is shown as hex.
- The camera scanner feeds live frames to the same decoder, about six times a second. New codes are added to the top of the results list, and a code you have already scanned is not added twice.
- `PayloadParser` recognises a payload by its prefix (`WIFI:`, `BEGIN:VCARD`, `otpauth://`, and so on) and falls back to plain text.

## Contributing

Never commit or push directly to `main`. Make every change on a `feature/`, `bugfix/` or `hotfix/` branch and open a pull request.

## Known limitations

- Payment QR formats (for example EMVCo or PIX) are shown as plain text, not parsed into fields.
- Raw binary payloads are shown as hex, not interpreted.
- There are no automated tests in the repo yet.

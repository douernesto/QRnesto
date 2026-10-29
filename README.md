# QRnesto

A native macOS and iOS app that reads QR codes and barcodes and decodes their content into readable, structured fields.

## Features

- **Four ways to scan**
  - Drop an image file onto the window, or use **Open…** (⌘O)
  - **Paste** an image from the clipboard (⇧⌘V)
  - **Capture Screen** to drag a region of your screen (⇧⌘C)
  - **Use Camera** for live scanning (⌘K). It stops by itself after 2 minutes; change this in Settings (⌘,)
- Finds every QR code and barcode (EAN, UPC, Code 128, Data Matrix, PDF417, Aztec and others Vision supports) in an image, including light-on-dark (inverted) codes.
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
  | Product barcode (EAN-8, UPC-A, EAN-13, GTIN-14) | Number, format | |
  | Anything else | Plain text | |

- **Show raw** and **Copy raw** are available for every result.
- Links are never opened automatically. You choose when to open one.

## Requirements

- macOS 13 or later
- Swift 5.9+ toolchain. The Xcode Command Line Tools are enough; full Xcode is not required.
- Intel or Apple Silicon. `make app` builds for the Mac you run it on; `make universal` builds both.
- A camera, and permission to use it, for live scanning. Screen capture needs Screen Recording permission.

Run `make check` to verify these before building. `make app` runs the same check first.

## iOS app

The iOS app (iPhone, iOS 16 or later) lives in `iOS/` and uses the same `QRCore` decoder and parser as the Mac app. It scans with the camera, from a photo, or from an image on the clipboard. Screen capture is not available on iOS.

It needs full Xcode, not just the Command Line Tools.

```sh
make ios-sim                  # build and launch in the iOS Simulator
SIM="iPhone 17 Pro" make ios-sim
```

The Simulator has no camera, so use **Photo** or **Paste** there: drag a QR image onto the Simulator window to add it to Photos. To test live scanning, run the app on your iPhone.

### Run on your iPhone (free Apple ID)

You do not need a paid Apple Developer Program membership to run the app on your own iPhone. Xcode signs it with a free Personal Team.

One-time setup:

1. In Xcode › Settings › Accounts, click **+**, choose **Apple ID** and sign in. A personal Apple ID works; a company-managed one may not.
2. Open the project: `open iOS/QRnesto.xcodeproj`.
3. Select the **QRnesto-iOS** target › **Signing & Capabilities**, and set **Team** to *Your Name (Personal Team)*. Leave **Automatically manage signing** on. If Xcode says the bundle ID is unavailable, change it to something unique, such as `com.douernesto.qrnesto.dev`.
4. Connect the iPhone with a cable, unlock it, and tap **Trust This Computer**.
5. On the iPhone, turn on **Settings › Privacy & Security › Developer Mode** and restart. The option appears after the phone has been connected to Xcode once.

Run it:

1. Run `make ios-device`, or pick your iPhone as the run destination in the Xcode toolbar and press **⌘R**. `make ios-device` reads your team ID from your Apple Development certificate, so you can skip step 3 of the setup.
2. The first launch is blocked as an untrusted developer. On the iPhone, go to **Settings › General › VPN & Device Management**, tap your Apple ID and choose **Trust**.
3. Run again and allow camera access when asked.

After the first cable connection you can usually run over Wi-Fi, with the phone and Mac on the same network.

Limits of a free account:

- The app stops opening after 7 days. Run `make ios-device` (or press **⌘R**) again to reinstall it; your settings are kept.
- At most 3 of your own apps can be installed per device.
- No TestFlight and no App Store. Sharing the app with others or publishing it needs the paid program.

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
| `make ios-sim` | Build the iOS app and launch it in the iOS Simulator (`SIM="iPhone 17"` picks the device) |
| `make ios-device` | Build, install and launch the iOS app on a connected iPhone (`TEAM=`, `DEVICE=`, `BUNDLE_ID=` override the defaults) |
| `make ios-open` | Open the iOS project in Xcode |
| `make ios-help` | Print the steps for running on your iPhone with a free Apple ID |
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

On iOS only the camera needs permission (Settings › Privacy & Security › Camera). Photos are picked with the system picker, which needs no permission.

macOS asks the first time you use each feature. The app only sees the camera or screen while you use that feature. Rebuilding the app changes its signature, so macOS may ask again after a rebuild.

## Project layout

```
Package.swift                 Swift package: QRCore library + QRnesto app
scripts/build_app.sh          Wraps the binary into QRnesto.app with an Info.plist and icon, and signs it
scripts/check_env.sh          Checks that this Mac can build the app (make check)
scripts/run_ios_sim.sh        Builds the iOS app and launches it in the iOS Simulator (make ios-sim)
Makefile                      Developer commands
Resources/AppIcon.png         1024x1024 app icon, converted to .icns at build time
Sources/
  QRCore/
    QRDecoder.swift           Finds QR codes and barcodes in images and camera frames (Vision)
    PayloadParser.swift       Turns a raw payload into labelled fields
  QRnesto/
    QRnestoApp.swift         App entry point and menu commands
    ScannerModel.swift        State: image, results, camera, screen capture
    SettingsView.swift        Settings window (camera auto-stop timeout)
    CameraScanner.swift       AVFoundation camera session and preview
    ContentView.swift         SwiftUI window
iOS/
  QRnesto.xcodeproj           Xcode project for the iOS app; depends on QRCore from the local package
  QRnesto/                    iOS app sources (SwiftUI + UIKit), same structure as Sources/QRnesto
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

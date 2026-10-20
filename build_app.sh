#!/bin/zsh
# Builds "QRnesto.app" into ./build using only the Swift toolchain (no Xcode needed).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/QRnesto"

APP="build/QRnesto.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/QRnesto"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>QRnesto</string>
  <key>CFBundleDisplayName</key><string>QRnesto</string>
  <key>CFBundleIdentifier</key><string>com.ppro.qrnesto</string>
  <key>CFBundleExecutable</key><string>QRnesto</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSCameraUsageDescription</key><string>QRnesto uses the camera to scan QR codes live.</string>
</dict></plist>
PLIST

codesign --force --sign - "$APP"
echo "Built: $APP"

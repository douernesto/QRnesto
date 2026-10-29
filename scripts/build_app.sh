#!/bin/zsh
# Builds "QRnesto.app" into ./build using only the Swift toolchain (no Xcode needed).
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/check_env.sh

# Native build by default (works on Intel and Apple Silicon). UNIVERSAL=1 builds arm64 + x86_64 and merges them with lipo.
if [[ "${UNIVERSAL:-0}" == 1 ]]; then
  mkdir -p build
  BIN="build/QRnesto-universal"
  slices=()
  for arch in arm64 x86_64; do
    swift build -c release --triple "$arch-apple-macosx13.0"
    slices+=("$(swift build -c release --triple "$arch-apple-macosx13.0" --show-bin-path)/QRnesto")
  done
  lipo -create -output "$BIN" "${slices[@]}"
else
  swift build -c release
  BIN="$(swift build -c release --show-bin-path)/QRnesto"
fi

APP="build/QRnesto.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/QRnesto"

ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET" "$APP/Contents/Resources"
for size in 16 32 128 256 512; do
  sips -z $size $size Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>QRnesto</string>
  <key>CFBundleDisplayName</key><string>QRnesto</string>
  <key>CFBundleIdentifier</key><string>com.douernesto.qrnesto</string>
  <key>CFBundleExecutable</key><string>QRnesto</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 douernesto. MIT License.</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSCameraUsageDescription</key><string>QRnesto uses the camera to scan QR codes live.</string>
</dict></plist>
PLIST

codesign --force --sign - "$APP"
echo "Built: $APP"

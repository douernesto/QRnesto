#!/bin/zsh
# Builds the iOS app and launches it in the iOS Simulator. SIM="iPhone 17" picks the device.
set -euo pipefail
cd "$(dirname "$0")/.."

# Use full Xcode even when xcode-select points at the Command Line Tools.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SIM="${SIM:-iPhone 17}"
DD="build/ios"

xcodebuild -project iOS/QRnesto.xcodeproj -scheme QRnesto-iOS -configuration Debug \
  -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath "$DD" -quiet build

xcrun simctl boot "$SIM" 2>/dev/null || true
# Xcode 27 shows simulators in DeviceHub; older versions ship Simulator.app.
for app in "$DEVELOPER_DIR/Applications/Simulator.app" "$DEVELOPER_DIR/../Applications/DeviceHub.app"; do
  [[ -d "$app" ]] && { open "$app"; break; }
done
xcrun simctl install "$SIM" "$DD/Build/Products/Debug-iphonesimulator/QRnesto.app"
xcrun simctl launch "$SIM" com.douernesto.qrnesto

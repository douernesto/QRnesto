#!/bin/zsh
# Builds the iOS app, installs it on a connected iPhone and launches it.
# TEAM=<team ID> overrides the team read from your Apple Development certificate.
# DEVICE=<name or UDID> picks a device when more than one is connected.
set -euo pipefail
cd "$(dirname "$0")/.."

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DD="build/ios"
BUNDLE_ID="${BUNDLE_ID:-com.douernesto.qrnesto}"

TEAM="${TEAM:-$(security find-certificate -c "Apple Development" -p 2>/dev/null \
  | openssl x509 -noout -subject 2>/dev/null | sed -nE 's/.*OU ?= ?([A-Z0-9]{10}).*/\1/p')}"
if [[ -z "$TEAM" ]]; then
  echo "No Apple Development certificate found. Sign in to Xcode › Settings › Accounts first (see make ios-help)."
  exit 1
fi

if [[ -z "${DEVICE:-}" ]]; then
  json="$(mktemp)"
  xcrun devicectl list devices --json-output "$json" >/dev/null
  DEVICE="$(python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))["result"]["devices"]
p=[x["hardwareProperties"]["udid"] for x in d if x["hardwareProperties"].get("reality")=="physical" and x["hardwareProperties"].get("platform")=="iOS"]
print(p[0] if p else "")' "$json")"
  rm -f "$json"
fi
if [[ -z "$DEVICE" ]]; then
  echo "No iPhone found. Connect it with a cable, unlock it and tap Trust This Computer (see make ios-help)."
  exit 1
fi

echo "Team $TEAM, device $DEVICE"
xcodebuild -project iOS/QRnesto.xcodeproj -scheme QRnesto-iOS -configuration Debug \
  -destination "generic/platform=iOS" -derivedDataPath "$DD" -allowProvisioningUpdates -quiet \
  DEVELOPMENT_TEAM="$TEAM" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" build

xcrun devicectl device install app --device "$DEVICE" "$DD/Build/Products/Debug-iphoneos/QRnesto.app"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID" \
  || echo "Installed, but could not launch. If the iPhone says Untrusted Developer, trust it in Settings › General › VPN & Device Management."

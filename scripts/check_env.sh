#!/bin/zsh
# Checks that this Mac can build QRnesto. UNIVERSAL=1 also checks the other architecture.
set -uo pipefail

fail=0
ok()   { echo "ok    $1"; }
bad()  { echo "FAIL  $1"; fail=1; }

ver_ge() { [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]; }

host="$(uname -m)"
ok "architecture: $host"

macos="$(sw_vers -productVersion)"
if ver_ge "$macos" 13.0; then ok "macOS $macos (13.0 or later)"; else bad "macOS $macos, need 13.0 or later"; fi

if command -v swift >/dev/null; then
  swiftv="$(swift --version 2>&1 | sed -nE 's/.*Swift version ([0-9]+(\.[0-9]+)*).*/\1/p' | head -1)"
  if ver_ge "${swiftv:-0}" 5.9; then ok "Swift $swiftv (5.9 or later)"; else bad "Swift ${swiftv:-unknown}, need 5.9 or later"; fi
else
  bad "swift not found: run xcode-select --install"
fi

if xcrun --show-sdk-path >/dev/null 2>&1; then ok "macOS SDK: $(xcrun --show-sdk-path)"; else bad "no macOS SDK: run xcode-select --install"; fi

tools=(sips iconutil codesign)
[[ "${UNIVERSAL:-0}" == 1 ]] && tools+=(lipo)
for t in $tools; do
  if command -v $t >/dev/null; then ok "$t found"; else bad "$t not found"; fi
done

if [[ "${UNIVERSAL:-0}" == 1 && $fail == 0 ]]; then
  other=x86_64; [[ "$host" == x86_64 ]] && other=arm64
  tmp="$(mktemp -d)"
  echo 'print("ok")' > "$tmp/main.swift"
  if swiftc -target "$other-apple-macosx13.0" -o "$tmp/probe" "$tmp/main.swift" >/dev/null 2>&1; then
    ok "can build for $other"
  else
    bad "cannot build for $other: update the Command Line Tools or use make app for a native build"
  fi
  rm -rf "$tmp"
fi

exit $fail

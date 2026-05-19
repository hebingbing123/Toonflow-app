#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

macos_app="${ROOT_DIR}/frontend/build/macos/Build/Products/Release/openflow_app.app"
linux_bundle="${ROOT_DIR}/frontend/build/linux/x64/release/bundle"
windows_bundle="${ROOT_DIR}/frontend/build/windows/x64/runner/Release"

checked=0

check_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing file: $path" >&2
    exit 1
  fi
}

check_dir() {
  local path="$1"
  if [[ ! -d "$path" ]]; then
    echo "missing directory: $path" >&2
    exit 1
  fi
}

if [[ -d "$macos_app" ]]; then
  echo "verifying macOS desktop bundle"
  check_file "${macos_app}/Contents/MacOS/openflow_app"
  check_file "${macos_app}/Contents/Frameworks/libopenflow_core_bridge.dylib"
  otool -D "${macos_app}/Contents/Frameworks/libopenflow_core_bridge.dylib" |
    grep -F "@rpath/libopenflow_core_bridge.dylib" >/dev/null
  codesign --verify --deep --strict "$macos_app"
  checked=$((checked + 1))
fi

if [[ -d "$linux_bundle" ]]; then
  echo "verifying Linux desktop bundle"
  check_file "${linux_bundle}/openflow_app"
  check_dir "${linux_bundle}/lib"
  check_file "${linux_bundle}/lib/libopenflow_core_bridge.so"
  checked=$((checked + 1))
fi

if [[ -d "$windows_bundle" ]]; then
  echo "verifying Windows desktop bundle"
  check_file "${windows_bundle}/openflow_app.exe"
  check_file "${windows_bundle}/openflow_core_bridge.dll"
  checked=$((checked + 1))
fi

if [[ "$checked" -eq 0 ]]; then
  echo "no desktop build artifacts found to verify" >&2
  exit 1
fi

echo "desktop bridge artifacts verified for ${checked} platform(s)"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW_SCREENSHOT_DIR="$ROOT_DIR/docs/screenshots"
DERIVED_DATA_DIR="${TMPDIR:-/tmp}/SilenceTheLAN-AppStoreScreenshots"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/Debug-iphonesimulator/SilenceTheLAN.app"
BUNDLE_ID="com.shrisha.stl"
DEVICE_NAME="${DEVICE_NAME:-iPhone 16 Pro Max}"
SCENARIOS=(
  "welcome"
  "discovery"
  "login"
  "dashboard"
  "extension"
  "settings"
)

find_device_udid() {
  xcrun simctl list devices available |
    rg -m1 "$DEVICE_NAME \\(" |
    sed -E 's/.*\(([0-9A-F-]+)\) \(.*/\1/'
}

udid="$(find_device_udid)"
if [[ -z "$udid" ]]; then
  echo "Unable to find simulator device named: $DEVICE_NAME" >&2
  exit 1
fi

mkdir -p "$RAW_SCREENSHOT_DIR"
rm -f "$RAW_SCREENSHOT_DIR"/*.png

echo "-> Building screenshot app for simulator..."
xcodebuild \
  -project "$ROOT_DIR/SilenceTheLAN.xcodeproj" \
  -scheme SilenceTheLAN \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build >/dev/null

echo "-> Booting simulator: $DEVICE_NAME ($udid)"
xcrun simctl boot "$udid" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$udid" -b

echo "-> Installing app..."
xcrun simctl install "$udid" "$APP_PATH"

echo "-> Applying consistent status bar override..."
xcrun simctl status_bar "$udid" override \
  --time 10:16 \
  --batteryState charged \
  --batteryLevel 100 \
  --wifiBars 3 \
  --cellularMode active \
  --cellularBars 4

for scenario in "${SCENARIOS[@]}"; do
  out_file="$RAW_SCREENSHOT_DIR/$scenario.png"
  echo "-> Capturing $scenario"
  xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$udid" "$BUNDLE_ID" -marketing-screenshot "$scenario" >/dev/null
  sleep 2
  xcrun simctl io "$udid" screenshot "$out_file" >/dev/null
done

echo "-> Clearing status bar override..."
xcrun simctl status_bar "$udid" clear

echo "-> Raw screenshots saved to: $RAW_SCREENSHOT_DIR"

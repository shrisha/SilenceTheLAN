#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON_ASSET_DIR="$ROOT_DIR/SilenceTheLAN/Assets.xcassets/AppIcon.appiconset"
RAW_SCREENSHOT_DIR="$ROOT_DIR/docs/screenshots"
OUT_DIR="$ROOT_DIR/docs/app-store"
ICON_OUT_DIR="$OUT_DIR/icons"
SHOT_69_OUT_DIR="$OUT_DIR/screenshots/iphone-6.9"
SHOT_65_OUT_DIR="$OUT_DIR/screenshots/iphone-6.5"
SWIFT_CACHE_DIR="${TMPDIR:-/tmp}/silencethelan-swift-module-cache"

SCREENSHOT_NAMES=(
  "welcome"
  "discovery"
  "login"
  "dashboard"
  "extension"
  "settings"
)

echo "-> Generating quiet-signal app icons..."
mkdir -p "$SWIFT_CACHE_DIR"
SWIFT_MODULECACHE_PATH="$SWIFT_CACHE_DIR" CLANG_MODULE_CACHE_PATH="$SWIFT_CACHE_DIR" \
  swift -module-cache-path "$SWIFT_CACHE_DIR" "$ROOT_DIR/Scripts/GenerateAppIcons.swift"

echo "-> Preparing App Store output directories..."
mkdir -p "$ICON_OUT_DIR" "$SHOT_69_OUT_DIR" "$SHOT_65_OUT_DIR"
rm -f "$ICON_OUT_DIR"/*.png "$SHOT_69_OUT_DIR"/*.png "$SHOT_65_OUT_DIR"/*.png

echo "-> Exporting icon variants..."
cp "$ICON_ASSET_DIR/AppIcon.png" "$ICON_OUT_DIR/AppIcon-1024.png"
cp "$ICON_ASSET_DIR/AppIcon-Dark.png" "$ICON_OUT_DIR/AppIcon-Dark-1024.png"
cp "$ICON_ASSET_DIR/AppIcon-Tinted.png" "$ICON_OUT_DIR/AppIcon-Tinted-1024.png"

echo "-> Exporting screenshots..."
for i in "${!SCREENSHOT_NAMES[@]}"; do
  name="${SCREENSHOT_NAMES[$i]}"
  input="$RAW_SCREENSHOT_DIR/$name.png"
  index="$(printf "%02d" "$((i + 1))")"

  if [[ ! -f "$input" ]]; then
    echo "Missing screenshot: $input" >&2
    exit 1
  fi

  # 6.9-inch iPhone screenshot: 1320x2868
  sips -z 2868 1320 "$input" --out "$SHOT_69_OUT_DIR/${index}-${name}.png" >/dev/null

  # 6.5-inch iPhone screenshot: 1284x2778
  sips -z 2778 1284 "$input" --out "$SHOT_65_OUT_DIR/${index}-${name}.png" >/dev/null
done

echo "-> App Store asset pack ready in: $OUT_DIR"

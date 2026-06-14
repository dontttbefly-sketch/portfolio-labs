#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/ImportToPhotos.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
CACHE_DIR="$SCRIPT_DIR/.build/module-cache"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$CACHE_DIR"
cp "$SCRIPT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
if [[ -f "$SCRIPT_DIR/DefaultImportFolder.txt" ]]; then
  cp "$SCRIPT_DIR/DefaultImportFolder.txt" "$RESOURCES_DIR/DefaultImportFolder.txt"
fi

export CLANG_MODULE_CACHE_PATH="$CACHE_DIR"
export SWIFT_MODULE_CACHE_PATH="$CACHE_DIR"

if [[ ! -f "$SCRIPT_DIR/ImportToPhotos.icns" || "$SCRIPT_DIR/make_icon.swift" -nt "$SCRIPT_DIR/ImportToPhotos.icns" ]]; then
  swiftc \
    -framework AppKit \
    -framework CoreGraphics \
    -framework ImageIO \
    -framework UniformTypeIdentifiers \
    "$SCRIPT_DIR/make_icon.swift" \
    -o "$SCRIPT_DIR/.build/make_icon"
  "$SCRIPT_DIR/.build/make_icon" "$SCRIPT_DIR"
fi

cp "$SCRIPT_DIR/ImportToPhotos.icns" "$RESOURCES_DIR/ImportToPhotos.icns"

swiftc -O \
  -framework AppKit \
  -framework Foundation \
  -framework Photos \
  -framework UniformTypeIdentifiers \
  "$SCRIPT_DIR/ImportToPhotos.swift" \
  -o "$MACOS_DIR/ImportToPhotos"

chmod +x "$MACOS_DIR/ImportToPhotos"

echo "Built $APP_DIR"

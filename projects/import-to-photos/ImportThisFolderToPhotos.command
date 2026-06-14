#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$SCRIPT_DIR/ImportToPhotos/ImportToPhotos.app"

if [[ ! -x "$APP/Contents/MacOS/ImportToPhotos" ]]; then
  echo "ImportToPhotos.app was not built yet. Building it now..."
  "$SCRIPT_DIR/ImportToPhotos/build.sh"
fi

open "$APP" --args "$SCRIPT_DIR"

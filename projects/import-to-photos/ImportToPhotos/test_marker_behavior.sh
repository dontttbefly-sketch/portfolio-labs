#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="$SCRIPT_DIR/ImportToPhotos.app/Contents/MacOS/ImportToPhotos"
MARKER_NAME="local.import-to-photos.uploaded"
MARKER_VALUE='{"version":1,"importedAt":"2026-05-15T00:00:00Z","appIdentifier":"local.import-to-photos"}'

if [[ ! -x "$BINARY" ]]; then
  echo "Missing binary: $BINARY" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

base64 -D > "$TMP_DIR/source.png" <<'PNG'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=
PNG

cp "$TMP_DIR/source.png" "$TMP_DIR/unmarked.png"
cp "$TMP_DIR/source.png" "$TMP_DIR/marked.png"
rm "$TMP_DIR/source.png"
xattr -w "$MARKER_NAME" "$MARKER_VALUE" "$TMP_DIR/marked.png"

OUTPUT="$("$BINARY" --dry-run "$TMP_DIR")"

grep -q "New images: 1" <<< "$OUTPUT"
grep -q "Skipped marked images: 1" <<< "$OUTPUT"
grep -q "NEW .*unmarked.png" <<< "$OUTPUT"
grep -q "SKIPPED .*marked.png" <<< "$OUTPUT"

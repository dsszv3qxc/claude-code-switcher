#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Claude Code Switcher"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
ZIP_PATH="$ROOT_DIR/dist/Claude-Code-Switcher-macOS.zip"
SHA_PATH="$ZIP_PATH.sha256"

"$ROOT_DIR/script/build_and_run.sh" --verify

rm -f "$ZIP_PATH" "$SHA_PATH"
ditto -c -k --norsrc --noextattr --keepParent "$APP_BUNDLE" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" > "$SHA_PATH"

echo "Created:"
echo "  $ZIP_PATH"
echo "  $SHA_PATH"

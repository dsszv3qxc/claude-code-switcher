#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Claude Code Switcher"
BUNDLE_ID="com.liuhuan.claudecodeswitcher"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.icns"
INSTALLED_APP="/Applications/$APP_NAME.app"

kill_running() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

stage_bundle() {
  swift build -c release --product "$APP_NAME"
  BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"
  cp "$BUILD_BINARY" "$APP_BINARY"
  chmod +x "$APP_BINARY"
  if [[ -f "$APP_ICON_SOURCE" ]]; then
    cp "$APP_ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
  fi
  if [[ -d "$ROOT_DIR/Sources/ClaudeCodeSwitcherApp/Resources" ]]; then
    find "$ROOT_DIR/Sources/ClaudeCodeSwitcherApp/Resources" -maxdepth 1 -name "*.lproj" -type d | while read -r LPROJ; do
      cp -R "$LPROJ" "$APP_RESOURCES/"
    done
  fi

  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>Claude Code 切换器</string>
  <key>CFBundleDisplayName</key>
  <string>Claude Code 切换器</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.4</string>
  <key>CFBundleVersion</key>
  <string>5</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

  /usr/bin/codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true
}

open_local_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

install_app() {
  rm -rf "$INSTALLED_APP"
  cp -R "$APP_BUNDLE" "$INSTALLED_APP"
  /usr/bin/codesign --force --deep --sign - "$INSTALLED_APP" >/dev/null 2>&1 || true
}

case "$MODE" in
  run|--run)
    kill_running
    stage_bundle
    open_local_app
    ;;
  install|--install)
    kill_running
    stage_bundle
    install_app
    /usr/bin/open -n "$INSTALLED_APP"
    ;;
  --debug|debug)
    kill_running
    stage_bundle
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    kill_running
    stage_bundle
    open_local_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    kill_running
    stage_bundle
    open_local_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    kill_running
    stage_bundle
    open_local_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --verify-installed|verify-installed)
    test -d "$INSTALLED_APP"
    /usr/bin/open -n "$INSTALLED_APP"
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|install|--debug|--logs|--telemetry|--verify|--verify-installed]" >&2
    exit 2
    ;;
esac

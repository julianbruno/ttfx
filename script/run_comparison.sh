#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TTFXComparisonApp"
MODE="${1:-run}"
case "$MODE" in run|--verify|--build) ;; *) echo "usage: $0 [run|--verify|--build]" >&2; exit 2;; esac
cd "$ROOT_DIR"
if [ "$MODE" != --build ]; then pkill -x "$APP_NAME" >/dev/null 2>&1 || true; fi
swift build --product "$APP_NAME"
BIN_DIR="$(swift build --show-bin-path)"
APP_BUNDLE="$ROOT_DIR/.build/apps/$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$BIN_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>dev.ttfx.comparison</string>
<key>CFBundleName</key><string>TTFX Video Comparison</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
if [ "$MODE" = --build ]; then exit 0; fi
/usr/bin/open -n "$APP_BUNDLE" --args --library "$ROOT_DIR/artifacts/video-comparison"
if [ "$MODE" = --verify ]; then sleep 1; pgrep -x "$APP_NAME" >/dev/null; fi

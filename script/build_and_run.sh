#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "--compare" ]; then
  shift
  exec "$(dirname "$0")/run_comparison.sh" "$@"
fi
MODE="${1:-run}"
case "$MODE" in
  run|--debug|--logs|--telemetry|--verify) ;;
  *) echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TTFXGalleryApp"
BUILD_DIR="$ROOT_DIR/.build/xcode"
APP_BUNDLE="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
xcodebuild -project "$ROOT_DIR/TTFXGalleryApp.xcodeproj" -scheme "$APP_NAME" -destination 'platform=macOS' -configuration Debug -derivedDataPath "$BUILD_DIR" build
case "$MODE" in
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs|--telemetry)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate 'process == "TTFXGalleryApp"'
    ;;
  --verify)
    /usr/bin/open -n "$APP_BUNDLE"
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
esac

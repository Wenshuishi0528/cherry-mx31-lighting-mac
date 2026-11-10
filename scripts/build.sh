#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/dist/键盘灯控.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$PROJECT_DIR/build"
swiftc -O -swift-version 5 -target arm64-apple-macos14.0 \
  "$PROJECT_DIR"/Sources/*.swift \
  -framework SwiftUI -framework AppKit -framework IOKit \
  -o "$APP_DIR/Contents/MacOS/KeyboardLights"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/THIRD_PARTY_NOTICES.txt" "$APP_DIR/Contents/Resources/"
cp "$PROJECT_DIR/LICENSE" "$APP_DIR/Contents/Resources/LICENSE.txt"
cp "$PROJECT_DIR/COPYRIGHT" "$APP_DIR/Contents/Resources/COPYRIGHT.txt"
if [[ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]]; then
  cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
fi
codesign --force --sign - "$APP_DIR"
codesign --verify --strict "$APP_DIR"
print "Built: $APP_DIR"

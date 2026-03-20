#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/dist/ShearingPlate.app"
EXECUTABLE_PATH="$BUILD_DIR/ShearingPlate"
ICON_PATH="$ROOT_DIR/Assets/AppIcon.icns"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

cd "$ROOT_DIR"
./Scripts/generate-app-icon.sh
swift build -c release --product ShearingPlate

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/ShearingPlate"
cp "$ROOT_DIR/Config/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ICON_PATH" "$APP_DIR/Contents/Resources/AppIcon.icns"

chmod +x "$APP_DIR/Contents/MacOS/ShearingPlate"
codesign --force --deep --sign - "$APP_DIR"

echo "Packaged app: $APP_DIR"

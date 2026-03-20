#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/ShearingPlate.app"
PACKAGE_DIR="$DIST_DIR/ShearingPlate-test-package"
ZIP_PATH="$DIST_DIR/ShearingPlate-test-package.zip"
GUIDE_SOURCE="$ROOT_DIR/Docs/TESTER-INSTALL.md"
GUIDE_DESTINATION="$PACKAGE_DIR/README-Install.md"

cd "$ROOT_DIR"
./Scripts/package-app.sh

rm -rf "$PACKAGE_DIR"
rm -f "$ZIP_PATH"
mkdir -p "$PACKAGE_DIR"

ditto "$APP_DIR" "$PACKAGE_DIR/ShearingPlate.app"
cp "$GUIDE_SOURCE" "$GUIDE_DESTINATION"

ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_DIR" "$ZIP_PATH"

echo "Packaged test zip: $ZIP_PATH"
echo "Included guide: $GUIDE_DESTINATION"

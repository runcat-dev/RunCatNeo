#!/usr/bin/env bash
#
# Builds this working copy of RunCat Neo and installs it to /Applications next to the
# App Store build, so the daily step counter can be tried without replacing the original app.
#
# Usage: Scripts/build-local.sh [--no-install]
#
set -euo pipefail

APP_DISPLAY_NAME="RunCat Neo (Steps)"
BUNDLE_ID="com.kyome.Neo.RunCat.local"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/local"
BUILT_APP="$DERIVED_DATA_DIR/Build/Products/Release/RunCatNeo.app"
INSTALL_PATH="/Applications/$APP_DISPLAY_NAME.app"

if ! xcodebuild -version >/dev/null 2>&1 && [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

if ! xcodebuild -version >/dev/null 2>&1; then
    echo "error: Xcode 26.x is required (xcodebuild is not available)." >&2
    echo "       Install Xcode from the App Store, then run 'sudo xcode-select -s /Applications/Xcode.app'." >&2
    exit 1
fi

cd "$ROOT_DIR"

echo "==> Building $APP_DISPLAY_NAME"
xcodebuild \
    -project RunCatNeo.xcodeproj \
    -scheme RunCatNeo \
    -configuration Release \
    -destination "platform=macOS,arch=arm64" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    -skipPackagePluginValidation \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    build

if [[ ! -d "$BUILT_APP" ]]; then
    echo "error: the build did not produce $BUILT_APP" >&2
    exit 1
fi

# The bundle identifier is rewritten after the build on purpose. Overriding PRODUCT_BUNDLE_IDENTIFIER
# on the xcodebuild command line also rewrites the identifier of the embedded Swift package resource
# bundle, and the duplicated identifier makes NSImage(resource:) fail to find the runner frames.
echo "==> Stamping bundle identifier $BUNDLE_ID"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$BUILT_APP/Contents/Info.plist"
if /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_DISPLAY_NAME" "$BUILT_APP/Contents/Info.plist" 2>/dev/null; then
    :
else
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $APP_DISPLAY_NAME" "$BUILT_APP/Contents/Info.plist"
fi
codesign --force --sign - --preserve-metadata=entitlements "$BUILT_APP"
codesign --verify --strict "$BUILT_APP"

if [[ "${1:-}" == "--no-install" ]]; then
    echo "==> Built $BUILT_APP (install skipped)"
    exit 0
fi

case "$INSTALL_PATH" in
    "/Applications/$APP_DISPLAY_NAME.app") ;;
    *) echo "error: refusing to write to unexpected path: $INSTALL_PATH" >&2; exit 1 ;;
esac

echo "==> Installing to $INSTALL_PATH"
rm -rf "$INSTALL_PATH"
ditto "$BUILT_APP" "$INSTALL_PATH"
codesign --verify --strict "$INSTALL_PATH"

echo "==> Installed $INSTALL_PATH"
echo "    Launch it with: open \"$INSTALL_PATH\""

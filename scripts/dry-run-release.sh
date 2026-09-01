#!/usr/bin/env bash
# Dry-run release build, signing, and verification script.
# This validates the manual release path without Apple Developer credentials.
set -euo pipefail

APP_NAME="Cue"
PROJECT="Cue.xcodeproj"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/Cue.xcarchive"
APP_PATH="$BUILD_DIR/Cue.app"

if [[ -t 1 ]]; then
  BLUE=$'\033[0;34m'
  GREEN=$'\033[0;32m'
  RED=$'\033[0;31m'
  YELLOW=$'\033[0;33m'
  BOLD=$'\033[1m'
  NC=$'\033[0m'
else
  BLUE=""
  GREEN=""
  RED=""
  YELLOW=""
  BOLD=""
  NC=""
fi

info() { printf "%sinfo:%s %s\n" "$BLUE$BOLD" "$NC" "$1"; }
success() { printf "%ssuccess:%s %s\n" "$GREEN$BOLD" "$NC" "$1"; }
warn() { printf "%swarning:%s %s\n" "$YELLOW$BOLD" "$NC" "$1"; }
fail() { printf "%serror:%s %s\n" "$RED$BOLD" "$NC" "$1" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "This script only runs on macOS."
command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild is required."
command -v codesign >/dev/null 2>&1 || fail "codesign is required."

info "Cleaning previous build output..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

info "Archiving $APP_NAME without signing..."
xcodebuild -project "$PROJECT" \
  -scheme "$APP_NAME" \
  -configuration Release \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  archive -archivePath "$ARCHIVE_PATH" \
  > /dev/null || fail "xcodebuild archive failed."
success "Archive created at $ARCHIVE_PATH"

info "Extracting app bundle from archive..."
[[ -d "$ARCHIVE_PATH/Products/Applications/Cue.app" ]] ||
  fail "Archive does not contain Cue.app at the expected path."
ditto "$ARCHIVE_PATH/Products/Applications/Cue.app" "$APP_PATH"

info "Signing the app ad hoc for local verification..."
SIGN_IDENTITY="-"
TIMESTAMP_FLAG="--timestamp=none"
xattr -rc "$APP_PATH"

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Contents/Info.plist")
PROCESSED_ENTITLEMENTS="$BUILD_DIR/processed-entitlements-dryrun.plist"
sed "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/$BUNDLE_ID/g" Cue/Cue.entitlements > "$PROCESSED_ENTITLEMENTS"

codesign --force --sign "$SIGN_IDENTITY" \
  -o runtime \
  --entitlements "$PROCESSED_ENTITLEMENTS" \
  $TIMESTAMP_FLAG \
  "$APP_PATH"
success "App bundle signed successfully"

codesign --verify --deep --strict --verbose=4 "$APP_PATH"
HR_FLAGS=$(codesign -dvvv "$APP_PATH" 2>&1 | grep "flags=" || true)
echo "$HR_FLAGS" | grep -q "runtime" || fail "Hardened runtime flag not found."
success "Hardened runtime verified: $HR_FLAGS"

if command -v create-dmg >/dev/null 2>&1; then
  info "Generating preview DMG..."
  create-dmg \
    --volname "Cue" \
    --background "assets/dmg-background.png" \
    --window-size 660 400 \
    --icon-size 120 \
    --icon "Cue.app" 180 170 \
    --app-drop-link 480 170 \
    --no-internet-enable \
    "$BUILD_DIR/Cue-dryrun.dmg" \
    "$APP_PATH"
else
  warn "create-dmg is not installed; skipping DMG preview."
fi

success "Dry-run release and signing validation complete."

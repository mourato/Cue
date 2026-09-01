#!/usr/bin/env bash
# Script to test the DMG layout and background alignment without building the entire Xcode app.
set -euo pipefail

# Check if create-dmg is installed
if ! command -v create-dmg >/dev/null 2>&1; then
  echo "Error: 'create-dmg' is not installed."
  echo "Install it using: brew install create-dmg"
  exit 1
fi

echo "Creating temporary build workspace with a valid dummy App bundle..."
TEMP_DIR="temp-dmg-test"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR/Cue.app/Contents/MacOS"

# Create dummy executable and Info.plist so Finder parses it as a single valid App
echo '#!/bin/bash' > "$TEMP_DIR/Cue.app/Contents/MacOS/Notinhas"
chmod +x "$TEMP_DIR/Cue.app/Contents/MacOS/Notinhas"

cat > "$TEMP_DIR/Cue.app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Notinhas</string>
    <key>CFBundleIdentifier</key>
    <string>com.mourato.cue.test-layout</string>
    <key>CFBundleName</key>
    <string>Notinhas</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
</dict>
</plist>
EOF

# Create build output directory if not exists
mkdir -p build
rm -f build/Cue-layout-test.dmg

echo "Generating test DMG with create-dmg..."
create-dmg \
  --volname "Cue Test Layout" \
  --background "assets/dmg-background.png" \
  --window-size 660 400 \
  --icon-size 120 \
  --icon "Cue.app" 180 170 \
  --app-drop-link 480 170 \
  --no-internet-enable \
  "build/Cue-layout-test.dmg" \
  "$TEMP_DIR/Cue.app"

echo "Cleaning up temporary workspace..."
rm -rf "$TEMP_DIR"

echo "--------------------------------------------------------"
echo "Success! Test DMG created at: build/Cue-layout-test.dmg"
echo "You can double-click this file in Finder to verify the background and icon alignment."
echo "--------------------------------------------------------"

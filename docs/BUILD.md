# Manual Build Guide

Build Cue from source on your local machine.

> For first-time setup and a basic debug run, start with [DEVELOPMENT.md](DEVELOPMENT.md).

## Prerequisites

- macOS 26.0+
- Xcode 15.0+
- Command Line Tools: `xcode-select --install`

## Quick Build (Xcode)

```bash
open Cue.xcodeproj
```

Press ⌘R to build and run (**Cue** scheme).

## Regenerate App Icon Assets

Cue ships a **full-bleed** app icon (the PNG already includes its blue/purple
gradient). Prefer regenerating from that finished artwork:

```bash
brew install imagemagick   # if magick is missing
scripts/generate-app-icon-assets.sh \
  --source-png Cue/CueIcon.icon/Assets/CueIcon.png \
  --full-bleed
```

After editing `Cue/CueIcon.icon` in Icon Composer (padded/glass style):

```bash
scripts/generate-app-icon-assets.sh
```

## Command Line Build

### Development Build

```bash
xcodebuild -project Cue.xcodeproj -scheme Cue -configuration Debug build
```

### Release Build (Unsigned)

```bash
xcodebuild -project Cue.xcodeproj \
  -scheme Cue \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### Release Archive (Signed)

Requires Apple Developer account.

```bash
xcodebuild -project Cue.xcodeproj \
  -scheme Cue \
  -configuration Release \
  archive -archivePath Cue.xcarchive
```

### Create DMG

```bash
create-dmg \
  --volname "Cue" \
  --background "assets/dmg-background.png" \
  --window-size 660 400 \
  --icon-size 120 \
  --icon "Cue.app" 180 170 \
  --app-drop-link 480 170 \
  --no-internet-enable \
  "Cue.dmg" \
  "./exported_app/Cue.app"
```

## Build Locations

| Build Type | Location |
|------------|----------|
| Debug (script) | `.build/xcode-derived-data/Build/Products/Debug/Cue Debug.app` |
| Release (script) | `.build/xcode-derived-data/Build/Products/Release/Cue.app` |
| Archive | `./Cue.xcarchive` |

## Troubleshooting

### Code Signing Issues

For local testing without signing:

```bash
xcodebuild ... CODE_SIGNING_ALLOWED=NO build
```

### Clean Build

```bash
xcodebuild -project Cue.xcodeproj -scheme Cue clean
rm -rf ~/Library/Developer/Xcode/DerivedData/Cue-*
```

## Bundle verification

After Release build:

```bash
APP=".build/xcode-derived-data/Build/Products/Release/Cue.app"
plutil -p "$APP/Contents/Info.plist" | rg 'CFBundleIdentifier|CFBundleName|CFBundleURLSchemes'
find "$APP/Contents/Frameworks" -name 'Sparkle.framework' 2>/dev/null
```

Expect `com.mourato.cue`, `notinhas` URL scheme, and no Sparkle framework.

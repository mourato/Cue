# Cue Release Workflow

Cue ships through **manual GitHub Releases** as `Cue-v<version>.dmg`. There is no Sparkle appcast, EdDSA update signing, or in-app update UI.

## Prerequisites

- macOS build host with Xcode 15+
- Apple Developer **Developer ID** certificate (recommended) or local ad-hoc signing for private builds
- `create-dmg` or the repository `scripts/test-dmg.sh` / release workflow for packaging

## Versioning

- `CFBundleShortVersionString` — marketing version (e.g. `1.0.0`)
- `CFBundleVersion` — monotonic build number for support comparisons

Bump both in `Cue.xcodeproj` before tagging.

## Local release build

```bash
# Unsigned local smoke (CI-style)
xcodebuild -project Cue.xcodeproj -scheme Cue -configuration Release \
  build CODE_SIGNING_ALLOWED=NO

# Signed archive (Developer ID)
xcodebuild -project Cue.xcodeproj -scheme Cue -configuration Release \
  -archivePath build/Cue.xcarchive archive
```

See [BUILD.md](BUILD.md) for Debug builds, icon regeneration, and DMG creation.

## DMG contents

| Asset | Expected |
| --- | --- |
| App bundle | `Cue.app` |
| Bundle ID | `com.mourato.cue` |
| URL scheme | `notinhas` only |
| Frameworks | No `Sparkle.framework` |
| Info.plist | No `SUFeedURL`, `SUPublicEDKey`, or Sparkle keys |

## GitHub Release steps

1. Create tag `vX.Y.Z` on `main`.
2. Run the **Release Publish** workflow (or upload manually).
3. Attach `Cue-vX.Y.Z.dmg` and write release notes (user-facing changes, migration/TCC notes when bundle ID or permissions change).

## User upgrade notes

Include in release notes when relevant:

- Re-grant Screen Recording / Accessibility after install
- Link to [MIGRATION.md](MIGRATION.md) for legacy identity upgrades
- Manual download URL: `https://github.com/mourato/Cue/releases`

## Beta / prerelease

Prereleases may be marked `prerelease: true` on GitHub. Users install the DMG manually; there is no beta channel toggle in the app.

## Troubleshooting

| Issue | Check |
| --- | --- |
| Gatekeeper blocks app | Code signing + notarization; or `xattr -rd com.apple.quarantine` for local ad-hoc builds |
| Permissions missing after upgrade | Expected — TCC is per bundle ID; see MIGRATION.md |
| Wrong app name in menu bar | Confirm the current `Cue.app` replaced any older app bundle in `/Applications` |

## Related

- [BUILD.md](BUILD.md) — local build paths
- [UPDATE_TESTING.md](UPDATE_TESTING.md) — post-build verification
- `.github/workflows/release-publish.yml` — CI packaging (when run)

# Update Testing

Cue does **not** use Sparkle or an in-app update channel. Local Sparkle
harnesses, appcast feeds, and updater-only scripts inherited from the upstream
project are **not applicable**.

## What to validate instead

### Release DMG smoke test

1. Build or download `Cue-v<version>.dmg` from CI or [Releases](https://github.com/mourato/Cue/releases).
2. Mount the DMG and drag `Cue.app` to `/Applications`.
3. Launch — confirm menu bar name **Cue**, no About/Check for Updates/Report UI.
4. Run `plutil -p /Applications/Cue.app/Contents/Info.plist` — expect `CFBundleIdentifier` `com.mourato.cue`, URL scheme `notinhas`, no `SUFeedURL` or Sparkle keys.
5. Confirm `find …/Cue.app/Contents/Frameworks -name 'Sparkle.framework'` returns nothing.

### Upgrade path

1. Install an older Cue DMG (or use a migration fixture with legacy data).
2. Install the newer DMG over `/Applications/Cue.app`.
3. Verify history, preferences, and logs per [MIGRATION.md](MIGRATION.md).
4. Re-grant Screen Recording / Accessibility / Microphone as needed.

### Automation

```bash
./scripts/test-dmg.sh          # DMG layout and bundle checks when available
./scripts/test-tcc-local.sh    # Local TCC persistence diagnostic (isolated by default)
```

`test-tcc-local.sh` installs to `/tmp/test-tcc-notinhas/Applications/Cue.app`
by default, writes stage metadata under `/tmp/test-tcc-notinhas/reports/`, and
requires `--install-path` plus `--allow-system-install` to touch
`/Applications/Cue.app`. Permission results still require manual inspection
in System Settings after each stage.

For maintainer release steps see [RELEASES.md](RELEASES.md).

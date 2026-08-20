# Migrating from Snapzy to Notinhas

Notinhas is a separate macOS app with its own bundle identifier, URL scheme, and on-disk identity. First launch runs a **non-destructive, idempotent** identity migration that copies legacy Snapzy data into Notinhas paths. Direct legacy source files are left in place; the older sandbox-off migration may clean copied sandbox directories after a successful copy.

## What changes

| Item | Legacy (Snapzy) | Notinhas |
| --- | --- | --- |
| App name | Snapzy | Notinhas |
| Release bundle ID | `com.trongduong.snapzy` | `com.mourato.notinhas` |
| Debug bundle ID | `com.trongduong.snapzy.debug` | `com.mourato.notinhas.debug` |
| URL scheme | `snapzy://` | `notinhas://` only |
| Application Support | `~/Library/Application Support/Snapzy/` | `~/Library/Application Support/Notinhas/` |
| Database | `snapzy.db` (+ `-wal`, `-shm`) | `notinhas.db` (+ companions) |
| Logs | `~/Library/Logs/Snapzy/snapzy_*.txt` | `~/Library/Logs/Notinhas/notinhas_*.txt` |
| TOML config | `~/.config/snapzy/config.toml` | `~/.config/notinhas/config.toml` |
| Cloud Keychain service | `com.trongduong.snapzy.cloud` (and older `com.snapzy.cloud`) | `com.mourato.notinhas.cloud` |

## First-launch migration

`NotinhasIdentityMigrationService` runs once per user account when legacy data exists and the marker file is absent:

```text
~/Library/Application Support/Notinhas/.notinhas-identity-migration-completed
```

### Inputs migrated (legacy → destination)

- **Application Support** — captures, annotation session sidecars, temp files, and related folders under legacy `Snapzy/` (including sandbox-off container copies when present).
- **Database** — `snapzy.db`, `snapzy.db-wal`, `snapzy.db-shm` copied/renamed to `notinhas.db` companions when the destination set is missing.
- **UserDefaults / preferences** — keys imported from legacy preference domains (`com.trongduong.snapzy`, `com.trongduong.snapzy.debug`) and sandbox preference plists.
- **Logs** — retained diagnostic files from `~/Library/Logs/Snapzy/` into `~/Library/Logs/Notinhas/`; copied legacy filenames are retained, while new logs use the `notinhas_` prefix.
- **TOML config** — `~/.config/snapzy/` tree is merged into `~/.config/notinhas/` without overwriting existing destination files.
- **Keychain** — ImgBB credentials remain readable through the existing
  migration adapter. BYO cloud credential items are not deleted or rewritten.

### Behavior guarantees

- **Non-destructive identity migration** — direct legacy Snapzy folders and plists remain on disk after a successful identity migration. The separate sandbox-off migration can remove copied sandbox subdirectories after marking completion.
- **Idempotent** — re-running is skipped once the marker file exists; destination files are not overwritten when already present.
- **Start Fresh** — user can skip migration; legacy data is untouched and Notinhas starts with empty destination paths.

Sandbox-off data migration (`SandboxOffDataMigrationService`) may also run for users who previously used non-sandboxed Snapzy builds.

## TCC permissions (mandatory re-grant)

macOS ties Screen Recording, Accessibility, and Microphone grants to the **code signature and bundle identifier**. Notinhas does **not** inherit Snapzy TCC entries.

After installing Notinhas you must:

1. Open **System Settings → Privacy & Security**
2. Re-authorize **Screen Recording** for Notinhas
3. Re-authorize **Accessibility** if you use global shortcuts or Fn bindings
4. Re-authorize **Microphone** if you use the optional Video module with voice

Remove stale Snapzy entries if they confuse the list. Debug builds (`Notinhas Debug.app`, `com.mourato.notinhas.debug`) require separate grants from release installs.

If Finder or another app shows duplicate Notinhas entries under **Open With**, close Notinhas, keep the desired release app at `/Applications/Notinhas.app`, and run `./scripts/clean-launch-services.sh` from the repository. Debug builds no longer claim image files, so new Debug entries will not be added.

```bash
tccutil reset ScreenCapture com.mourato.notinhas
tccutil reset Accessibility com.mourato.notinhas
tccutil reset Microphone com.mourato.notinhas
```

## URL scheme

- **Supported:** `notinhas://capture/area`, `notinhas://open/annotate`, and the full table in [SHORTCUTS.md](SHORTCUTS.md).
- **Ignored:** `snapzy://` links are rejected intentionally; automation must be updated to `notinhas://`.

## Distribution and updates

Notinhas does not include Sparkle, in-app **Check for Updates**, **About**, or **Report a Problem** UI. Install new versions manually from [GitHub Releases](https://github.com/mourato/Notinhas/releases) (`Notinhas-v<version>.dmg`).

## Verification checklist

After migration:

1. Launch Notinhas — menu bar shows **Notinhas**; no About/update/report menu items.
2. Open **Capture History** — prior screenshots/videos appear when migration copied the database and capture files.
3. Open **Preferences** — prior settings imported; TOML path is `~/.config/notinhas/config.toml`.
4. Check `~/Library/Logs/Notinhas/` for new `notinhas_*.txt` diagnostic files.
5. Run `notinhas://capture/area` — capture starts; `snapzy://capture/area` does nothing.
6. Re-grant TCC permissions, then capture → annotate → copy brief.

## Troubleshooting

| Symptom | Action |
| --- | --- |
| Empty history after upgrade | Confirm legacy `~/Library/Application Support/Snapzy/snapzy.db` exists; delete marker file only if you intend to re-run migration and destination DB is absent |
| Permissions still fail | Reset TCC for `com.mourato.notinhas`, quit System Settings, relaunch Notinhas |
| Config not applied | Grant config folder access in Settings → Advanced; confirm `~/.config/notinhas/config.toml` |
| Old cloud settings are present | They are ignored; local sharing and ImgBB remain available |

## Retired BYO cloud settings

Plan 089 retires AWS S3, Cloudflare R2, and Google Drive uploads. Importing an
older configuration tolerates and ignores its `[cloud]` section. Legacy
`cloudURL` and `cloudKey` fields remain migration-only so old local records can
decode, but are not used for new uploads or UI actions.

This migration is non-destructive: Notinhas does not delete remote objects,
Keychain items, or configuration files. Users who need old cloud data must
manage it with the provider directly.

For engineering detail see `Notinhas/Services/Migration/NotinhasIdentityMigrationService.swift` and `NotinhasTests/Services/Migration/`.

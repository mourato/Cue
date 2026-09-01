# Migration: Snapzy, Notinhas, and Cue

Cue is a separate macOS app with its own bundle identifier, URL scheme, and on-disk identity. First launch runs **non-destructive, idempotent** identity migrations that copy legacy Snapzy and Notinhas data into Cue paths. Direct legacy source files are left in place unless a separate sandbox-off migration cleans copied sandbox directories after a successful copy.

## Upgrade paths

| From | Service | Marker file |
| --- | --- | --- |
| Snapzy → Notinhas (historical) | `NotinhasIdentityMigrationService` | `~/Library/Application Support/Notinhas/.notinhas-identity-migration-completed` |
| Notinhas → Cue | `CueIdentityMigrationService` | `~/Library/Application Support/Cue/.cue-identity-migration-completed` |

On a fresh Cue install over an existing Notinhas tree, both chains may run in order: Snapzy readers remain for very old data, Notinhas → Cue runs before database setup.

## Current identity (Cue)

| Item | Value |
| --- | --- |
| App name | Cue / Cue Debug |
| Release bundle ID | `com.mourato.cue` |
| Debug bundle ID | `com.mourato.cue.debug` |
| URL scheme | `cue://` only |
| Application Support | `~/Library/Application Support/Cue/` |
| Database | `cue.db` (+ `-wal`, `-shm`) |
| Logs | `~/Library/Logs/Cue/cue_*.txt` |
| TOML config | `~/.config/cue/config.toml` |
| Cloud Keychain service | `com.mourato.cue.cloud` |

## Legacy sources still read on upgrade

| Item | Legacy (Notinhas) | Legacy (Snapzy) |
| --- | --- | --- |
| Release bundle ID | `com.mourato.notinhas` | `com.trongduong.snapzy` |
| URL scheme | `notinhas://` (**rejected** in Cue) | `snapzy://` (**rejected**) |
| Application Support | `~/Library/Application Support/Notinhas/` | `~/Library/Application Support/Snapzy/` |
| Database | `notinhas.db` | `snapzy.db` |
| Logs | `~/Library/Logs/Notinhas/notinhas_*.txt` | `~/Library/Logs/Snapzy/snapzy_*.txt` |
| TOML config | `~/.config/notinhas/config.toml` | `~/.config/snapzy/config.toml` |

### What CueIdentityMigrationService copies

- **Application Support** — captures, annotation session sidecars, temp files, and related folders under legacy `Notinhas/` (and Snapzy readers when still present).
- **Database** — `notinhas.db` companions copied/renamed to `cue.db` when the destination set is missing.
- **UserDefaults / preferences** — keys imported from `com.mourato.notinhas`, `com.mourato.notinhas.debug`, and older Snapzy domains.
- **Logs** — diagnostic files from `~/Library/Logs/Notinhas/` into `~/Library/Logs/Cue/`; copied legacy filenames are retained; new logs use the `cue_` prefix.
- **TOML config** — `~/.config/notinhas/` merged into `~/.config/cue/` without overwriting existing destination files.
- **Keychain** — legacy cloud credential items remain readable through migration adapters; provider credentials are not exported.

### Behavior guarantees

- **Non-destructive** — legacy Snapzy/Notinhas folders and plists remain on disk after identity migration unless sandbox-off cleanup applies.
- **Idempotent** — re-running is skipped once the Cue marker file exists; destination files are not overwritten when already present.
- **Start Fresh** — user can skip migration; legacy data is untouched and Cue starts with empty destination paths.

Serialized annotation sessions still decode the JSON key `notinhasNotesSession` on read; new writes use Cue session types.

## TCC permissions (mandatory re-grant)

macOS ties Screen Recording, Accessibility, and Microphone grants to the **code signature and bundle identifier**. Cue does **not** inherit Cue or Snapzy TCC entries.

After installing Cue you must:

1. Open **System Settings → Privacy & Security**
2. Re-authorize **Screen Recording** for Cue
3. Re-authorize **Accessibility** if you use global shortcuts or Fn bindings
4. Re-authorize **Microphone** if you use the optional Video module with voice

Remove stale Cue or Snapzy entries if they confuse the list. Debug builds (`Cue Debug.app`, `com.mourato.cue.debug`) require separate grants from release installs.

If Finder shows duplicate entries under **Open With**, close Cue, keep the release app at `/Applications/Cue.app`, and run `./scripts/clean-launch-services.sh`.

```bash
tccutil reset ScreenCapture com.mourato.cue
tccutil reset Accessibility com.mourato.cue
tccutil reset Microphone com.mourato.cue
```

## URL scheme

- **Supported:** `cue://capture/area`, `cue://open/annotate`, and the full table in [SHORTCUTS.md](SHORTCUTS.md).
- **Rejected:** `notinhas://` and `snapzy://` — update Shortcuts, Raycast, and shell scripts to `cue://`.

## Distribution and updates

Cue does not include Sparkle, in-app **Check for Updates**, **About**, or **Report a Problem** UI. Install new versions manually from [GitHub Releases](https://github.com/mourato/Cue/releases) (`Cue-v<version>.dmg`).

## Verification checklist

After upgrading from Notinhas to Cue:

1. Launch Cue — menu bar shows **Cue**; no About/update/report menu items.
2. Open **Capture History** — prior screenshots/videos appear when migration copied the database and capture files.
3. Open **Preferences** — prior settings imported; TOML path is `~/.config/cue/config.toml`.
4. Check `~/Library/Logs/Cue/` for new `cue_*.txt` diagnostic files.
5. Run `cue://capture/area` — capture starts; `notinhas://capture/area` and `snapzy://capture/area` do nothing.
6. Re-grant TCC permissions, then capture → annotate → copy brief.

## Troubleshooting

| Symptom | Action |
| --- | --- |
| Empty history after upgrade | Confirm legacy `~/Library/Application Support/Notinhas/notinhas.db` exists; delete the Cue marker only if you intend to re-run migration and destination DB is absent |
| Permissions still fail | Reset TCC for `com.mourato.cue`, quit System Settings, relaunch Cue |
| Config not applied | Grant config folder access in Settings → Advanced; confirm `~/.config/cue/config.toml` |
| Automation stopped working | Replace `notinhas://` URLs with `cue://` |
| Old cloud settings are present | They are ignored; local sharing and the selected direct image providers remain available |

## Retired BYO cloud settings

Plan 089 retires AWS S3, Cloudflare R2, and Google Drive uploads. Importing an older configuration tolerates and ignores its `[cloud]` section. Legacy `cloudURL` and `cloudKey` fields remain migration-only so old local records can decode, but are not used for new uploads or UI actions.

This migration is non-destructive: Cue does not delete remote objects, Keychain items, or configuration files.

For engineering detail see:

- `Cue/Services/Migration/CueIdentityMigrationService.swift`
- `Cue/Services/Migration/NotinhasIdentityMigrationService.swift` (legacy Notinhas chain)
- `CueTests/Services/Migration/`

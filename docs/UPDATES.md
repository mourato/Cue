# Diagnostics & Local Logs

Cue keeps diagnostics on the user's Mac only. There is **no** Sparkle updater, in-app **Check for Updates**, **About** tab, or **Report a Problem** bundle flow.

Verified against `Cue/Services/Diagnostics/` and `Cue/App/AppCoordinator.swift`.

## Updates

Install new versions manually from [GitHub Releases](https://github.com/mourato/Cue/releases):

1. Download `Cue-v<version>.dmg`
2. Quit Cue
3. Replace `/Applications/Cue.app`
4. Re-grant TCC permissions if macOS prompts after the signature change

See [RELEASES.md](RELEASES.md) for maintainer packaging notes and [MIGRATION.md](MIGRATION.md) for data/TCC migration.

## Diagnostics

- `DiagnosticLogger` appends to daily files:

  ```text
  ~/Library/Logs/Cue/notinhas_yyyy-MM-dd.txt
  ```

- Levels: `DBG`, `INF`, `WRN`, `ERR`, `CRS`
- Categories include SYSTEM, CAPTURE, LIFECYCLE, ANNOTATE, CLIPBOARD, EXPORT, PREFERENCES, HISTORY, and others.
- Toggle: `diagnostics.enabled` (default on) — Settings → Advanced → Diagnostics and onboarding diagnostics step.
- Retention: `LogCleanupScheduler` removes files older than `diagnostics.retentionDays` (default 3, range 1–30).
- Crash detection: `CrashSentinel` sets `diagnostics.sessionActive` per session; abnormal termination is logged on next launch.

## Sharing logs for bug reports

When filing a GitHub issue:

1. Reproduce the problem with diagnostics enabled.
2. Attach the relevant `cue_*.txt` files from `~/Library/Logs/Cue/` (redact paths or credentials if needed).
3. Include Cue version, macOS version, and install method.

There is no in-app upload or support endpoint.

## Cache management

Settings → Advanced exposes cache and capture storage cleanup actions. History retention policies are documented in [PREFERENCES.md](PREFERENCES.md) and [HISTORY.md](HISTORY.md).

## Related

- [APP_LIFECYCLE.md](APP_LIFECYCLE.md) — scheduler startup, onboarding diagnostics step
- [RELEASES.md](RELEASES.md) — DMG release workflow (no appcast)

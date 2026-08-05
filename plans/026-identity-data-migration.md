# Plan 026: Migrate Snapzy data into Notinhas storage

> **Executor instructions**: A Composer 2.5 subagent must implement this plan
> in an isolated worktree, run every gate, commit the changes, merge them into
> the orchestrator branch, remove the worktree/branch, and push. If isolation
> prevents merge/push, return the commit and commands to the GPT 5.6
> orchestrator, which performs them immediately. After integration, GPT 5.6
> runs `/thermo-nuclear-code-quality-review`, fixes every finding, commits the
> fixes, and only then starts Plan 027.
>
> **Drift check**:
> `git diff --stat 6822c42..HEAD -- Snapzy/App/SnapzyApp.swift Snapzy/Services/Migration Snapzy/Services/Cloud/DatabaseManager.swift Snapzy/Services/FileAccess/CaptureStorageManager.swift Snapzy/Services/Diagnostics Snapzy/Services/Configuration/SnapzyConfigurationPaths.swift Snapzy/Services/Cloud/CloudKeychainStore.swift SnapzyTests/Services/Migration SnapzyTests/Services/Configuration`
> must be empty before work begins.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: none
- **Category**: migration
- **Planned at**: `6822c42`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — this must precede the bundle-ID change.
- **Reviewer required**: yes — it moves SQLite, preferences, logs, config, and Keychain references.
- **Rationale**: First-launch ordering and collision safety are more important than speed.
- **Escalate when**: deletion, TCC transfer, cloud-object rewriting, or real credentials become necessary.

## Why this matters

The current app stores data under `Application Support/Snapzy`, logs under
`Logs/Snapzy`, configuration under `~/.config/snapzy`, and the database as
`snapzy.db`. A new Notinhas bundle would otherwise look empty. Migrate
non-destructively and idempotently before database initialization. TCC
permissions cannot be migrated and are deliberately deferred to documentation.

## Current state

- `Snapzy/App/SnapzyApp.swift:98-121` runs sandbox migration, then database setup;
  no identity migration exists.
- `Snapzy/Services/Migration/SandboxOffDataMigrationService.swift:36-169`
  provides injectable merge/copy/marker patterns.
- `Snapzy/Services/Cloud/DatabaseManager.swift:56,148-166` uses
  `Application Support/Snapzy/snapzy.db` plus WAL/SHM.
- `Snapzy/Services/FileAccess/CaptureStorageManager.swift:18-38` uses
  `Application Support/Snapzy/Captures`.
- `Snapzy/Services/Diagnostics/DiagnosticLogger.swift:17-23,101-106` uses
  `Logs/Snapzy` and `snapzy_` files.
- `Snapzy/Services/Configuration/SnapzyConfigurationPaths.swift:41-45` uses
  `~/.config/snapzy`.
- `Snapzy/Services/Cloud/CloudKeychainStore.swift:20-45,79-125` has legacy
  account/service lookup that should be extended.
- `SandboxOffDataMigrationServiceTests.swift:44-100` is the test exemplar.

Destination contract:

- `~/Library/Application Support/Notinhas`
- `notinhas.db`, `notinhas.db-wal`, `notinhas.db-shm`
- `~/Library/Logs/Notinhas/notinhas_YYYY-MM-DD.txt`
- `~/.config/notinhas/config.toml`
- new Keychain service/accounts under `com.mourato.notinhas.cloud`
- legacy inputs: old paths, `com.trongduong.snapzy(.debug)`, old config path,
  old logs, and old Keychain services.

## Commands

| Purpose | Command | Expected |
|---|---|---|
| Baseline/default | `./scripts/run-tests.sh` | Exit 0 |
| Focused migration | `./scripts/run-tests.sh -only-testing:SnapzyTests/NotinhasIdentityMigrationServiceTests` | All new tests pass |
| Config tests | `./scripts/run-tests.sh -only-testing:SnapzyTests/SnapzyConfigurationPathsTests` | All selected tests pass |
| Full verification | `./scripts/run-tests.sh` | `Tests passed.` |
| Format | `swiftformat --lint Snapzy/Services/Migration Snapzy/Services/Diagnostics Snapzy/Services/Configuration/SnapzyConfigurationPaths.swift SnapzyTests/Services/Migration` | No violations |

## Scope

**In scope**:

- `Snapzy/App/SnapzyApp.swift`
- `Snapzy/Services/Migration/SandboxOffDataMigrationService.swift`
- `Snapzy/Services/Migration/NotinhasIdentityMigrationService.swift` (create)
- `Snapzy/Services/Cloud/DatabaseManager.swift`
- `Snapzy/Services/FileAccess/CaptureStorageManager.swift`
- `Snapzy/Services/Diagnostics/DiagnosticLogger.swift`
- `Snapzy/Services/Diagnostics/LogCleanupScheduler.swift`
- `Snapzy/Services/Configuration/SnapzyConfigurationPaths.swift`
- `Snapzy/Services/Cloud/CloudKeychainStore.swift`
- `Snapzy/Features/Preferences/Models/PreferencesKeys.swift`
- `SnapzyTests/Services/Migration/NotinhasIdentityMigrationServiceTests.swift` (create)
- `SnapzyTests/Services/Configuration/SnapzyConfigurationPathsTests.swift`

**Out of scope**: bundle/project rename, URL scheme, Sparkle/About/report
removal, source-root rename, cloud/recording/video changes, TCC transfer, and
automatic deletion of old data.

## Git workflow

Branch: `advisor/026-identity-data-migration`; commit:
`feat: migrate Snapzy data to Notinhas storage`.

## Steps

### 1. Centralize paths and add injectable migration

Create `NotinhasIdentityMigrationService` with injected home/Library,
FileManager, UserDefaults, and Keychain adapter. Recognize release/debug legacy
bundle IDs. Missing sources are no-ops; read/copy failures do not set the
completion marker.

**Verify**: `swiftformat --lint Snapzy/Services/Migration/NotinhasIdentityMigrationService.swift` → no violations.

### 2. Migrate files and database atomically

Merge old Application Support into Notinhas without overwriting destination
files. Copy `snapzy.db`, WAL, and SHM together to their `notinhas.db` names;
an incomplete companion set or unsafe collision must be a typed failure.
Update `DatabaseManager` and `CaptureStorageManager` to new destinations.

**Verify**: focused migration tests assert files, collisions, retries, and
SQLite companion handling.

### 3. Migrate logs, config, preferences, and Keychain

Write new logs as `Notinhas/notinhas_...`; let retention recognize both new
files and copied old files. Import old UserDefaults domains without overriding
existing new values. Copy `.config/snapzy` to `.config/notinhas` when needed.
On Keychain read miss, search old services/accounts, write the new item, and
delete only the exact migrated item. Never log secret values.

**Verify**: diagnostics/config/migration tests pass; tests use temporary roots,
`UserDefaultsFactory`, and a fake Keychain adapter only.

### 4. Run before database setup

Invoke the migration in `AppDelegate.applicationDidFinishLaunching` before
`ensureDatabaseReadyForLaunch`. Preserve old sandbox-container sources and the
existing retry/start-fresh/quit recovery style without deleting legacy data.

**Verify**: `rg -n 'NotinhasIdentityMigrationService|ensureDatabaseReadyForLaunch' Snapzy/App/SnapzyApp.swift` shows migration first; `./scripts/run-tests.sh` passes.

## Test plan

Add tests for no source, copy, idempotency, collisions, partial failure,
release/debug preference domains, old config, logs, SQLite companions, old
sandbox container, and fake-Keychain migration. Model them on
`SandboxOffDataMigrationServiceTests`.

## Done criteria

- [ ] New destinations are active; old sources remain readable and are not
      deleted automatically.
- [ ] Migration runs before database initialization and is idempotent.
- [ ] SQLite WAL/SHM, preferences, logs, config, and Keychain paths are tested.
- [ ] `./scripts/run-tests.sh` and scoped formatting pass.
- [ ] Only Scope files changed.
- [ ] Composer 2.5 commit was merged, worktree/branch cleaned, and pushed.
- [ ] GPT 5.6 thermo review findings were fixed and committed.

## STOP conditions

Stop if safe handling of an incomplete SQLite set, old sandbox container,
Keychain entitlement, or destination collision cannot be established. Also
stop after two failed verification attempts or if an out-of-scope file is
needed.

## Maintenance notes

Plan 029 must reuse this marker/path contract when changing the bundle ID. Keep
legacy constants explicit and review startup ordering and secret-free logging.

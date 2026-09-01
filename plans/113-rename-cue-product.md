# Plan 113: Rename the product identity from Notinhas to Cue

> **Executor instructions**: Implement in an isolated worktree (`cue/rename-product`),
> run every gate, commit, review, merge, validate, push. Use `git mv` for physical
> renames. Do not start with a repo-wide find-replace on strings.
>
> **Drift check** (after integration):
> `rg -n '\\b(NotinhasApp|Notinhas\\.xcodeproj|com\\.mourato\\.notinhas|notinhas://)\\b' Cue CueTests Cue.xcodeproj scripts .github`
> must return no **active** matches outside allowlisted legacy readers/migration.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: —
- **Category**: tech-debt / identity
- **Planned at**: HEAD, 2026-08-31

## Confirmed product decisions (locked)

| Decision | Value |
|---|---|
| Display name | `Cue` / `Cue Debug` |
| Module / feature folder | `Cue/` and `Features/Cue/` |
| Release bundle ID | `com.mourato.cue` |
| Debug bundle ID | `com.mourato.cue.debug` |
| Test bundle ID | `com.mourato.cue.tests` |
| URL scheme | `cue://` only |
| Legacy URL schemes | `notinhas://` and `snapzy://` **rejected** (no alias) |
| GitHub repository | Rename to `mourato/Cue` after code integration |
| Video compile flag | `CUE_VIDEO_MODULE` (rename from `NOTINHAS_VIDEO_MODULE`) |
| Bundle name build setting | `CUE_BUNDLE_NAME` (rename from `NOTINHAS_BUNDLE_NAME`) |

**User impact**: bundle-ID change resets Screen Recording, Accessibility,
Microphone, and Camera TCC grants. Existing Notinhas data must migrate
automatically on first Cue launch (same class of work as Plan 026/029).

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: High/Full
- **Parallelizable**: no — project, module, bundle, migration, scripts, and CI
  must move atomically per integration unit.
- **Reviewer required**: yes
- **Escalate when**: legacy Snapzy readers are deleted, cloud object prefixes
  change, `notinhas://` is kept as an alias, or TCC “transfer” is proposed.

## Why this matters and current state

The codebase identifies as Notinhas at every layer: `Notinhas.xcodeproj`,
`Notinhas/` module root, `Features/Notinhas/` domain, ~464 `Notinhas*`
Swift symbols, `com.mourato.notinhas` bundle IDs, `notinhas://` deep links,
Application Support / logs / config paths, Keychain service names, localization,
scripts, CI DMG names, and agent/docs guidance.

Plan 029 already renamed Snapzy → Notinhas with explicit legacy readers.
This plan performs the same cutover Notinhas → Cue while **retaining** Snapzy
and Notinhas compatibility readers for upgrades and serialized data.

## Commands

| Purpose | Command | Expected |
|---|---|---|
| Project | `xcodebuild -project Cue.xcodeproj -list` | Cue targets/schemes listed |
| Default/video tests | `./scripts/run-tests.sh && ./scripts/run-tests.sh --video-module` | Both exit 0 |
| Debug/Release build | `xcodebuild -project Cue.xcodeproj -scheme Cue -configuration Debug build CODE_SIGNING_ALLOWED=NO` (and Release) | `BUILD SUCCEEDED` |
| Bundle ID | `PlistBuddy -c 'Print :CFBundleIdentifier' <Cue.app>/Contents/Info.plist` | `com.mourato.cue*` |
| URL scheme | `PlistBuddy -c 'Print :CFBundleURLTypes' …` | `cue` registered; no `notinhas` |
| Active identity scan | `rg -n '\\b(Notinhas|notinhas://|NOTINHAS_)\\b' Cue CueTests Cue.xcodeproj scripts .github --glob '!*Migration*' --glob '!*Legacy*'` | No active product identity outside allowlist |
| Legacy fence | Tests assert `notinhas://` and `snapzy://` are rejected | Pass |
| Format | `swiftformat --lint Cue CueTests` | No violations |
| Validate | `make validate` | Pass |

## Scope

**In scope**

- Physical rename: `Notinhas.xcodeproj` → `Cue.xcodeproj`, `Notinhas/` → `Cue/`,
  `NotinhasTests/` → `CueTests/`, `Notinhas.xctestplan` → `Cue.xctestplan`
- Schemes `Notinhas` / `Notinhas Video` → `Cue` / `Cue Video`
- Targets, products (`Cue.app`), module imports, entitlements path
- Bundle IDs, `Info.plist`, `AppBundleIdentity`, deep-link handler (`cue://`)
- `CueIdentityMigrationService` (Notinhas → Cue paths, prefs, Keychain, DB, logs,
  config) — modeled on `NotinhasIdentityMigrationService`
- Rename `Features/Notinhas/` → `Features/Cue/` and mechanical `Notinhas*` →
  `Cue*` symbol renames (types, files, tests)
- Serialized formats: new writes use Cue names; readers accept Notinhas + Snapzy
  legacy (e.g. `PersistedCueNotesSession` reads `notinhasNotesSession` JSON key)
- TOML: export `cue_min_version`; import `notinhas_min_version` and `snapzy_*`
  as legacy aliases
- Default capture filenames: `Cue_{datetime}`, `Cue_Recording_{datetime}`
- Assets: `CueIcon*`, menubar PNG names as needed, `CFBundleIconFile`
- Localization (~760 strings), `L10n.swift` defaults, TCC usage strings
- Logger subsystem `Cue`, dispatch queue labels `com.mourato.cue.*`
- Test env vars: `CUE_ALLOW_*` (rename from `NOTINHAS_ALLOW_*`)
- Scripts, Makefile, `.github/workflows`, DMG `Cue-v<version>.dmg`, `install.sh`
- `uninstall.sh` / `reset-permissions.sh`: clean Cue + legacy Notinhas/Snapzy paths
- Plan 114 prep: list doc/skill paths for follow-up sweep

**Out of scope**

- Changing cloud upload object key prefixes or provider APIs
- Reintroducing Sparkle, About, Report, or removed Snapzy surfaces
- Deleting Snapzy/Notinhas legacy import readers or migration tests
- Renaming unrelated in-flight feature plans (109–112) — update only when they
  touch renamed paths during merge conflict resolution

## Allowlisted legacy (must remain readable, not active identity)

- Snapzy storage paths, bundle IDs, Keychain services, TOML keys, sidecars
- Notinhas storage paths and bundle IDs as **migration sources only**
- JSON keys `notinhasNotesSession` on read
- Rejection tests for `snapzy://` and `notinhas://`

## Git workflow

Branch: `cue/rename-product`
Commit message: `refactor: rename Notinhas product identity to Cue`

Repository rename (`mourato/Notinhas` → `mourato/Cue`) happens **after** merge
via GitHub Settings + local `git remote set-url` (human or authorized step).

## Steps (execution order)

### 0. Preflight

Create worktree, bind delivery contract, record base SHA. Confirm no unrelated
dirty paths in the worktree root.

### 1. Migration service first (before bundle cutover)

Add `CueIdentityMigrationService` + `CueStoragePaths` + tests:

| Source (Notinhas) | Destination (Cue) |
|---|---|
| `~/Library/Application Support/Notinhas/` | `…/Cue/` |
| `~/Library/Logs/Notinhas/notinhas_*.txt` | `…/Cue/cue_*.txt` |
| `~/Library/Application Support/notinhas/config.toml` | `…/cue/config.toml` |
| `notinhas.db` | `cue.db` |
| Prefs `com.mourato.notinhas(.debug)` | import into Cue defaults |
| Keychain `com.mourato.notinhas.cloud` | `com.mourato.cue.cloud` |
| Marker `.notinhas-identity-migration-completed` | read-only; write `.cue-identity-migration-completed` |

Wire migration to run before database setup (same ordering as Plan 026).

**Verify**: focused migration tests pass on current tree (can land before step 2
if migration types are added under neutral names first, then renamed in step 2).

### 2. Physical Xcode rename (atomic batch)

`git mv` project, module roots, test plan, schemes, entitlements. Update
`project.pbxproj`: target names, test host, `CUE_BUNDLE_NAME`, bundle IDs,
`CUE_VIDEO_MODULE`, product names, icon references.

**Verify**: `xcodebuild -list` and Debug build succeed.

### 3. Runtime identity and deep links

- `CueApp`, `AppBundleIdentity` → `com.mourato.cue*`
- `CueDeepLinkHandler`, register `cue://`, reject `notinhas://` and `snapzy://`
- Update `Info.plist` URL types and permission strings

**Verify**: deep-link rejection tests; PlistBuddy checks on built app.

### 4. Swift symbols and `Features/Cue/`

Mechanical rename `Notinhas*` → `Cue*` (files + types). Rename
`Features/Notinhas/` → `Features/Cue/`. Update cross-module references in
Annotate, Capture, Configuration, Cloud.

Serialized session models: new primary types; decode legacy JSON keys.

**Verify**: identity scan; Debug build; `./scripts/run-tests.sh`.

### 5. User-visible branding and assets

Localization catalogs, `CaptureOutputNaming`, splash/onboarding/menubar tooltips,
`CueIcon` asset set, diagnostic subsystem strings.

**Verify**: spot-check EN + one non-EN locale; menubar/Dock name in manual smoke.

### 6. Tooling, CI, and cleanup scripts

Update `scripts/build_and_run.sh`, `run-tests.sh`, release workflow, DMG naming,
`verification-map.tsv`, Makefile, `install.sh`, `uninstall.sh`.

**Verify**: `make validate`; dry-run release script if available.

### 7. Documentation and agent guidance (Plan 114 or same PR if small)

README, AGENTS.md, docs/*, `.agents/skills/*`, MIGRATION.md (Cue upgrade path,
TCC re-grant, no `notinhas://`). Update `plans/README.md` confirmed decisions.

### 8. GitHub repository rename

After merge to `main`: rename repo to `Cue`, update remotes, release URLs,
issue templates, SECURITY.md links.

## Test plan

- `CueIdentityMigrationServiceTests`: Notinhas App Support, logs, config, DB,
  prefs, Keychain copy/import
- Config TOML: export contains `cue_min_version`; import accepts `notinhas_*`
  and `snapzy_*`
- Deep links: `cue://capture/area` dispatches; `notinhas://` and `snapzy://`
  rejected with tests
- Annotation session restore: JSON with `notinhasNotesSession` still loads
- Capture → annotate → export (default suite)
- Video module suite if `CUE_VIDEO_MODULE` paths touched
- Manual: install Cue over existing Notinhas.app; confirm data migration and
  permission prompts

## Done criteria

- [ ] Project, module, schemes, app bundle, scripts, and CI identify as Cue
- [ ] Bundle IDs exactly `com.mourato.cue` / `.debug` / `.tests`
- [ ] Only `cue://` registered; `notinhas://` rejected
- [ ] Notinhas → Cue migration runs once and preserves user data
- [ ] Snapzy legacy readers unchanged
- [ ] Tests, builds, format, and `make validate` pass
- [ ] GitHub repo renamed to `mourato/Cue` (or documented blocker)

## STOP conditions

Stop if: migration loses Keychain or database access; a serialized format loses
a reader; cloud prefix change is required; two gates fail; unrelated dirty paths
appear in the worktree; or `notinhas://` alias is reintroduced.

## Follow-up

- **Plan 114** (optional): docs/skills/release-notes sweep and migration guide
  for external automations that used `notinhas://` (must switch to `cue://`).

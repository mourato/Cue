# Plan 028: Replace `snapzy://` with `notinhas://`

> **Executor instructions**: A Composer 2.5 subagent implements this plan in an
> isolated worktree, runs all gates, commits, merges, cleans the worktree/branch,
> and pushes. If isolation prevents integration, GPT 5.6 performs those
> operations from the returned commit. GPT 5.6 then runs
> `/thermo-nuclear-code-quality-review`, fixes every finding, commits the fixes,
> and only then starts Plan 029.
>
> **Drift check**:
> `git diff --stat 92491f3..HEAD -- Snapzy/Resources/Info.plist Snapzy/App/AppCoordinator.swift Snapzy/App/SnapzyDeepLinkHandler.swift Snapzy/Services/Cloud/GoogleDriveOAuthService.swift Snapzy/Shared/Localization/L10n.swift Snapzy/Resources/Localization/Features/Settings.xcstrings SnapzyTests/App/SnapzyDeepLinkHandlerTests.swift SnapzyTests/Services/Media/MediaCoreTests.swift`
> must be empty.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/027-remove-upstream-surfaces.md`
- **Category**: migration
- **Planned at**: `92491f3`, 2026-07-21 (reconciled after Plan 027 review fixes)

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — LaunchServices, parser, OAuth, localization, and tests form one contract.
- **Reviewer required**: yes — an incorrect scheme breaks external automation and OAuth return.
- **Rationale**: Route grammar is existing and tested, but OS registration and browser callbacks are cross-process.
- **Escalate when**: an alias is proposed, route semantics change, or provider-side callback registration is needed.

## Why this matters and current state

`Snapzy/Resources/Info.plist:31-40` registers `snapzy`; 
`Snapzy/App/SnapzyDeepLinkHandler.swift:12,30,128-149` validates it and
`AppCoordinator.swift:112-115` constructs the handler. Google Drive OAuth
HTML in `GoogleDriveOAuthService.swift:380-392,476-488` returns through
`snapzy://settings/cloud`. L10n and Settings catalogs document the old scheme.
The current handler tests cover canonical routes, aliases, file parameters,
settings, and disabled/video gates. `QRPayloadClassifier.swift` generically
classifies schemes and must not become a dispatcher.

Only the scheme changes. Preserve route aliases and `open/combine?file=`
semantics; reject old URLs explicitly.

## Commands

| Purpose | Command | Expected |
|---|---|---|
| Deep links | `./scripts/run-tests.sh -only-testing:SnapzyTests/NotinhasDeepLinkHandlerTests` | All route tests pass |
| Media/QR | `./scripts/run-tests.sh -only-testing:SnapzyTests/MediaCoreTests` | All tests pass |
| Full suite | `./scripts/run-tests.sh` | Exit 0 |
| Registration | `/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:0:CFBundleURLSchemes:0' Snapzy/Resources/Info.plist` | `notinhas` |
| Active-scheme scan | `rg -n 'snapzy://|notinhas://' Snapzy SnapzyTests` | Old value only in explicit rejection/legacy tests |
| Format | `swiftformat --lint Snapzy/App Snapzy/Services/Cloud/GoogleDriveOAuthService.swift SnapzyTests/App` | No violations |

## Scope

**In scope**:

- `Snapzy/Resources/Info.plist`
- `Snapzy/App/AppCoordinator.swift`
- `Snapzy/App/SnapzyDeepLinkHandler.swift` → `NotinhasDeepLinkHandler.swift`
- `Snapzy/Services/Cloud/GoogleDriveOAuthService.swift`
- `Snapzy/Shared/Localization/L10n.swift`
- Settings localization catalogs
- `SnapzyTests/App/SnapzyDeepLinkHandlerTests.swift` →
  `NotinhasDeepLinkHandlerTests.swift`
- `SnapzyTests/Services/Media/MediaCoreTests.swift`

**Out of scope**: project/module/source-root rename (Plan 029), docs (Plan 030),
compatibility aliases, route grammar changes, URL preference removal, and cloud
token behavior.

## Git workflow

Branch: `advisor/028-notinhas-url-scheme`; commit:
`feat: replace Snapzy URL scheme with notinhas`.

## Steps

### 1. Register only the new scheme

Set `CFBundleURLName` to the future `com.mourato.notinhas` identity and make
the only `CFBundleURLSchemes` value `notinhas`.

**Verify**: PlistBuddy command returns `notinhas` and no second scheme exists.

### 2. Rename and harden the handler

Rename handler/action types to `NotinhasDeepLinkHandler` and
`NotinhasDeepLinkAction`; accept only lowercased `notinhas`. Preserve all
existing routes and remove the About route already removed by Plan 027. Add
capture, settings, and combine tests proving `snapzy://` returns `nil`.

**Verify**: focused deep-link tests pass and `rg` finds no active old handler names.

### 3. Update OAuth and localized copy

Change Google Drive success/failure redirects to
`notinhas://settings/cloud` and visible callback labels to Notinhas. Update
L10n/catalog values naming the scheme. Keep HTML escaping, state checks,
loopback server, and token handling unchanged.

**Verify**: OAuth old-string scan returns no active matches; media/QR tests pass.

### 4. Validate disabled and cold-launch routing

Confirm the URL preference still gates new URLs, unknown schemes are ignored,
and the generic QR classifier remains generic.

**Verify**: `./scripts/run-tests.sh` passes.

## Test plan

Rename and preserve all existing deep-link tests; add explicit old-scheme
rejection for capture/settings/combine. Use `notinhas://` in product QR
fixtures and retain one generic old-scheme classification assertion without
dispatch.

## Done criteria

- [ ] Info.plist registers only `notinhas`.
- [ ] Handler accepts `notinhas://` and rejects `snapzy://`.
- [ ] Route aliases/file semantics and disabled preference pass.
- [ ] Google OAuth returns through the new scheme.
- [ ] Localized user copy uses the new scheme.
- [ ] Tests/format pass and only Scope files changed.
- [ ] Composer 2.5 commit merged, cleaned, and pushed; GPT 5.6 review findings
      fixed and committed before Plan 029.

## STOP conditions

Stop if an existing caller requires the old alias, OAuth needs an unprovided
provider registration, route behavior is unclear, two gate attempts fail, or
an out-of-scope file is required.

## Maintenance notes

Plan 029 physically renames the source/test roots. Plan 030 must document the
intentional old-scheme rejection.

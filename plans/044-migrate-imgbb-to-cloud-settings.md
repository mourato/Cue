# Plan 044: Migrate ImgBB configuration into the Cloud preferences flow

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the **STOP conditions** section occurs, stop and
> report — do not improvise. When done, update the status row for this plan in
> `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first):**
> `git diff --stat cf730ede..HEAD -- Notinhas/Features/Preferences/Components/PreferencesCloudSettingsView.swift Notinhas/Features/Preferences/Components/PreferencesAnnotateSettingsView.swift Notinhas/Features/Notinhas/Services/NotinhasImgBBConfiguration.swift Notinhas/Features/Notinhas/Services/NotinhasUploadCoordinator.swift Notinhas/Services/Cloud/CloudKeychainStore.swift Notinhas/Shared/Localization/L10n.swift Notinhas/Resources/Localization/Features/Cloud.xcstrings Notinhas/Resources/Localization/Features/Annotate.xcstrings docs/CLOUD.md docs/PREFERENCES.md docs/SECURITY.md docs/CONFIGURATION.md`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED-HIGH
- **Depends on**: none; coordinate the Preferences UI smoke test with Plan 043 if both are implemented in the same round.
- **Category**: direction
- **Planned at**: commit `cf730ede`, 2026-07-22

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — credential migration, Cloud UI, operational upload callers, localization, and documentation must agree on one source of truth.
- **Reviewer required**: yes — this changes secret storage and user-facing Preferences, and requires a manual migration/upload gate.
- **Rationale**: The visible UI change is localized, but the current ImgBB key is read from plain UserDefaults with an Info.plist fallback while Cloud credentials use Keychain. The executor must preserve existing keys, migrate safely, and keep the generic Cloud provider/history contract intact.
- **Escalate when**: the target still injects `IMGBB_API_KEY`; the implementation needs to change `CloudProviderType`, `CloudProvider`, `CloudUploadRecord`, cloud expiration/deletion semantics, or the `.notinhascloud` archive format; or an existing release depends on the build-time key.

## Grilling: decisions and non-goals

The request contains two different possible scopes. This plan chooses the safer product interpretation and makes the alternative explicit:

1. **Recommended target — configuration ownership moves to Cloud.** Add an ImgBB “Image Sharing” section to `CloudSettingsView`, using the existing `Section`, `SettingRow`, password-gate, masked-secret, and alert patterns. Remove the API-key editor from Annotate preferences. Annotate and Quick Access keep their operational “Upload to ImgBB” actions and read the same shared configuration.
2. **Rejected for this plan — make ImgBB a `CloudProvider`.** The current `CloudProvider` contract assumes bucket/folder storage, object keys, public URL generation, lifecycle/expiration, deletion, progress, and `CloudUploadHistoryStore` records. ImgBB is an image-only external host that returns a link and a `delete_url`; the current upload path also accepts an `NSImage` and copies a link rather than managing a cloud object. Adding `.imgbb` would create fake expiration/history/deletion behavior and broaden schema/UI changes without user value.

The generic Cloud upload button, Cloud Uploads history, expiration controls, provider picker, and cloud-storage reset remain unchanged. ImgBB uploads do not appear in Cloud Upload History in this plan. If the desired outcome is one provider picker, shared history, or deletion from the Cloud window, stop and create a follow-up plan for a separate external-image-host model.

Do not add a “Test ImgBB credentials” action that uploads a disposable image: there is no side-effect-free validation endpoint in the current adapter. Saving the key and using the existing real upload flow are the acceptance checks.

## Why this matters

ImgBB is currently configured under Annotate’s Notinhas settings, but it is a network-backed image-sharing integration and its secret is stored outside the Cloud security model. This splits discovery from the Cloud tab and lets the API key bypass the Cloud Keychain/password/secret-handling conventions. The desired end state is one Cloud-owned configuration surface, one secure source of truth, and unchanged manual image-sharing actions in Annotate and Quick Access.

## Current state

### Relevant files and symbols

- `Notinhas/Features/Preferences/Components/PreferencesAnnotateSettingsView.swift` — currently renders the ImgBB API-key `SettingRow` under the Notinhas settings section and binds `@AppStorage(PreferencesKeys.notinhasImgBBAPIKey)`.
- `Notinhas/Features/Preferences/Components/PreferencesCloudSettingsView.swift` — owns the Cloud tab, existing grouped `Form`, `Section`, `SettingRow`, configured/unconfigured states, `CloudPasswordGateView`, and protected edit/import/export actions.
- `Notinhas/Features/Notinhas/Services/NotinhasImgBBConfiguration.swift` — currently reads `notinhas.imgbb.apiKey` from UserDefaults first and `IMGBB_API_KEY` from Info.plist second; it also owns unrelated panel-side migration, which must remain intact.
- `Notinhas/Features/Notinhas/Services/NotinhasImgBBUploadService.swift` — ImgBB HTTP adapter; keep its image upload protocol, result link, `deleteURL`, error mapping, and endpoint behavior unless a focused test requires a small seam.
- `Notinhas/Features/Notinhas/Services/NotinhasUploadCoordinator.swift` — downscales the rendered image and delegates upload; keep the 2048-pixel Annotate and existing Quick Access behavior.
- `Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift` — manual Annotate upload action; remove its `@AppStorage` observation workaround once the shared secure configuration publishes a reliable state change.
- `Notinhas/Features/QuickAccess/Components/QuickAccessCardView.swift` — manual Quick Access ImgBB action; keep it enabled from the shared configuration.
- `Notinhas/Services/Cloud/CloudKeychainStore.swift` — add a dedicated ImgBB secret item without changing existing cloud credential accounts or legacy migrations.
- `Notinhas/Services/Cloud/CloudManager.swift` or a small Cloud-owned ImgBB credential adapter — expose load/save/clear/masked/configured operations without turning ImgBB into `CloudProvider`.
- `Notinhas/Features/Preferences/Models/PreferencesKeys.swift` — retain `notinhas.imgbb.apiKey` as a legacy-read migration key; do not use it for new writes or rename it away during this plan.
- `Notinhas/Resources/Info.plist` — currently contains the optional `IMGBB_API_KEY` build-time fallback; remove it only after the stop-condition search proves no target/release workflow depends on it.
- `Notinhas/Resources/Localization/Features/Cloud.xcstrings`, `Annotate.xcstrings`, and generated `Notinhas/Shared/Localization/L10n.swift` — move only configuration title/help/placeholder ownership to Cloud; keep operational upload/error copy under Annotate.
- `docs/CLOUD.md`, `docs/PREFERENCES.md`, `docs/SECURITY.md`, and `docs/CONFIGURATION.md` — document the new ownership, storage, portability boundary, and network behavior.

### Required target behavior

- The Cloud tab always shows an **Image Sharing** / ImgBB section, including when no generic Cloud storage provider is configured.
- When unconfigured, the section offers a secure API-key field and Save action. When configured, it shows a masked status and protected Edit/Clear actions using the existing Cloud password gate when a protection password exists.
- The generic Cloud storage form and ImgBB section remain separate. Cloud reset must not silently delete the ImgBB key; the ImgBB section has its own explicit clear action.
- New writes go to Keychain. A legacy UserDefaults value is migrated additively on read/write; the old value is removed only after a successful Keychain write. If Keychain is unavailable, keep the legacy value usable and surface the existing error pattern without logging the value.
- The `IMGBB_API_KEY` Info.plist fallback is removed once confirmed unused. A build-time secret must not remain as an undocumented second source of truth.
- Annotate and Quick Access continue to upload manually to ImgBB and copy the returned link. Missing-key copy should point users to Preferences → Cloud. Generic Cloud uploads and history remain independent.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Drift check | `git diff --stat cf730ede..HEAD -- Notinhas/Features/Preferences/Components/PreferencesCloudSettingsView.swift Notinhas/Features/Preferences/Components/PreferencesAnnotateSettingsView.swift Notinhas/Features/Notinhas/Services/NotinhasImgBBConfiguration.swift Notinhas/Features/Notinhas/Services/NotinhasUploadCoordinator.swift Notinhas/Services/Cloud/CloudKeychainStore.swift Notinhas/Shared/Localization/L10n.swift Notinhas/Resources/Localization/Features/Cloud.xcstrings Notinhas/Resources/Localization/Features/Annotate.xcstrings docs/CLOUD.md docs/PREFERENCES.md docs/SECURITY.md docs/CONFIGURATION.md` | Empty output, or every pre-existing change is reviewed against this plan before proceeding. |
| Build-key audit | `rg -n "IMGBB_API_KEY|imgbb.*api.?key|notinhas\.imgbb\.apiKey" . --glob '!build/**' --glob '!.build/**' --glob '!plans/**'` | Every match is classified as active configuration, legacy migration, operational copy, or documentation; no untracked release/CI injection is missed. |
| Focused ImgBB tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/NotinhasImgBBUploadServiceTests -only-testing:NotinhasTests/NotinhasImgBBConfigurationTests` | Exit 0; upload parsing and secure configuration migration tests pass. |
| Cloud core regression | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CloudCoreTests` | Existing Cloud signing, transfer, lifecycle, and history-adjacent tests pass unchanged. |
| Localization verification | `swift -module-cache-path build/swift-module-cache tools/localization/CatalogTool.swift verify` | `missing=0` and `extra=0`; any known unrelated CatalogTool path issue is reported, not “fixed” by widening scope. |
| Formatting | `swiftformat Notinhas/Features/Preferences/Components/PreferencesCloudSettingsView.swift Notinhas/Features/Preferences/Components/PreferencesAnnotateSettingsView.swift Notinhas/Features/Notinhas/Services/NotinhasImgBBConfiguration.swift Notinhas/Services/Cloud/CloudKeychainStore.swift` | Formatting completes with no unrelated files changed. |
| Default build | `./scripts/build_and_run.sh --no-video-module --verify` | Default Notinhas scheme builds and launches. |
| Full default tests | `./scripts/run-tests.sh` | Exit 0, or pre-existing unrelated failures are recorded explicitly. |

## Scope

**In scope** (the only files to modify, plus a focused new test/helper file if required by the existing test target):

- `Notinhas/Features/Preferences/Components/PreferencesCloudSettingsView.swift` — add the ImgBB Image Sharing section and protected edit/clear flow using existing components.
- `Notinhas/Features/Preferences/Components/PreferencesAnnotateSettingsView.swift` — remove only the ImgBB API-key editor; retain panel-side and all other Annotate settings.
- `Notinhas/Features/Notinhas/Services/NotinhasImgBBConfiguration.swift` — make the secure Cloud-owned credential source authoritative and preserve panel-side migration.
- `Notinhas/Services/Cloud/CloudKeychainStore.swift` and, if needed, a small `Notinhas/Services/Cloud/ImgBB...CredentialStore.swift` adapter — add the dedicated secret item and legacy migration seam.
- `Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift` and `Notinhas/Features/QuickAccess/Components/QuickAccessCardView.swift` — update configuration reads/state refresh and the missing-key destination copy only; preserve upload behavior.
- `Notinhas/Features/Notinhas/NotinhasL10n.swift`, `Notinhas/Shared/Localization/L10n.swift`, `Notinhas/Resources/Localization/Features/Cloud.xcstrings`, and `Annotate.xcstrings` — move configuration strings to Cloud and retain operational ImgBB strings under Annotate.
- `Notinhas/Resources/Info.plist` — remove the build-time `IMGBB_API_KEY` entry only after the build-key audit passes.
- `docs/CLOUD.md`, `docs/PREFERENCES.md`, `docs/SECURITY.md`, and `docs/CONFIGURATION.md` — document behavior and the deliberate Cloud-storage/ImgBB boundary.
- `NotinhasTests/Features/Notinhas/NotinhasImgBBConfigurationTests.swift` (new, or the existing configuration test location) and `NotinhasTests/Features/Notinhas/NotinhasImgBBUploadServiceTests.swift` — cover migration/source precedence without any real API key.
- `plans/README.md` — update plan 044 status when the executor finishes.

**Out of scope** (do not touch):

- `CloudProviderType`, `CloudProvider`, `CloudManager.upload`, provider implementations, `CloudUploadRecord`, `CloudUploadHistoryStore`, expiration/lifecycle logic, and generic Cloud upload UI.
- Adding ImgBB to Cloud Upload History, Cloud Uploads window, re-upload/stale-record logic, deletion, thumbnails, usage stats, or provider selection.
- Changing the existing `.notinhascloud` encrypted storage-credential archive; ImgBB portability is a separate decision because the current archive requires a configured storage provider and access/secret pair.
- Changing `NotinhasImgBBUploadService`’s endpoint, image encoding, returned `deleteURL`, 2048-pixel downscaling, or clipboard-success behavior.
- Removing the legacy UserDefaults key before a successful migration path exists, logging key material, adding a secret to TOML/config exports, or retaining a new UserDefaults write.
- Any unrelated Annotate, Capture, Recording, Quick Access, menu-bar, or product-branding changes.

## Steps

### Step 1: Confirm drift, callers, and secret injection

Run the drift and build-key commands. Read the live Cloud settings states, ImgBB configuration, CloudKeychainStore, upload callers, localization manifest, and docs. Classify every `IMGBB_API_KEY` and `notinhas.imgbb.apiKey` match. Confirm whether any Xcode configuration, script, release workflow, or local build setting still injects the Info.plist key.

**Verify**: no in-scope file has unexplained drift; the only legacy runtime source is the documented UserDefaults key; and no active target/release workflow depends on `IMGBB_API_KEY`. If the last condition is false, STOP and report the dependency instead of deleting the fallback.

### Step 2: Add a secure, migration-safe ImgBB credential source

Add a dedicated `CloudKeychainItem` account for the ImgBB API key. Expose a small synchronous adapter or CloudManager facade with `read`, `save`, `clear`, `maskedValue`, and `isConfigured` behavior. Keep secret values out of logs and diagnostics.

Make the Keychain value authoritative. On read, use this precedence:

1. Current ImgBB Keychain item.
2. Legacy `UserDefaults` value under `PreferencesKeys.notinhasImgBBAPIKey`; if non-empty, attempt one-time Keychain upsert, then remove the legacy value only after success.
3. No value. Do not retain the Info.plist fallback after Step 1 approves its removal.

If a Keychain write fails, preserve the legacy value for continuity and return the existing localized configuration error path. Keep `NotinhasImgBBConfiguration.migratePanelSideIfNeeded()` and its unrelated key behavior unchanged. Retain the old UserDefaults constant solely for migration and add a comment that new writes must not use it.

**Verify**: the new configuration tests cover Keychain-first precedence, legacy migration, failed-write preservation, empty/whitespace handling, masking, and absence of secret values in logs or test fixtures. Existing `NotinhasImgBBUploadServiceTests` still pass.

### Step 3: Move the editor into the Cloud tab

Extract a focused private `ImgBBSettingsSection` only if needed to keep `CloudSettingsView` readable. Render it in the Cloud `Form` for both generic-cloud configured and unconfigured states, using existing `Section`, `SettingRow`, `SecureField`/masked status, buttons, and alert patterns.

Use an explicit heading/description that identifies ImgBB as external image sharing, not bucket storage. In the unconfigured state, allow API-key setup without requiring a generic storage provider. In the configured state, show masked status and provide protected Edit/Clear actions. Reuse `CloudPasswordGateView` when `CloudPasswordService.shared.shouldRequirePasswordForEdit()` is true; do not force a new password-init flow for an ImgBB-only user. Keep the generic Cloud reset limited to generic storage credentials; ImgBB clear must be explicit.

Remove only the ImgBB `SettingRow` and `@AppStorage` binding from `PreferencesAnnotateSettingsView`. Do not add an Annotate navigation link or duplicate key editor.

**Verify**: source inspection shows exactly one configuration editor under `CloudSettingsView`; the Cloud section renders when generic Cloud storage is unconfigured; Annotate settings no longer contain an API-key field; and generic provider edit/import/export/reset behavior is unchanged.

### Step 4: Reconnect the operational upload flows to the shared source

Update Annotate and Quick Access callers to use the secure shared configuration rather than observing `@AppStorage` directly. Preserve their existing manual actions, disabled states, downscaling, progress/toasts, link copy, and error handling. Update the missing-key guidance to point to Preferences → Cloud. Do not merge the ImgBB action into the generic Cloud action and do not add ImgBB records to Cloud history.

If SwiftUI needs immediate refresh after Cloud settings change, use the narrowest existing observable state/invalidation mechanism; do not reintroduce a UserDefaults observer solely to mirror the removed field. Verify a key change, clear, and failed save update both Annotate and Quick Access availability after reopening or returning to those surfaces.

**Verify**: focused upload tests pass; a source search finds no active `@AppStorage(PreferencesKeys.notinhasImgBBAPIKey)` binding; and generic Cloud upload call sites remain untouched except for clearly unrelated shared-state compilation fixes.

### Step 5: Move localization and update security/product documentation

Move only these configuration strings from the `annotate.notinhas.*` namespace to `cloud-settings.*` (or the project’s equivalent Cloud prefix): API-key title, help, and placeholder. Keep operational error/progress/success strings and the “Upload to ImgBB” action under Annotate because the action remains in Annotate/Quick Access. Update `NotinhasL10n` and `L10n.CloudSettings` consistently and remove obsolete source-catalog entries only after reference search confirms they are unused.

Update documentation to state:

- Cloud Preferences owns generic storage providers and an independent ImgBB external-image-sharing integration.
- ImgBB’s API key is stored in Keychain, migrated from the legacy UserDefaults key, and is not written to ordinary TOML configuration.
- The encrypted `.notinhascloud` archive remains for generic Cloud storage credentials in this plan; ImgBB is intentionally not presented as a storage provider or history record.
- Manual ImgBB upload remains available from Annotate and Quick Access; it is not automatic and does not change Cloud Upload History.
- Network access includes user-configured ImgBB image uploads in addition to user-configured storage.

Remove the `IMGBB_API_KEY` Info.plist/security documentation only when Step 1 proved it is unused. Never include a real key in docs, fixtures, screenshots, logs, or commit history.

**Verify**: CatalogTool reports `missing=0` and `extra=0`; `rg` finds no old configuration-string references; docs agree on Keychain ownership and archive boundaries; and no secret literal appears in the diff.

### Step 6: Run automated gates and the manual migration/UI gate

Run all commands in the Commands table, then manually verify:

- With generic Cloud storage unconfigured, Preferences → Cloud still exposes ImgBB setup and save.
- A configured key is masked; editing/clearing follows the existing Cloud password behavior; generic Cloud reset does not remove it.
- An existing legacy UserDefaults key migrates on first access, survives relaunch, and is not rewritten to UserDefaults.
- Annotate Preferences has no ImgBB API-key editor; Annotate and Quick Access still expose their manual ImgBB actions when configured.
- Uploading a rendered Annotate image copies the ImgBB link and shows the existing progress/success/error feedback.
- Generic Cloud upload, re-upload, history, expiration, and delete behavior remains unchanged; ImgBB uploads do not appear as Cloud history entries.
- Missing-key guidance points to Cloud, and no API key is visible in logs or diagnostics.

Record automated results and manual results separately. Use existing Screen Recording/Accessibility permissions for the capture/Annotate smoke check; no real API key or production upload is required for automated validation.

## Stop conditions

- `IMGBB_API_KEY` is still active in a release target, CI script, or distribution workflow.
- The proposed implementation requires adding `.imgbb` to `CloudProviderType` or changing cloud history/lifecycle/deletion schemas.
- Keychain migration cannot distinguish “missing” from “write failed,” or would delete the legacy value before a successful write.
- The Cloud view can only render the ImgBB section when generic storage is configured, preventing ImgBB-only setup.
- A requested export/import behavior requires changing the existing `.notinhascloud` schema; stop and propose a separate archive plan.
- Any test, diagnostic, fixture, screenshot, or documentation change would persist a real API key or upload user data.
- Existing generic Cloud upload/history tests regress for reasons attributable to this change.

## Test plan

- Add deterministic configuration-store tests for Keychain-first reads, legacy UserDefaults migration, failed migration preservation, clear behavior, and masked display. Use injected storage/test doubles; do not exercise a real account or real API key.
- Keep `NotinhasImgBBUploadServiceTests` for HTTP request/response mapping and extend only if the shared configuration seam needs a compile-safe integration assertion.
- Run `CloudCoreTests` to prove provider signing, encrypted storage credential transfer, and lifecycle behavior remain unchanged.
- Run the localization verifier, focused tests, default build, and full default suite.
- Perform the manual Cloud/Annotate/Quick Access checklist in Step 6.

## Done criteria

- [ ] ImgBB configuration is visible only in Preferences → Cloud; Annotate Preferences has no duplicate key field.
- [ ] ImgBB is clearly labeled as external image sharing and is not added to `CloudProvider`, provider selection, Cloud Upload History, expiration, deletion, or usage stats.
- [ ] New ImgBB key writes use Keychain; legacy UserDefaults data migrates safely and remains recoverable when Keychain writes fail.
- [ ] The build-time `IMGBB_API_KEY` fallback is removed only after the active-injection audit passes.
- [ ] Annotate and Quick Access manual ImgBB uploads still work from the shared configuration and preserve link-copy feedback.
- [ ] Generic Cloud storage reset does not silently clear ImgBB; ImgBB clear is explicit.
- [ ] Operational localization remains under Annotate; configuration localization is owned by Cloud and CatalogTool passes.
- [ ] Documentation describes the security, migration, network, portability, and Cloud-history boundaries accurately.
- [ ] Focused ImgBB/configuration tests, CloudCoreTests, default build, and full default tests pass, with any unrelated baseline failures recorded.

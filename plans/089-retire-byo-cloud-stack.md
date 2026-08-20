# Plan 089: Retire the BYO cloud upload stack

Executor: implementation agent in an isolated worktree, followed by a focused
reviewer. Work from baseline `ce23ea3471f7f367fe470f2983245711f4bdbe29` and
stop for drift before editing.

Status: TODO
Execution profile: implementer; High/Full; reviewer required; serialize this
plan with other changes touching Annotate, Preferences, Quick Access, or
configuration. No remote or Keychain deletion is authorized.

## Why

The ponytail audit found that the AWS S3, Cloudflare R2, and Google Drive BYO
upload stack duplicates the product's useful local clipboard/export flow and
ImgBB integration. The current request explicitly supersedes the retain-cloud
decision recorded in ADR 070. The optional Video module remains in scope as a
feature; only its cloud-upload affordances may be removed if required to keep
the gated build compiling.

## Current state

- `Notinhas/Services/Cloud/` mixes provider implementations, signing,
  multipart upload, OAuth, usage, password, credential transfer, upload
  history, and the local capture-history database.
- Active callers include Annotate, Capture, History, Quick Access, Preferences,
  app/deep-link routing, configuration import/export, and Video-gated code.
- `DatabaseManager.swift` is still required by capture history and must stay.
- `CloudKeychainStore.swift` must retain the ImgBB key path and any
  migration-only readers needed by `NotinhasIdentityMigrationService`.
- Existing local records, legacy configuration files, Keychain entries, and
  remote objects are user state. They must not be deleted as cleanup.

## Scope

Remove the active BYO cloud product surface and provider implementation:

1. Characterize every `CloudManager`, `CloudProvider`, provider-specific
   configuration, upload-history, usage, password, OAuth, S3/R2, and Google
   Drive caller before deleting anything.
2. Delete the provider core and provider-only tests, while retaining the local
   capture-history database, ImgBB credential adapter, and ImgBB behavior.
3. Remove the cloud upload action, menu/deep-link routes, Annotate and History
   cloud affordances, Quick Access cloud action, cloud upload history/usage,
   credential transfer/password UI, and provider-specific Preferences controls.
   Keep local save/copy/export and ImgBB upload.
4. Make persisted models and configuration tolerant of old cloud data: old
   `[cloud]` keys may be ignored, and legacy `cloudURL`/`cloudKey` fields may
   remain migration-only until Codable compatibility is proven. Do not erase
   those fields or remote objects automatically.
5. Remove dead localization and documentation, retain a concise ImgBB/local
   sharing description, and mark ADR 070 superseded by this decision. Update
   `docs/MIGRATION.md` with the non-destructive migration behavior.

Likely deletion candidates (confirm each has no non-ImgBB owner first) include
`AWSV4Signer.swift`, `CloudConfiguration.swift`,
`CloudCredentialTransferModels.swift`, `CloudCredentialTransferService.swift`,
`CloudManager.swift`, `CloudPasswordService.swift`, `CloudProvider.swift`,
`CloudUploadHistoryStore.swift`, `CloudUploadRecord.swift`, `CloudUsageInfo.swift`,
`CloudUsageService.swift`, `GoogleDriveCloudProvider.swift`,
`GoogleDriveOAuthService.swift`, `LifecycleXMLParser.swift`,
`R2CloudProvider.swift`, `S3CloudProvider.swift`, `S3MultipartUploader.swift`,
and cloud-only `Data+MD5.swift`. Do not delete shared database/keychain/ImgBB
files merely because they are in the same directory.

## Steps and verification

1. Re-run the caller map and inspect persisted model/configuration decoding.
   Record any unexpected owner and stop before widening the scope.
2. Remove provider code and provider-only tests. Keep database, ImgBB, and
   migration compatibility code. Verify no active provider type remains.
3. Remove UI/actions/routes and simplify Preferences to ImgBB. Verify the
   default Quick Access list contains no BYO cloud action and local history
   actions still compile.
4. Remove provider config emission and make import tolerant of legacy keys.
   Add or retain focused Codable/config tests for old input and current output.
5. Prune unused strings and update `docs/CLOUD.md`, `docs/ANNOTATE.md`,
   `docs/QUICK_ACCESS.md`, `docs/HISTORY.md`, `docs/POST_CAPTURE.md`,
   `docs/VIDEO_EDITOR.md`, `docs/PREFERENCES.md`, `docs/STRUCTURE.md`,
   `docs/APP_LIFECYCLE.md`, `docs/MIGRATION.md`, and ADR 070 as applicable.
6. Review the diff for accidental secret logging, Keychain deletion, remote
   deletion, or unrelated Video feature changes.

## Validation

Run from the implementation worktree, using the repository delivery workflow:

```text
./scripts/verify-local.sh --base ce23ea34 --full --plan-only --strict
make format-check
make lint-changed
make agent-check
make build
make test
make build-video
make test-video
```

Manual gates: open Preferences and configure ImgBB; upload from Annotate and
Quick Access to ImgBB; copy/save locally; open and delete a History item; verify
old configuration input does not fail launch; verify no BYO cloud action,
history, or credential-transfer surface remains. Video checks cover cloud
affordance removal only, not redesign or deletion of the Video module.

## Done criteria

- Only local sharing/export and ImgBB remain user-visible.
- No active AWS S3, R2, Google Drive, OAuth, cloud-usage, cloud-password, or
  cloud-upload-history path remains.
- Capture history, legacy decoding, ImgBB credentials, and migration readers
  remain intact.
- Default and Video builds/tests plus the focused gates pass.
- No remote object, Keychain item, or user configuration file is deleted.
- ADR/docs describe the new boundary and the implementation/review handoff
  records the commands and manual checks.

## STOP conditions

Stop and report if removing a cloud type breaks identity migration, old local
record decoding, capture history, or the ImgBB path; if a remote/Keychain
deletion is proposed; if a provider is still needed by a non-cloud feature; or
if the change requires deleting the Video module rather than only its cloud
affordance.


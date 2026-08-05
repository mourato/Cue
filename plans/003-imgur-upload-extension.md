# Plan 003: Upload Notinhas output to Imgur

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, report it; do not improvise. Update this plan's row in
> `plans/README.md` only after the code-review gate passes.
>
> **Drift check (run first)**: `git diff --stat bad6da2..HEAD -- Snapzy/Features/Notinhas Snapzy/Features/Annotate Snapzy/Features/QuickAccess Snapzy/Features/Preferences Snapzy.xcodeproj Snapzy/Resources/Info.plist SnapzyTests/Features/Notinhas SnapzyTests/Features/QuickAccess Snapzy/Resources/Localization`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/002-notes-export-composition.md`
- **Category**: direction
- **Planned at**: commit `bad6da2`, 2026-07-20

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — it consumes Plan 002's final composition and adds
  UI actions on two existing surfaces.
- **Reviewer required**: yes — external network transfer, configuration
  hygiene, cancellation, and user feedback need independent scrutiny.
- **Rationale**: It introduces a remote API boundary and must not leak into
  Snapzy's configured cloud-provider model.
- **Escalate when**: Imgur requires OAuth/account upload, server-side secrets,
  background transfer persistence, or a change to App Sandbox entitlements.

## Why this matters

The fastest handoff is a final annotated image plus a URL already on the
clipboard. Anonymous Imgur upload provides that without asking the user to
configure S3, R2, or Google Drive. It must remain a Notinhas-specific adapter
so it does not alter the semantics, credentials, or history of Snapzy's cloud
providers.

## Current state

- `QuickAccessActionKind` currently exposes configurable actions, including
  `uploadToCloud`; `QuickAccessCardView` renders and performs them.
- `AnnotateExporter.renderFinalImage` is the single final-image source after
  Plan 002, including a Notes panel when one exists.
- `CloudManager` is configured-account storage for S3/R2/Google Drive and must
  not be extended for anonymous Imgur.
- Imgur's official API allows anonymous image upload with a registered
  application Client ID in `Authorization: Client-ID <id>`; the app must not
  commit any credential or configuration value.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `./scripts/format.sh` | SwiftFormat exits 0 |
| Tests | `./scripts/run-tests.sh` | `success: Tests passed.` |
| Build | `xcodebuild -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug build` | `** BUILD SUCCEEDED **` |
| Run | `./scripts/build_and_run.sh` | `Snapzy Debug` launches |

## Scope

**In scope**

- `Snapzy/Features/Notinhas/Services/ImgurUploadService.swift` plus request,
  response, configuration, and test fakes.
- Thin Annotate and Quick Access action adapters, new Quick Access action
  identifier/configuration UI, user feedback, and localization strings.
- A non-secret build-setting/configuration contract for `ImgurClientID` and
  contributor documentation explaining how an operator injects it locally.
- XCTest coverage under `SnapzyTests/Features/Notinhas/` and Quick Access
  configuration/action tests.

**Out of scope**

- OAuth, Imgur account management, upload history/deletion, albums, retries
  across relaunch, and changes to `CloudManager`/S3/R2/Google Drive.
- Committing a Client ID, secret, token, or personal image URL to the repo.

## Steps

### Step 1: Establish a non-secret configuration boundary

Add an `ImgurClientID` Info.plist/build-setting lookup used only by the
Notinhas adapter. Document an untracked local `.xcconfig` or Xcode build
setting setup; add only a placeholder/example file if needed. Do not put any
real configuration value in source, tests, plans, or committed build settings.
If the value is missing or blank, expose an unavailable state with a clear
message explaining that a local Imgur Client ID must be configured.

**Verify**: `xcodebuild -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug build` →
`** BUILD SUCCEEDED **` with no credential value committed (`git diff --check`).

### Step 2: Implement the anonymous Imgur adapter

Create a small `ImgurUploadService` under `Features/Notinhas/Services`, with a
protocol injectable into tests. Encode the final PNG/JPEG image as multipart or
base64 according to the current official `/3/image` endpoint contract, use the
Client-ID authorization header, validate HTTP status and API success, and
return only the canonical share URL plus deletion metadata needed for this
request (do not persist deletion metadata in v1). Map transport, malformed
response, unauthorized, rate-limit, and missing-configuration cases to
localized actionable errors. Run network work off the main actor and make a
user cancellation leave the image and Notes session unchanged.

**Verify**: `./scripts/run-tests.sh -only-testing:SnapzyTests/Features/Notinhas/ImgurUploadServiceTests` →
mocked success and each error mapping pass without network access.

### Step 3: Add editor and Quick Access entry points

Add `Upload to Imgur` to the Annotate action area. It renders through the same
`AnnotateExporter.renderFinalImage` path as copy/save, uploads that result,
copies the returned URL, and presents progress/success/failure feedback.

Add `uploadToImgur` as a separate Quick Access action; do not overload
`uploadToCloud`. Make it enabled and assigned to the default trailing upload
slot, while leaving the generic cloud action available in the configurable
action list/context menu for users who use it. For a Quick Access item with an
editable annotation session, render its latest committed session through the
same final compositor; otherwise upload the capture file. Pause the item's
auto-dismiss countdown while the request is active and restore it on every
terminal outcome, following the existing cloud-upload behavior.

**Verify**: `./scripts/run-tests.sh -only-testing:SnapzyTests/Features/QuickAccess/QuickAccessCoreTests` →
the new action is persisted/configurable and existing action ordering tests pass.

### Step 4: Localize, document, and perform mandatory code review

Add user-facing strings for the action, progress, successful link copy,
configuration-needed, cancellation, and API errors. Update the Notinhas
section of `AGENTS.md` or a focused feature document with the local Client-ID
setup and the fact that anonymous uploads are public share links; never claim
privacy or account ownership.

Have a reviewer inspect the full diff. Confirm: no credential was committed;
the Notinhas service is not wired into `CloudManager`; upload always uses the
Plan 002 final composer; errors never silently discard an image; Quick Access
countdown resumes; cancellation and missing configuration are handled; and
network tests use a fake URL session rather than the live service.

**Verify**: `git diff --check && ./scripts/run-tests.sh` → no whitespace
errors and `success: Tests passed.`

## Test plan

- Adapter tests with a mocked session: valid success URL, malformed JSON,
  non-success API body, 401/429/5xx, cancellation, and absent configuration.
- Action tests: editor passes a rendered Notes image; Quick Access chooses a
  committed rendered session when present and raw capture otherwise; success
  copies the returned link.
- Manual macOS test with a disposable registered Client ID: upload a plain
  capture and a three-style Notes composition from both surfaces; confirm the
  browser URL shows the exact exported image and the link is in the clipboard.

## Done criteria

- [ ] No client ID, secret, token, or private URL is committed.
- [ ] Missing configuration disables/fails the action with setup guidance.
- [ ] Editor and Quick Access upload the same final image used by copy/save.
- [ ] Success copies the Imgur URL; every failure preserves the source image
  and shows an actionable localized message.
- [ ] Full XCTest suite and Debug build pass.
- [ ] Mandatory code review completed and the README status is updated.

## STOP conditions

- Official Imgur API terms or endpoint behavior require OAuth for anonymous
  uploads, or require a secret that cannot safely exist in a desktop app.
- A Quick Access annotated item cannot be rendered from its session without
  reopening the editor or changing the image permanently.
- The only integration path is to persist anonymous upload credentials in the
  existing Cloud Keychain store.

## Maintenance notes

Keep Imgur request/response code entirely inside `Features/Notinhas`. If a
future release adds account uploads or deletion history, create a distinct
plan: it changes privacy, persistence, and security scope. Revalidate the
official Imgur API documentation before changing endpoint fields or headers.

# Plan 097: Add direct ImageKit upload and provider selection

> **Executor instructions:** execute this plan in order. This is an implementation
> brief, not permission to broaden the product. If a stop condition occurs,
> stop, record the evidence, and return for a decision instead of improvising a
> server, dependency, migration, or fallback.

## 1. Delivery contract

**Objective:** add ImageKit as an optional direct image-upload provider for the
personal macOS app, while preserving ImgBB behavior and introducing the smallest
shared provider-selection seam needed by UploadThing.

**Observable outcome:** a user can select ImageKit in Preferences → Uploads,
store the ImageKit private key in Keychain, trigger an explicit upload from
Annotate or Quick Access, receive a public ImageKit URL, and copy that URL to
the clipboard. A user who does nothing keeps the existing ImgBB behavior.

**In scope:**

- ImageKit provider model and selected-provider persistence.
- ImageKit credential storage and configuration UI.
- Direct ImageKit Upload File V1 request through `URLSession`.
- Coordinator routing for ImgBB and ImageKit.
- Dynamic provider name/status in Annotate and Quick Access.
- Localized errors and success/progress copy.
- Focused unit tests, manual checks, and affected documentation references
  needed to keep the implementation handoff accurate.

**Out of scope:**

- Any Notinhas server, serverless function, proxy, authentication endpoint,
  webhook, background worker, or hosted configuration.
- Public or multi-user distribution security.
- ImageKit transformations, folders, tags, metadata workflows, file listing,
  deletion, history, private-file delivery, signed delivery URLs, or video/GIF
  uploads.
- Automatic upload, automatic retry, cross-provider fallback, telemetry, or
  upload-history persistence.
- UploadThing implementation; it is Plan 098.
- Broad renaming of legacy `uploadToImgBB` persisted action identifiers.
- Reintroducing the retired S3, R2, or Google Drive cloud stack.

**Constraints:**

- The project is a personal local macOS application with no server and no
  intention to pay for one.
- Direct use of a provider secret in a local app is accepted only because the
  account belongs to the local user. It is not an acceptable design for a
  distributed product with other users.
- Secrets must remain in Keychain and must never be written to UserDefaults,
  TOML, diagnostics, tests, logs, clipboard, or UI text beyond a masked
  summary.
- Upload happens only after an explicit user action.
- Existing ImgBB migration and persisted action decoding must remain intact.
- Reuse the existing image encoder, clipboard path, `URLSession`, Foundation,
  and Keychain infrastructure. Do not add a package for multipart encoding or
  HTTP.

**Acceptance:**

- [ ] ImageKit can be selected and configured without changing the existing
      ImgBB default.
- [ ] A valid encoded image produces the `url` returned by ImageKit and that
      URL reaches the existing clipboard/success path.
- [ ] Missing, malformed, unauthorized, offline, and non-2xx responses produce
      safe, user-visible errors without leaking secrets or image data.
- [ ] Annotate and Quick Access use the same selected provider and configured
      state; they do not each maintain an independent provider choice.
- [ ] Existing `uploadToImgBB` raw values continue to decode and existing ImgBB
      users remain functional.
- [ ] Focused tests and repository gates pass, with manual network/UI checks
      recorded separately.

**Validation:**

- Focused provider, credential, provider-selection, and coordinator tests.
- `make format-check`.
- `make lint-changed`.
- `make agent-check`.
- `./scripts/verify-local.sh --base 346857f4 --execute --strict`.
- Manual Preferences, Annotate, Quick Access, clipboard, offline, and clear
  credential checks.

**Integration:** implementation worktree and branch according to
`core/policies/worktrees.md`; local `main` only after review and explicit merge
authorization. No push is authorized by this plan.

**Stop conditions:** see Section 13. Any unresolved stop condition blocks the
handoff.

**Handoff:** report changed files, exact commands/results, manual checks,
known baseline failures, security risks, and whether the implementation is
implemented, reviewed, merged locally, pushed, or validated on `main`.

## 2. Status and execution profile

- **Priority:** P1
- **Effort:** M/L
- **Risk:** MED-HIGH
- **Depends on:** none
- **Category:** direction / security / tech-debt
- **Planned at**: commit `346857f4`, 2026-08-20
- **Publication:** local plan
- **Recommended executor:** implementer
- **Risk lane:** Medium/Full
- **Parallelizable:** no. Provider selection, Keychain state, coordinator
  routing, and both upload surfaces must share one contract.
- **Reviewer required:** yes. This changes outbound network behavior and secret
  storage.

The plan is intentionally the first provider plan because it establishes the
shared seam that Plan 098 extends. Do not prematurely design a generic cloud
framework: two direct image adapters and one small routing choice are enough.

## 3. Product and security boundary

### 3.1 Why ImageKit is being added

ImgBB is currently the only explicit image-sharing provider and is reported as
slow. The app already performs the expensive work locally: it composes the
annotated image, applies upload encoding settings, and copies the resulting URL.
ImageKit should replace only the remote upload step.

The desired architecture is:

```text
Annotate / Quick Access
        │ explicit user action
        ▼
NotinhasUploadCoordinator
        │ encode off MainActor
        ▼
selected provider adapter
        │ direct HTTPS request
        ▼
ImageKit or ImgBB public URL
        │
        ▼
existing success/toast/clipboard flow
```

### 3.2 Personal-only credential exception

ImageKit's Upload File V1 API uses account credentials. This plan assumes the
user is the sole operator of the local app and owns the ImageKit account. The
private key is therefore read from the local Keychain at the moment of the
explicit upload.

This does not make the private key safe for distribution. A packaged app can be
inspected, the local user's Keychain can be accessed by the local user, and a
secret embedded in a multi-user client would expose the owner's account. If the
app is ever distributed to other people, stop and redesign around a trusted
backend or another provider flow whose client credential is explicitly safe.

### 3.3 Public-link implications

The returned link is intended for visual handoff and can be shared with anyone
who receives it. Do not describe this feature as private storage, encrypted
storage, access-controlled delivery, or automatic cleanup. Do not persist a
delete token or remote file identifier just to support a future feature.

Provider plan limits, pricing, retention, and terms are external state. Do not
hard-code current free-plan numbers into Swift. Link to the official plan page
in documentation and ask the implementer to verify the account's current limits
before a real upload.

## 4. Official contract to freeze before coding

Read the official ImageKit Upload File V1 reference immediately before
implementation:

- API reference: <https://imagekit.io/docs/api-reference/upload-file/upload-file>
- Plans: <https://imagekit.io/plans>

The planned endpoint is:

```text
POST https://upload.imagekit.io/api/v1/files/upload
```

Before writing the adapter, confirm from the official reference:

- current endpoint and API version;
- authentication format and which credential is allowed for this operation;
- multipart field name for the image data;
- required/optional filename and MIME metadata;
- success response field containing the durable public URL;
- error response shape and whether error bodies contain sensitive data;
- maximum file size relevant to the chosen upload derivative;
- whether a plain public URL is the intended result for this account setup.

Use Upload File V1. Do not switch to an undocumented endpoint, the V2 beta
path, an SDK copied from another language, or a client-side authentication flow
without updating this plan and its stop/approval boundary.

## 5. Current repository state

Inspect these files before editing; line numbers are a starting map and may move:

| Surface | Current responsibility | Planned change |
|---|---|---|
| `Notinhas/Features/Notinhas/Services/NotinhasUploadCoordinator.swift` | `@MainActor` coordinator; encodes images detached and calls only ImgBB | route to selected provider while retaining encoding and published state |
| `Notinhas/Features/Notinhas/Services/NotinhasUploadSettings.swift` | shared upload encoding settings and derivative generation | reuse unchanged unless a compile-only adaptation is required |
| `Notinhas/Features/Notinhas/Services/NotinhasImgBBUploadService.swift` | existing direct ImgBB adapter and result/error behavior | preserve; align only at the smallest shared URL boundary |
| `Notinhas/Services/Cloud/CloudKeychainStore.swift` | shared Security API and `CloudKeychainItem` enum | add one ImageKit item; preserve legacy cases |
| `Notinhas/Services/Cloud/NotinhasImgBBCredentialStore.swift` | ImgBB Keychain storage and legacy UserDefaults migration | preserve migration; extract/reuse only if it reduces duplication without changing behavior |
| `Notinhas/Features/Preferences/Components/PreferencesCloudSettingsView.swift` | one ImgBB SecureField and state machine | add provider selection and provider-specific credential state |
| `AnnotateBottomBarView.swift` | ImgBB-specific availability, labels, upload call, progress/error UI | derive displayed provider and credential state from shared configuration |
| `QuickAccessCardView.swift` | repeated ImgBB-specific state and upload handler | use the same shared provider state and coordinator contract |
| `QuickAccessActionKind.swift` | persisted `.uploadToImgBB` action | preserve raw case/value for compatibility; change display semantics only |
| `AnnotateChromeItem.swift` | persisted ImgBB-named bottom action | preserve raw case/value and existing decode compatibility |
| `Notinhas/Shared/Localization/L10n.swift` | ImgBB-specific labels/errors | add provider-neutral strings plus provider names where useful |
| matching `NotinhasTests/` files | ImgBB service/configuration/encoder/persistence tests | add ImageKit and shared-state coverage |

Also inspect callers before changing the coordinator. Do not patch only the
visible button: the same coordinator state can be observed by multiple views.

## 6. Proposed smallest data model

### 6.1 Provider identity

Add a small `NotinhasUploadProvider` value, likely an enum, with:

```swift
enum NotinhasUploadProvider: String, CaseIterable, Identifiable {
    case imgbb
    case imageKit
}
```

The exact location should follow the current feature/service organization. Keep
it image-upload-specific; do not call it `CloudProvider`, because the retired
generic cloud subsystem must not be revived through naming.

Required behavior:

- stable raw values for UserDefaults;
- `imgbb` as the default when no value exists;
- invalid stored values fall back to `imgbb` without crashing;
- display name and short explanation are localized or routed through the
  existing localization convention;
- provider selection is configuration, not a secret.

Proposed key: use the repository's existing `PreferencesKeys` convention, for
example `uploadProvider`. Confirm the exact naming convention before adding it.

### 6.2 Credential ownership

Add an ImageKit-specific credential store following the proven ImgBB pattern:

- read/write/delete through `CloudKeychainStore`;
- trim whitespace before save;
- reject an empty key before touching Keychain;
- publish a cached `isConfigured` flag after init/save/clear/reload;
- expose only a masked summary to the UI;
- keep the secret out of UserDefaults and configuration export;
- do not use a single generic dictionary that makes it easy to mix provider
  credentials.

Proposed Keychain item account:

```text
com.mourato.notinhas.cloud.imagekitPrivateKey
```

Confirm naming against the existing `CloudKeychainItem` account convention. Add
no legacy accounts because there is no existing Notinhas ImageKit migration.

### 6.3 Shared configuration publication

Annotate and Quick Access must observe one source of truth. The shared state
should publish:

- selected provider;
- whether the selected provider is configured;
- a revision/change signal if the existing architecture needs one to invalidate
  cached UI state.

It must not publish the raw credential as an observable property. When the
selected provider changes, the upload action should immediately reflect the
new provider's configured state. A missing selected-provider credential must
disable or explain upload rather than silently falling back to ImgBB.

## 7. Implementation steps

### Step 0 — preflight and worktree

1. Confirm the worktree is isolated according to the repository policy.
2. Run `git status -sb` and record unrelated changes before editing.
3. Read the current ImageKit reference and freeze the request facts in the
   implementation handoff.
4. Inspect the existing upload service, coordinator callers, Keychain tests,
   localization, and both UI paths.
5. Confirm no new entitlement or package is required. The existing
   `com.apple.security.network.client` entitlement should cover explicit HTTPS
   client traffic; there must be no `network.server` entitlement.

**Checkpoint:** if the official API requires a server-side signing/auth step,
stop before modifying source.

### Step 1 — add provider identity and configuration

Implement the provider model and selected-provider persistence using the
existing preferences conventions.

Required details:

- preserve ImgBB as the default for upgrades and fresh installs unless the user
  explicitly chooses ImageKit;
- do not infer ImageKit merely because an ImageKit key exists;
- clearing ImageKit's credential must not clear ImgBB's credential;
- switching providers must not delete or migrate the other provider's key;
- selected provider is safe to include in nonsecret configuration only if the
  existing TOML format supports it; if not, keep it local and document why;
- invalid persisted values recover to ImgBB and should be covered by a test.

**Checkpoint:** provider/configuration tests pass before wiring network calls.

### Step 2 — add ImageKit Keychain storage

Extend `CloudKeychainItem` with the ImageKit account and add a dedicated
credential store/protocol seam suitable for unit tests.

Match current semantics:

- read Keychain first;
- normalize whitespace to absent;
- save trimmed value;
- clear only the ImageKit item;
- preserve Keychain fallback/error handling from `CloudKeychainStore`;
- do not log the raw value on read/write failure;
- make `isConfigured` a cached state so SwiftUI body recomputation does not
  synchronously hit `securityd` on every unrelated update.

Test cases:

1. existing Keychain value is read and masked;
2. missing value is unconfigured;
3. whitespace-only value is unconfigured;
4. save trims and stores the value;
5. empty save fails without mutation;
6. clear removes only ImageKit;
7. Keychain write failure becomes a safe localized error;
8. reload refreshes configured state.

### Step 3 — implement the ImageKit adapter

Create a focused actor, for example:

```text
Notinhas/Features/Notinhas/Services/NotinhasImageKitUploadService.swift
```

Keep the service responsible only for one upload request and response parsing.
It should accept the already encoded `NotinhasEncodedImage` and a credential
passed from the coordinator. It must not know about SwiftUI, clipboard, toast
presentation, capture history, or Keychain UI.

Request construction:

- use `URLRequest` and the existing `URLSession` style;
- `POST` the official upload URL;
- create a cryptographically unique multipart boundary;
- include the image data under the provider-documented `file` field;
- include a safe generated filename, not the user's local path;
- use `NotinhasEncodedImage.contentType` and file extension consistently;
- add only headers required by the official contract;
- authenticate exactly as documented, without putting the private key in the
  URL, query string, logs, or error text;
- use a finite request timeout consistent with existing network behavior;
- do not add automatic retries because a retry may create a second remote file.

Response handling:

- accept only the expected 2xx success range;
- decode the documented JSON response into a private `Decodable` type;
- extract and validate a nonempty absolute `url`;
- reject a missing, empty, malformed, or non-HTTPS URL unless the official
  contract explicitly permits another scheme;
- map non-2xx status, transport errors, invalid JSON, and missing URL to typed
  errors;
- keep provider diagnostic text bounded and sanitized;
- never include authorization headers, private key, image bytes, local path, or
  full response body in logs.

Suggested error categories (adapt to current naming):

- missing credential;
- invalid image/empty encoded data;
- transport failure;
- unauthorized/forbidden;
- rate limited/quota exceeded;
- provider rejection/non-2xx;
- malformed response;
- missing public URL;
- cancelled.

Do not prematurely force ImgBB and ImageKit into a large common error enum if
the existing code uses provider-specific errors. A small shared result of
`String`/URL is sufficient at the coordinator boundary.

### Step 4 — generalize the coordinator

The current coordinator is `@MainActor`, owns upload state, performs image
encoding in `Task.detached`, and calls only `NotinhasImgBBUploadService`.
Preserve that behavior.

Change the smallest possible seam so both upload entry points can:

1. snapshot the `NSImage` or file URL;
2. load current upload encoding settings;
3. encode off MainActor;
4. select the configured provider;
5. load only the selected provider's credential;
6. call the selected direct adapter;
7. publish `isUploading`, `lastUploadedURL`, and `lastErrorMessage` on MainActor;
8. return the URL to the existing caller.

Avoid these designs:

- a factory protocol with one call site and no meaningful substitution;
- a generic cloud manager containing provider-specific credential rules;
- passing `Any`, dictionaries, or raw provider names through every view;
- putting Keychain reads in SwiftUI body properties;
- moving image encoding back onto MainActor;
- changing public behavior for video/GIF uploads.

If the current `apiKey: String` parameter becomes misleading, replace it with
the smallest provider-aware input that keeps the credential out of the view.
Do not expose secrets through `@Published` state.

### Step 5 — update Preferences

Extend `CloudSettingsView`/`PreferencesCloudSettingsView` with:

- a provider picker containing ImgBB and ImageKit;
- provider-specific description and credential label;
- masked configured state;
- edit/save/cancel/reset behavior;
- safe error alert for Keychain failures;
- an explicit personal-use explanation that the credential stays in Keychain;
- no raw secret prefilled into an ordinary `Text` view;
- no secret included in export/import controls.

State behavior matrix:

| Selected provider | Credential state | UI behavior |
|---|---|---|
| ImgBB | missing | show ImgBB field and setup explanation |
| ImgBB | configured | show masked value, Edit, Remove |
| ImageKit | missing | show ImageKit private-key field and setup explanation |
| ImageKit | configured | show masked value, Edit, Remove |
| either | save error | preserve editable input locally, show safe error |
| either | provider switched while editing | do not save the old field into the new provider |

When switching providers, clear only transient field state or explicitly keep it
scoped to the provider; never cross-save a credential.

### Step 6 — update Annotate and Quick Access

Replace ImgBB-only availability reads with the shared selected-provider state.
The existing action identifiers remain for persisted compatibility, but their
display label and accessibility value should name the selected provider.

For both surfaces verify:

- configured provider shows the upload action;
- missing selected-provider credential shows the existing disabled/setup path;
- progress text says the selected provider, or uses provider-neutral text if
  that is the established UX choice;
- success text says the selected provider and copied-link result;
- error text names the selected provider only when useful;
- the final Annotate composition is uploaded, not the pre-annotation source;
- Quick Access uses the existing encoded-file flow;
- URL is copied through the existing clipboard path;
- in-flight state prevents duplicate clicks according to current behavior;
- video/GIF paths remain disabled or unchanged;
- no upload occurs simply because a card/window appears.

Check both light/dark appearance and accessibility labels. Use the existing
native SwiftUI patterns; do not introduce a new settings architecture.

### Step 7 — localization and compatibility

Replace hard-coded or misleading ImgBB-only generic errors with provider-neutral
messages where possible. Keep provider names as proper names where that makes
the error actionable.

Review all affected `L10n` entries and translations. At minimum cover:

- provider name/description;
- missing credential;
- invalid image;
- upload in progress;
- upload failed;
- success/link copied;
- Keychain save/read failure;
- remove/reset action;
- personal credential/storage explanation.

Do not rename persisted localization keys or raw action values solely for
cosmetic reasons if existing migrations/tests rely on them.

### Step 8 — focused review before broad validation

Review the diff for:

- raw secrets in source, fixtures, snapshots, logs, or error strings;
- accidental `UserDefaults`/TOML credential writes;
- provider fallback when the selected credential is absent;
- duplicate upload triggers;
- MainActor image encoding regressions;
- new entitlements/packages;
- changes to retired cloud code;
- broken decoding of old action/configuration values;
- ImgBB behavior changes not required by the shared seam.

## 8. Test matrix

### 8.1 ImageKit service tests

Create tests beside `NotinhasImgBBUploadServiceTests.swift`, using the existing
`URLProtocol` mocking pattern and an ephemeral `URLSession`.

Required cases:

| Case | Assertion |
|---|---|
| blank credential | typed missing-credential error; no request |
| empty image data | typed image error; no request |
| happy path | endpoint, POST, multipart content, auth presence, URL parsing |
| filename/MIME | safe filename and encoded content type are present |
| 401/403 | maps to authorization-safe error; key is absent from message |
| 429/quota | maps to retry-later/quota error if status is distinguishable |
| other non-2xx | maps to provider error without dumping body |
| invalid JSON | malformed-response error |
| missing URL | missing-public-URL error |
| invalid URL | malformed/missing URL error |
| transport failure | transport error preserved safely |
| cancellation | cancellation is not turned into success |

Assert request structure without asserting the literal secret. If inspecting
Basic Auth in a test, assert that the header exists and decodes to the expected
shape using a fixture-only value, then do not print it in a failure message.

### 8.2 Credential and provider-state tests

- Keychain read/save/clear/reload and masking;
- empty and whitespace normalization;
- provider default and invalid-value recovery;
- provider persistence across a new store instance;
- switching does not mutate either credential;
- selected provider's configured state drives the shared observable state;
- no provider secret appears in exported configuration.

### 8.3 Coordinator and regression tests

- ImgBB success remains unchanged;
- ImageKit success reaches the same URL result path;
- selected-provider failure reaches `lastErrorMessage` and resets
  `isUploading`;
- encoding failures still happen before the network request;
- `lastUploadedURL` is not replaced by a failed attempt;
- persisted Quick Access and Annotate action raw values still decode;
- existing encoder tests remain green.

### 8.4 Commands

Before any build/test/lint/validation command, load the repository's
`delivery-workflow` skill and its Notinhas overlay.

```text
./scripts/run-tests.sh \
  -only-testing:NotinhasTests/Features/Notinhas/NotinhasImgBBUploadServiceTests \
  -only-testing:NotinhasTests/Features/Notinhas/NotinhasImageKitUploadServiceTests \
  -only-testing:NotinhasTests/Features/Notinhas/NotinhasImgBBConfigurationTests

make format-check
make lint-changed
make agent-check
./scripts/verify-local.sh --base 346857f4 --execute --strict
```

Use quiet tests. Do not enable visual/audio integration flags for the automated
suite.

## 9. Manual verification

Perform with a test image that contains no sensitive information, using the
user's own ImageKit account:

1. Open Preferences → Uploads.
2. Confirm ImgBB remains selected by default on an existing installation.
3. Select ImageKit and save the private key.
4. Confirm the UI shows only a masked Keychain summary after save.
5. Upload the final image from Annotate.
6. Confirm progress, success, copied URL, and that the URL opens.
7. Upload a Quick Access screenshot and confirm the same result.
8. Switch to ImgBB and confirm its credential/action still works.
9. Clear ImageKit and confirm only ImageKit becomes unavailable.
10. Attempt upload without ImageKit configuration and confirm no remote request
    is attempted and the setup error is understandable.
11. Test invalid credentials, offline mode, cancellation if reproducible, and
    a large/optimized image.
12. Repeat the relevant UI checks in Light and Dark appearance.
13. Inspect exported configuration and diagnostics; confirm no secret appears.

Record provider account/region/date only as nonsecret test metadata. Never put
the key, response body, or private screenshot in the repository.

## 10. Evidence mapping

| Invariant | Implementation owner | Evidence |
|---|---|---|
| ImgBB remains default/backward-compatible | provider store, raw action decoders | provider-state tests; existing Quick Access/configuration tests |
| ImageKit secret is Keychain-only | credential store, configuration exporter boundary | credential tests; export assertion; diff review |
| direct endpoint returns validated URL | ImageKit actor | URLProtocol service tests; manual real-account upload |
| no secret/image/path logging | adapter errors, logging review | targeted test assertions; source/diff review |
| encoding stays off MainActor | coordinator/task boundary | existing encoder tests; concurrency review |
| both UI surfaces share state | shared provider configuration | state tests; Annotate and Quick Access manual check |
| no automatic/fallback upload | action handlers/coordinator | manual missing-credential/offline checks; diff review |

## 11. External-state addendum

**Authority:** the user's local Keychain is authoritative for the ImageKit
credential; the selected-provider UserDefaults value is authoritative for
which adapter is used; ImageKit is authoritative for the existence and URL of
the remote uploaded file.

**Identity:** Keychain identity is the stable account string
`com.mourato.notinhas.cloud.imagekitPrivateKey` under the existing Keychain
service. A remote upload is identified by the provider response, but this plan
does not persist a remote identifier.

**Scope:** read/write/delete only the ImageKit credential item; issue one remote
upload for one explicit user action; do not list, delete, rename, or mutate
other provider/account files.

**Preflight:** verify selected provider and configured state; validate nonempty
encoded data; verify endpoint/auth contract against official docs before coding;
verify no secret is in export/logging paths.

**Idempotency:** no provider idempotency guarantee is assumed. Do not retry an
upload automatically. A user retry may create a second remote object and this
is acceptable for the initial personal workflow; document it rather than
pretending the operation is idempotent.

**Failure:** do not clear a credential because a network request fails; retain
the last successful URL; reset in-flight state; present a safe actionable error;
do not claim upload failure if a valid success response was received.

**Concurrency:** one visible upload at a time per coordinator according to the
existing UI state. Capture immutable encoded data and credential values before
each await. Ignore stale/cancelled results if the current coordinator has
changed state.

**Destructive actions:** clearing a Keychain credential requires the existing
explicit Remove/Reset action. There is no remote delete in this plan, so there
is no recovery/orphan cleanup implementation.

**Admission:** explicit Annotate/Quick Access action, selected provider
configured, valid encoded image, and no conflicting upload state.

**Execution:** preserve the encoded image, selected provider, and credential
snapshot across awaits; never reread mutable UI fields mid-request.

**Publication:** publish only the URL from the current successful operation;
publish errors only if no success has been published for that operation.

**Serialization:** serialize the Keychain mutation through the existing store;
do not add a global upload queue or cross-provider lock.

**Recovery:** after cancellation/timeout, leave the credential and previous
success intact and let the user explicitly retry.

## 12. Done checklist and handoff

- [ ] Official ImageKit contract was rechecked and recorded.
- [ ] Isolated worktree and baseline status were recorded.
- [ ] Provider selection and default behavior are tested.
- [ ] ImageKit credential is Keychain-only and masked in UI.
- [ ] ImageKit service has offline URLProtocol coverage.
- [ ] Coordinator routes both providers without moving encoding to MainActor.
- [ ] Annotate and Quick Access use selected-provider state.
- [ ] Legacy action/configuration values still decode.
- [ ] Localization is complete for changed visible states.
- [ ] Automated commands and results are recorded.
- [ ] Manual checks and unavailable checks are recorded.
- [ ] Review findings and remaining risks are recorded.

Handoff must state: changed surface, validation evidence, known baseline
failures, whether a real provider upload was performed, and the next action
(normally Plan 098).

## 13. STOP conditions

Stop immediately if:

- ImageKit requires a server-side signature/auth endpoint for the chosen flow.
- the implementation would expose this credential model to other users;
- a new package, entitlement, proxy, or server is needed;
- the endpoint/response contract cannot be verified in official docs;
- public URL/privacy semantics differ materially from this plan;
- a retry/fallback design is being added to hide provider failures;
- existing ImgBB migration, Quick Access persistence, or Annotate chrome
  decoding requires a destructive migration;
- the task touches video upload, history, remote deletion, or retired BYO cloud
  code;
- the same validation failure occurs twice without a documented correction;
- unrelated worktree changes conflict with the planned files.

## 14. Maintenance notes

Provider API contracts and free-plan limits can change. Keep the endpoint and
response shape isolated in one adapter and keep current external facts in
documentation links, not code comments that promise a permanent quota.

If Notinhas becomes distributable, this plan is no longer valid as a security
model. Revisit the architecture before adding onboarding or sharing the app.

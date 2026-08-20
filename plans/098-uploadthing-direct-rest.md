# Plan 098: Add direct UploadThing REST upload

> **Executor instructions:** this plan follows Plan 097. It is a feasibility
> gated implementation brief. UploadThing's ecosystem is server-oriented, so
> the first deliverable is proving that the current official REST contract can
> complete a direct desktop upload without a file router, callback, webhook, or
> Notinhas server. If that proof fails, stop and report; do not invent a bridge.

## 1. Delivery contract

**Objective:** add UploadThing as an optional direct REST image-upload provider
for the personal local app, reusing the provider/configuration seam established
by Plan 097 and without operating any server.

**Observable outcome:** after the official REST contract is frozen and verified,
the user can select UploadThing, store the personal API key/token in Keychain,
perform an explicit Annotate or Quick Access upload directly to UploadThing, and
copy a stable public URL. If the official contract cannot support that flow,
the correct outcome is a documented stop, not code.

**In scope:**

- UploadThing provider identity added to the shared image-provider model.
- UploadThing credential storage in Keychain.
- Provider-specific Preferences UI.
- One direct `URLSession`/Foundation adapter using the currently documented
  official REST/OpenAPI contract.
- Coordinator and dynamic UI integration from Plan 097.
- Focused offline tests for the exact selected request/response contract.
- Manual validation with a personal UploadThing account and a non-sensitive
  test image.

**Out of scope:**

- Any Notinhas server/serverless function, proxy, CORS setup, callback route,
  webhook, file router, or public endpoint.
- UploadThing JavaScript SDK, React helpers, server route handlers, or a custom
  Swift package.
- Resumable uploads, background upload queues, remote delete/rename/listing,
  usage dashboard, history, remote metadata management, or private-file
  delivery unless the direct public-link path itself requires documented
  metadata fields.
- Automatic retry, fallback to another provider, or silent provider switching.
- Changes to ImgBB/ImageKit behavior beyond the shared provider switch.
- Generic cloud storage abstractions or reintroduction of retired S3/R2/Drive
  functionality.

**Constraints:**

- Personal, local macOS app; no server and no server budget.
- The UploadThing API key/token remains in Keychain and is used only by this
  local account. This is not a multi-user distribution design.
- The public URL must be usable after the request completes; do not add an
  unbounded wait for asynchronous processing.
- The exact request contract must come from official UploadThing documentation
  or the official OpenAPI schema. Unofficial snippets are not evidence.
- Upload is explicit, one image at a time, and reuses the current encoded image
  derivative and clipboard behavior.
- Do not store remote file IDs simply because the API returns them.

**Acceptance:**

- [ ] An official, current, no-server REST flow is identified before coding.
- [ ] The flow returns a stable public URL or a documented deterministic way to
      obtain one within a bounded request sequence.
- [ ] UploadThing credential is Keychain-only and provider-scoped.
- [ ] The exact request, auth header, response parsing, and failure states are
      covered by offline tests.
- [ ] Annotate and Quick Access can use UploadThing through the shared provider
      state without changing ImgBB or ImageKit behavior.
- [ ] A real personal-account manual test either succeeds end-to-end or is
      recorded as the reason to stop and not ship this provider.

**Validation:**

- Official OpenAPI/documentation preflight.
- Focused UploadThing service and configuration tests.
- Existing provider regression tests.
- `make format-check`, `make lint-changed`, `make agent-check`, and
  `./scripts/verify-local.sh --base 346857f4 --execute --strict`.
- Manual provider configuration, upload, URL opening, credential clear, and
  offline/missing-credential checks.

**Integration:** implementation worktree/branch per repository policy; local
`main` only after review and explicit merge authorization. No push is authorized
by this plan.

**Stop conditions:** see Section 14. A failed feasibility gate is a valid final
result for this plan.

**Handoff:** record the exact official endpoint/version, request fields,
authentication scheme, response URL field, manual result, commands/results,
remaining risks, and whether Plan 099 can proceed.

## 2. Status and execution profile

- **Priority:** P2
- **Effort:** M, with a potentially zero-code outcome if the direct contract is
  not viable
- **Risk:** MED
- **Depends on:** Plan 097
- **Category:** direction / performance / external API feasibility
- **Planned at**: commit `346857f4`, 2026-08-20
- **Publication:** local plan
- **Recommended executor:** implementer with reviewer
- **Risk lane:** Medium/Full
- **Parallelizable:** no. This extends the provider/configuration contract and
  the exact REST contract controls the adapter design.
- **Reviewer required:** yes. The API is external, credentials are account
  scoped, and a two-step flow can create orphaned remote files.

## 3. Why this plan is deliberately gated

UploadThing's primary product model commonly involves a file router/backend
boundary, while the app has no server by design. A REST API may still provide a
direct path, but “there is an API” is not enough: the current endpoint must
accept the file from this desktop client, authenticate with the user's
credential, and return a durable URL without a callback owned by Notinhas.

The plan therefore has two possible valid outcomes:

1. **Implementable:** official current REST/OpenAPI flow passes the feasibility
   gate; implement one thin adapter.
2. **Not implementable under constraints:** official flow requires a server,
   file router, callback, or non-durable URL; leave UploadThing unimplemented,
   document the evidence, and keep ImageKit/ImgBB as the options.

Do not reinterpret the user's “no server” requirement to mean “a free serverless
function is acceptable.” It is not.

## 4. Official references and preflight contract

Read these official sources immediately before implementation:

- OpenAPI: <https://docs.uploadthing.com/api-reference/openapi-spec>
- Uploading files: <https://docs.uploadthing.com/uploading-files>
- v7 API: <https://docs.uploadthing.com/v7>
- UT API reference: <https://docs.uploadthing.com/api-reference/ut-api>
- Regions and ACL: <https://docs.uploadthing.com/concepts/regions-acl>
- Product/pricing: <https://uploadthing.com/>

The previously observed documentation exposes REST API material under
`https://api.uploadthing.com` and references operations such as
`POST /v6/uploadFiles` and `POST /v7/prepareUpload`. These names are planning
leads, not a frozen implementation contract. Verify them again because API
versions and request shapes can change.

### 4.1 Feasibility questions that must be answered

Before writing Swift, answer all of these from current official material:

1. What is the current supported API version for a direct file upload?
2. Is the endpoint intended for a trusted server only, or is a personal
   desktop client explicitly viable under the account model?
3. Does authentication use `x-uploadthing-api-key`, another header, a bearer
   value, or a signed request produced by a server?
4. Does the API accept raw bytes, a data URL, a presigned upload description,
   or only a server-side file reference?
5. What exact fields are required: filename, MIME type, size, ACL, content
   disposition, file data, custom ID, app ID, or region?
6. Is the file upload one request or a prepare-then-upload sequence?
7. If two-step, does the signed upload URL go directly from the app to object
   storage without a callback to Notinhas?
8. What exact response field contains the final public URL or file key?
9. Is the URL stable after the request, or does it expire?
10. Does the API require a file router endpoint or webhook to finalize the file?
11. Are `public-read` and `inline` current documented values, and are they
    required for a shareable screenshot URL?
12. What are current file-size, storage, bandwidth, rate, and retention limits?
13. Is an API key capable of account-wide destructive operations? If so, can a
    restricted personal key be used, and what is the minimum permission?
14. Does the provider document idempotency or duplicate-upload behavior?

If an answer cannot be verified, treat it as unknown and stop rather than coding
by analogy.

### 4.2 Required contract record

Before Step 2, write a short record in the implementation handoff with:

```text
API version:
Endpoint(s):
Authentication header/shape:
Request content type:
Required fields:
Public-link/ACL fields:
Response URL field:
Second-stage request, if any:
Timeout/async behavior:
Official source URLs and access date:
Reason no server/callback is required:
```

If this record cannot be completed, the implementation stops at the gate.

## 5. Current state after Plan 097

Plan 097 is expected to provide:

- `NotinhasUploadProvider` with ImgBB and ImageKit;
- selected-provider persistence with ImgBB default;
- shared provider/configuration state for Preferences, Annotate, and Quick
  Access;
- provider-scoped Keychain credentials;
- coordinator routing and common URL/clipboard behavior;
- direct ImageKit actor and offline tests;
- no server, no upload queue, and no generic cloud manager.

Inspect the actual result of Plan 097 rather than assuming names. In
particular, locate:

- the provider enum and its raw-value convention;
- the shared credential/configuration state;
- how coordinator dependencies are injected in tests;
- the common result/error boundary;
- how UI labels derive the selected provider;
- the exact test helper used for `URLProtocol`.

Do not create a parallel UploadThing configuration store or a second provider
picker.

## 6. Proposed minimal model extension

Add `.uploadThing` to the existing provider model, preserving raw values for
any stored configuration. The display name should be “UploadThing” and the
internal spelling should match the provider's brand exactly.

Add a dedicated Keychain item, likely:

```text
com.mourato.notinhas.cloud.uploadThingToken
```

Confirm whether the official terminology is API key, token, or another name and
use that terminology in the UI. Do not name the field generically `secret`.

Required state rules:

- existing ImgBB and ImageKit secrets remain untouched;
- selecting UploadThing with no token does not fall back to another provider;
- clearing UploadThing affects only UploadThing;
- changing provider never copies the current SecureField text into another
  provider's credential store;
- provider selection may be persisted as nonsecret state according to Plan 097;
- the token itself is never observable, exported, or included in diagnostics.

## 7. Implementation steps

### Step 0 — baseline and external contract gate

1. Confirm the isolated worktree and run `git status -sb`.
2. Review the actual Plan 097 diff and tests.
3. Read the current official OpenAPI and upload docs.
4. Complete the contract record in Section 4.2.
5. Confirm the direct flow does not require a Notinhas-owned route, callback,
   webhook, browser login, or server-side secret.
6. Confirm the flow produces a URL acceptable for the existing clipboard UX.

**Hard checkpoint:** do not add provider enum cases, UI, or tests until the
contract gate is passed. A plan with an unverified endpoint is not an
implementation plan.

### Step 1 — add UploadThing credential storage

Extend the existing Keychain enum/store convention with a provider-specific
UploadThing item. Follow the tested ImageKit credential pattern:

- trim whitespace;
- reject empty values before Keychain mutation;
- save only in Keychain;
- expose masked summary and cached `isConfigured`;
- clear only the UploadThing item;
- preserve Keychain fallback/error semantics;
- never emit the token in a log or `LocalizedError` message.

Use a protocol-backed fake in tests, not the real user's Keychain.

Required tests:

- missing token;
- whitespace token;
- save/read/reload;
- masked display;
- clear;
- Keychain failure;
- provider switch isolation;
- no token in configuration export.

### Step 2 — extend provider selection and Preferences

Add UploadThing to the existing picker. The view should reuse the shared state
from Plan 097 and render provider-specific guidance:

- what credential to create in the UploadThing dashboard;
- that the credential is stored locally in Keychain;
- that uploads produce public links;
- that the integration is intended for this personal app/account;
- that no Notinhas server is involved.

Do not embed a provider setup wizard or dashboard automation. A static external
link may be documented if that is already consistent with Preferences UI, but
do not open a URL automatically when the provider is selected.

State matrix:

| Provider | Credential state | Expected behavior |
|---|---|---|
| UploadThing | missing | setup copy, SecureField, Save |
| UploadThing | configured | masked token, Edit, Remove |
| UploadThing | invalid at upload | safe provider/API error; retain token |
| UploadThing | cleared | action unavailable until explicitly configured |
| switch away/back | configured | value remains scoped to UploadThing |

### Step 3 — implement the exact direct REST adapter

Create a focused actor, for example:

```text
Notinhas/Features/Notinhas/Services/NotinhasUploadThingUploadService.swift
```

The adapter accepts the already encoded `NotinhasEncodedImage` and a token/key
snapshot. It does not read Keychain or update SwiftUI.

#### One-step flow

If official docs confirm a one-step endpoint:

- construct the documented request exactly;
- send the filename, MIME type, size, and bytes in the required format;
- use only the documented auth header;
- request public/inline delivery only if those are current official fields;
- parse the documented URL field;
- validate it as a nonempty absolute HTTPS URL when appropriate;
- reject malformed success responses.

#### Two-step flow

If official docs require prepare-then-upload:

1. call the documented prepare endpoint with only required metadata;
2. parse the signed upload URL, fields, headers, and final file identity;
3. perform the signed upload exactly as returned;
4. use the documented final URL from the prepare response or upload result;
5. do not call a Notinhas callback because none exists;
6. do not poll forever; only perform bounded documented polling if the API
   explicitly requires it to obtain a final URL.

Treat each stage as an independent failure boundary. A successful first stage
followed by a failed second stage may create an orphaned remote object. Do not
pretend the operation is atomic; surface the failure and do not retry
automatically.

#### Request and response hygiene

- use `URLRequest`/`URLSession` and Foundation only;
- use finite timeouts;
- do not log request body, token, signed URL, response body, or local path;
- bound provider error text before displaying it;
- map cancellation separately from authorization and transport failure;
- do not expose object-storage internals to the user unless required for
  actionable diagnostics;
- do not accept a success response without a usable final URL;
- do not parse URL strings with ad hoc substring manipulation.

Suggested error categories:

- missing token;
- invalid image data;
- prepare request failed;
- upload request failed;
- unauthorized/forbidden;
- rate limited/quota exceeded;
- malformed provider response;
- missing/expired public URL;
- cancellation;
- offline/transport failure.

Use provider-specific errors inside the actor if that matches current code;
convert to the existing coordinator/UI boundary at one place.

### Step 4 — coordinator integration

Extend the existing provider switch from Plan 097. Keep these invariants:

- `@MainActor` owns published UI state;
- image/file encoding remains detached/off MainActor;
- the selected provider and credential are snapshotted before awaits;
- an upload is initiated only by an explicit action;
- no automatic fallback from UploadThing to ImageKit/ImgBB;
- `lastUploadedURL` is updated only after a validated success;
- `isUploading` resets on every exit path;
- prior successful URL is not replaced by a failed attempt;
- clipboard receives only the validated final URL.

Do not make the coordinator aware of UploadThing's internal two-stage details.
Those belong in the adapter.

### Step 5 — Annotate and Quick Access integration

Reuse the dynamic labels/availability added by Plan 097. Verify that the
persisted `uploadToImgBB` action remains decodable even when its displayed
provider is UploadThing.

For Annotate:

- upload the final composed image;
- preserve current progress/toast/error lifecycle;
- do not upload before annotation is finalized;
- keep videos/GIFs out of scope.

For Quick Access:

- use the existing file URL and derivative encoder;
- preserve action placement and customization;
- do not upload a temporary file after the card is dismissed unless the user
  explicitly triggered the action and the current flow already owns that file;
- keep the existing copied-link behavior.

### Step 6 — localization and accessibility

Add/update strings for:

- UploadThing provider name/description;
- API key/token field;
- missing credential;
- upload progress;
- success and copied public link;
- authorization failure;
- quota/rate-limit failure;
- malformed response/offline failure;
- Keychain save failure;
- public-link/personal-use explanation.

Review labels, help text, SecureField semantics, VoiceOver values, and disabled
state explanations in both upload surfaces. Keep proper brand names intact.

### Step 7 — review external-state behavior

Explicitly review whether the API can create a remote object before returning a
final URL. If yes:

- document the orphan risk;
- do not add remote deletion unless requested and designed separately;
- do not add an automatic retry that multiplies orphaned objects;
- ensure the user can retry manually and understands that a previous attempt
  may have succeeded remotely despite a local timeout.

## 8. Test matrix

### 8.1 Contract and request tests

Use an ephemeral `URLSession` with the repository's `URLProtocol` pattern.
Tests must model the exact official contract frozen in Section 4.2.

For one-step flow:

- correct endpoint and method;
- required auth header exists without printing its value;
- correct content type/body fields;
- filename, MIME type, and data are sent;
- public/inline fields are correct if documented;
- happy response parses the final URL.

For two-step flow:

- prepare request shape;
- prepare success parsing;
- signed request shape/headers/fields;
- final URL extraction;
- prepare failure;
- signed-upload failure;
- missing final URL;
- expired/invalid signed URL if representable;
- no second stage after a failed prepare;
- no unbounded polling.

### 8.2 Error tests

Cover:

- blank token and blank encoded data;
- 400/401/403;
- 408/timeout and transport offline;
- 413/file too large;
- 429/rate limit;
- 5xx;
- invalid JSON;
- valid JSON without URL;
- invalid URL scheme/format;
- cancellation at each await;
- provider error text that contains token-like text is not echoed verbatim.

### 8.3 Shared/regression tests

- ImgBB and ImageKit focused tests remain green;
- provider default remains ImgBB;
- provider selection survives reload;
- UploadThing credential is isolated from other credentials;
- configuration export excludes all provider secrets;
- Annotate/Quick Access action raw values remain compatible;
- coordinator resets progress state after all error categories;
- clipboard path receives only the validated URL.

### 8.4 Commands

Before running commands, load `delivery-workflow` and the Notinhas overlay.
Use quiet tests and no visual/audio flags:

```text
./scripts/run-tests.sh \
  -only-testing:NotinhasTests/Features/Notinhas/NotinhasUploadThingUploadServiceTests \
  -only-testing:NotinhasTests/Features/Notinhas/NotinhasImgBBUploadServiceTests \
  -only-testing:NotinhasTests/Features/Notinhas/NotinhasImgBBConfigurationTests

make format-check
make lint-changed
make agent-check
./scripts/verify-local.sh --base 346857f4 --execute --strict
```

## 9. Manual verification

Use a non-sensitive image and a personal UploadThing account:

1. Confirm UploadThing appears in Preferences → Uploads.
2. Save the token/API key and confirm only a masked value is shown.
3. Confirm the selected provider persists after reopening Preferences/app.
4. Upload from Annotate and verify the copied URL opens in a browser.
5. Upload from Quick Access and verify the same.
6. Confirm no Notinhas server, browser callback, or local route is involved.
7. Clear the UploadThing credential and verify only UploadThing becomes
   unavailable.
8. Switch to ImageKit and ImgBB and verify their credentials/actions still
   work.
9. Test missing token, invalid token, offline network, provider rejection, and
   a file at/near the configured upload-size boundary.
10. If the flow is two-step, observe that a first-stage success/second-stage
    failure is presented as failure without automatic retry.
11. Inspect exported configuration and diagnostics for secret absence.
12. Repeat relevant UI checks in Light and Dark appearance.

Do not put account tokens, signed URLs, provider response bodies, or private
screenshots into the repository or handoff.

## 10. Evidence mapping

| Invariant | Implementation owner | Evidence |
|---|---|---|
| no-server constraint remains true | adapter and project entitlements | contract record; diff review; manual flow |
| official REST shape is current | implementation handoff | official links/date; URLProtocol fixtures |
| token is Keychain-only | credential store/export boundary | credential tests; export test; diff review |
| final URL is validated | UploadThing actor | success/malformed URL tests; manual URL open |
| two-stage failures are visible | actor/coordinator error mapping | per-stage tests; manual forced failure if possible |
| no automatic duplicate retries | adapter/coordinator | code review; timeout/retry test |
| existing providers remain stable | shared provider switch | ImgBB/ImageKit regression tests; manual switch |
| explicit user action is required | Annotate/Quick Access handlers | manual no-action observation; diff review |

## 11. External-state addendum

**Authority:** local Keychain is authoritative for the UploadThing credential;
selected-provider configuration is authoritative for routing; UploadThing is
authoritative for remote file state and returned URL.

**Identity:** Keychain account is the stable UploadThing token item. A remote
file may have an UploadThing file key/ID, but this plan does not persist it.

**Scope:** read/write/delete only the UploadThing credential; upload only the
encoded bytes associated with the explicit current action; no remote list,
delete, rename, or usage mutation.

**Preflight:** freeze official contract; verify token is nonempty; verify
encoded data and content metadata; verify the selected provider is UploadThing;
verify no secret/logging/export path is active.

**Idempotency:** assume uploads are not idempotent unless the official contract
documents an idempotency key. Do not retry automatically. A manually repeated
action may create a duplicate and that is preferable to hidden background
behavior for this personal workflow.

**Failure:** preserve the token on API/network failure; reset in-flight state;
retain the previous successful URL; distinguish a possible remote-success/local
timeout from a confirmed rejection where the provider allows that distinction.

**Concurrency:** serialize visible uploads through the existing coordinator;
capture immutable request values before each await; reject stale results from a
cancelled or superseded operation.

**Destructive actions:** Remove clears only the local credential. No remote
delete is implemented, so partially uploaded/orphaned files remain subject to
provider retention and account cleanup.

**Admission:** explicit user action, UploadThing selected/configured, valid
encoded image, no conflicting upload.

**Execution:** preserve exact prepare response fields, signed URL, headers, and
file data for the operation; never reconstruct signed requests from guesses.

**Publication:** publish only a validated final public URL. If a two-step flow
fails after the provider may have accepted bytes, do not publish a guessed URL.

**Serialization:** no global queue; one coordinator operation at a time as
already established by the UI.

**Recovery:** user may explicitly retry after failure; no automatic cleanup or
retry is attempted.

## 12. Done checklist and handoff

- [ ] Feasibility gate completed from official current docs.
- [ ] Exact API contract recorded with version/date/URLs.
- [ ] No server, callback, webhook, file router, or new dependency added.
- [ ] UploadThing credential is Keychain-only and masked.
- [ ] One-step/two-step request tests match the official contract.
- [ ] All relevant HTTP/transport/parser/cancellation failures are tested.
- [ ] Coordinator and both UI surfaces use shared provider state.
- [ ] Existing ImgBB/ImageKit behavior and persisted action values remain valid.
- [ ] Manual personal-account upload and URL-open checks are recorded.
- [ ] Free-plan/account limits are recorded as external facts, not code
      assumptions.
- [ ] Commands/results, manual gates, review findings, and remaining risks are
      in the handoff.

If the feasibility gate fails, mark this plan blocked/not viable under the
no-server constraint, include the exact official evidence, and do not create a
partial adapter.

## 13. Maintenance notes

Keep all UploadThing-specific endpoint/version/field handling inside one actor.
When UploadThing changes API versions, update the adapter and fixtures as one
unit; do not scatter endpoint strings through the coordinator or UI.

Free-plan limits, API permissions, regions, ACL defaults, and retention can
change. Link to official documentation and recheck before implementation or
when uploads begin failing; do not promise unlimited practical storage merely
because a plan page currently uses broad upload/download wording.

Public links should be treated as shareable by anyone who obtains them. If the
product later needs private screenshots, this direct public-link plan is not a
small extension; it requires a separate access-control decision.

## 14. STOP conditions

Stop if any of the following is true:

- current official docs require a server/file router/callback/webhook for the
  chosen upload path;
- the only direct request requires a secret that cannot safely remain local to
  this personal app;
- the endpoint, auth header, fields, or response URL cannot be verified from
  official docs;
- the final URL expires, is private, or cannot be opened as a stable public
  handoff link;
- the flow requires an undocumented browser/session/cookie workaround;
- a new dependency or entitlement is required;
- safe bounded handling of a two-stage flow is not possible;
- the implementation needs automatic retries, fallback, remote cleanup, or
  upload history to appear reliable;
- the task expands beyond the personal local app;
- unrelated worktree changes conflict with the planned files;
- the same validation failure occurs twice without a documented correction.

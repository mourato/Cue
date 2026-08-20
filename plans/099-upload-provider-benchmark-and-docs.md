# Plan 099: Benchmark direct providers and reconcile documentation

> **Executor instructions:** run this plan after Plans 097 and 098. It is the
> closure plan for performance evidence, security wording, documentation, and
> manual readiness. It must not grow into telemetry, a server, a cloud-history
> subsystem, or an automatic provider-selection engine.

## 1. Delivery contract

**Objective:** measure the real upload paths for ImgBB, ImageKit, and (if Plan
098 passes) UploadThing, then reconcile product/security/configuration
documentation with the implementation and the explicit no-server personal-use
boundary.

**Observable outcome:** the repository documents what the app actually does,
which credentials it stores, which providers are available, what public-link
and privacy assumptions apply, and which provider is recommended based on a
repeatable local benchmark rather than an unverified performance claim.

**In scope:**

- Controlled benchmark of the same encoded image through the real Annotate and
  Quick Access paths.
- Comparison of encoding, network, total, success/failure, and practical
  free-plan constraints.
- Decision record for default/recommended provider behavior.
- Security, lifecycle, cloud-boundary, configuration, feature, UI, and
  localization documentation updates.
- One ADR if the direct personal-credential/no-server decision is not already
  recorded adequately.
- Manual credential, upload, clipboard, URL-open, offline, and appearance
  checks.

**Out of scope:**

- Permanent timing instrumentation, analytics, telemetry, remote metrics, or a
  benchmark server.
- Automatic provider fallback, latency-based routing, health checks, or
  provider recommendation UI.
- Server/serverless infrastructure, OAuth, generic cloud storage, remote file
  deletion, history, usage dashboards, or video upload.
- Rewriting historical upstream changelog entries merely to remove old names.
- Changing the default provider silently for existing users.

**Constraints:**

- This is a personal local macOS app with no server.
- Direct provider credentials are local-only and unsuitable for multi-user
  distribution; documentation must say so plainly.
- The benchmark must use identical encoded bytes/settings where possible and
  must not persist sensitive test images or provider secrets.
- Performance findings are empirical observations for this user's account and
  network, not guarantees about global provider performance.
- Existing ImgBB persisted configuration/action identifiers remain compatible.
- The retired S3/R2/Google Drive cloud stack remains retired.

**Acceptance:**

- [ ] Benchmark results contain enough method/data to reproduce the comparison
      later without adding a metrics system.
- [ ] The default-provider behavior is explicit and does not surprise existing
      users.
- [ ] Documentation consistently distinguishes image hosting from retired
      generic cloud storage.
- [ ] Documentation identifies Keychain-only credential storage and the
      personal-only security exception.
- [ ] Docs do not claim automatic uploads, privacy guarantees, server hosting,
      unlimited storage, or guaranteed performance.
- [ ] User-facing labels, docs, localization, configuration export docs, and
      ADR use the same provider set and terminology.
- [ ] Automated guidance/product checks and manual checks are recorded.

**Validation:**

- Controlled benchmark worksheet/handoff.
- `make guidance-check`.
- `make test` or the smallest repository-approved equivalent if the full suite
  is not available; record baseline failures.
- `make format-check`, `make agent-check`, and changed-surface verification.
- Manual UI/network/privacy checks described below.

**Integration:** documentation/implementation branch according to repository
policy; local `main` only after review and explicit merge authorization. No push
is authorized by this plan.

**Stop conditions:** see Section 16.

**Handoff:** include benchmark data/method, default decision, changed docs/ADR,
commands/results, manual gates, remaining external risks, and exact delivery
status.

## 2. Status and execution profile

- **Priority:** P2
- **Effort:** S/M
- **Risk:** LOW/MED
- **Depends on:** Plans 097 and 098; if Plan 098 is blocked, benchmark the
  providers that actually shipped and document UploadThing as not available
- **Category:** performance / docs / security / product contract
- **Planned at**: commit `346857f4`, 2026-08-20
- **Publication:** local plan
- **Recommended executor:** implementer or documentation-focused implementer
  with provider review
- **Risk lane:** Medium/Full because docs describe credential and network
  behavior
- **Parallelizable:** no. The documentation and default recommendation depend
  on actual implementation and benchmark results.
- **Reviewer required:** yes. Stale security/cloud documentation is a product
  risk even when code is correct.

## 3. Purpose and decision boundary

The original motivation is that ImgBB works but feels slow. The purpose of this
plan is to determine whether ImageKit or UploadThing is materially better for
this user's actual workflow while preserving the free/no-server constraint.

Do not turn a local benchmark into a product claim such as “ImageKit is always
faster.” The strongest safe claim is narrower: “In the recorded test on date X,
from network/account context Y, provider Z had the lowest median total time.”

Do not switch existing users silently. The safest initial behavior is:

- keep ImgBB as the persisted default for compatibility;
- allow explicit provider selection;
- document the recommended provider for a fresh personal setup after the
  benchmark;
- avoid automatic fallback because fallback can upload a screenshot to a
  different account without a clear user action.

If the user later explicitly requests a default switch, that is a separate
decision with migration/UX acceptance; do not smuggle it into documentation
cleanup.

## 4. Expected implementation state

After Plans 097 and 098, verify rather than assume:

- provider selection includes ImgBB, ImageKit, and possibly UploadThing;
- selected provider is persisted independently of secrets;
- ImgBB legacy key migration still works;
- ImageKit and UploadThing credentials are in provider-scoped Keychain items;
- TOML/configuration export contains encoding/provider settings only where
  intentionally supported and never raw secrets;
- Annotate and Quick Access use one provider-selection state;
- upload is explicit and foreground/local;
- video/GIF upload remains out of scope;
- no server/serverless/network server entitlement exists;
- direct-provider services do not log secrets, paths, image bytes, or full
  response bodies.

If either provider did not pass its implementation stop gate, do not document it
as available. Document the reason and keep the feature set honest.

## 5. Benchmark protocol

### 5.1 Test fixture

Use one representative screenshot captured locally and then use the exact same
encoded bytes for all providers wherever the service contract permits.

Record non-sensitive fixture metadata:

- image pixel dimensions;
- encoded format (`jpeg`, `webp`, or the selected supported format);
- encoded byte count;
- upload optimization settings;
- whether the source came from Annotate composition or Quick Access;
- test date/time and approximate region/network type;
- provider/account region if visible without recording secrets.

Do not record the screenshot itself in the repository. Do not use a sensitive
customer/design image. Do not add a permanent fixture if a local temporary
fixture is sufficient.

### 5.2 Runs

For every provider that shipped, perform at least five runs from each entry
point:

- Annotate final-image upload: five runs;
- Quick Access file upload: five runs.

Use the same provider credential for the run set, the same image settings, and
the same network where practical. Avoid changing Wi-Fi/VPN during a set.

Separate:

- first/cold request after app launch;
- subsequent/warm requests;
- successful requests;
- failed requests and their error category.

Do not intentionally upload the same image repeatedly if a provider's duplicate
behavior would distort results; use deterministic copies or a test image that
the provider treats as ordinary new uploads. The benchmark should measure the
real path, not a synthetic no-op.

### 5.3 Measurements

Measure, in milliseconds when possible:

1. **Encoding time:** start of local encode to encoded bytes ready.
2. **Request time:** first provider request to validated provider response.
3. **Second-stage time:** prepare-to-upload/finalization duration if applicable.
4. **Total action time:** explicit button action to copied URL.
5. **Clipboard completion:** response validation to clipboard write completion.
6. **Failure rate:** failed runs/total runs and error category.
7. **URL usability:** whether the copied URL opens immediately and remains
   usable after a later check.

If the production coordinator does not expose timings, use a temporary manual
stopwatch or local observation. Do not add timing properties, analytics, logs,
or persistent telemetry solely for this plan.

### 5.4 Results table

Record a compact table in the implementation handoff or a local planning note
that is not committed if the repository does not retain benchmark artifacts:

| Provider | Entry point | Cold total | Warm totals | Median request | Median total | Failures | URL usable |
|---|---|---:|---:|---:|---:|---:|---|
| ImgBB | Annotate |  |  |  |  |  |  |
| ImgBB | Quick Access |  |  |  |  |  |  |
| ImageKit | Annotate |  |  |  |  |  |  |
| ImageKit | Quick Access |  |  |  |  |  |  |
| UploadThing | Annotate |  |  |  |  |  |  |
| UploadThing | Quick Access |  |  |  |  |  |  |

Use `n/a` for a provider that did not pass its no-server feasibility gate.

### 5.5 Interpretation rules

- Compare medians, not a single best run.
- Treat a provider as practically better only when the difference is visible
  in the actual user flow and not explained by one outlier.
- Consider failure rate and URL usability as first-class outcomes; a lower
  latency with unstable links is not automatically better.
- Separate local encoding time from network/provider time so a provider is not
  blamed for shared image-processing cost.
- Do not infer global CDN performance, account-wide quota, or future reliability
  from five local runs.
- If results are too close to call, document “no clear winner” and leave the
  explicit default unchanged.

## 6. Free-plan and operational review

Before recommending a provider, recheck its official plan/account dashboard:

- storage quota;
- bandwidth/egress quota;
- maximum image/file size;
- rate limits;
- retention/deletion behavior;
- public-link behavior;
- account suspension/overage behavior;
- whether the free tier requires a payment method or has changed terms.

Use official links:

- ImageKit plans: <https://imagekit.io/plans>
- UploadThing product/pricing: <https://uploadthing.com/>

Do not encode plan numbers in Swift or promise that free usage will remain
free. The implementation's purpose is to avoid Notinhas infrastructure cost;
provider free-tier terms remain the user's responsibility.

Document the practical conclusion, for example:

```text
Provider recommendation: ImageKit for this personal setup.
Reason: lower median total time in the recorded test and acceptable current
free-tier limits.
Compatibility default: ImgBB remains the persisted default.
Security boundary: direct personal credential only; not distributable.
```

## 7. Default/recommendation decision

### 7.1 Required decision

Choose one of:

- keep ImgBB as both compatibility default and recommendation;
- keep ImgBB as compatibility default but recommend ImageKit;
- keep ImgBB as compatibility default but recommend UploadThing;
- document no clear winner and recommend the provider with the simplest
  reliable setup.

The decision must include performance, failure rate, URL behavior, free-tier
practicality, and credential/security tradeoffs.

### 7.2 Forbidden behavior

- Do not auto-select a provider based on measured latency.
- Do not silently migrate an existing ImgBB user.
- Do not send a failed upload to another account/provider without a second
  explicit action.
- Do not use provider health checks that generate remote files.
- Do not describe a provider as “free forever” or “private” without current
  contractual evidence.

### 7.3 Upgrade behavior

Verify these scenarios:

1. fresh configuration: selected default is documented;
2. existing ImgBB configuration: remains ImgBB after upgrade;
3. selected ImageKit/UploadThing: remains selected after relaunch;
4. selected provider credential cleared: only that provider becomes unavailable;
5. old `uploadToImgBB` action raw values: still decode and show the selected
   provider's current label;
6. invalid provider raw value: safe fallback according to Plan 097.

## 8. Documentation inventory and edits

Read each target document before editing. Keep terminology consistent and do
not rewrite unrelated historical material.

### 8.1 `docs/SECURITY.md`

Update the network boundary from ImgBB-only to explicit user-selected image
uploads. State:

- optional outbound network is used only after explicit upload action;
- supported providers are the ones that actually shipped;
- credentials are Keychain-only;
- provider secrets are excluded from UserDefaults, TOML, diagnostics, logs,
  clipboard, and UI text except masked summaries;
- public URLs can be shared by anyone who receives them;
- direct local credentials are a personal-use exception, not a multi-user
  distribution security model;
- no automatic update, telemetry, crash upload, support upload, server, or
  background cloud sync was introduced.

Do not claim the Keychain makes the provider account safe from the local user or
from reverse engineering of a distributed app.

### 8.2 `docs/APP_LIFECYCLE.md`

Update the `com.apple.security.network.client` description to cover explicit
user-configured image uploads through supported providers. Keep the statement
that no `network.server` entitlement exists. Do not imply the app opens a
listening service or performs background synchronization.

### 8.3 `docs/CLOUD.md`

Clarify the boundary:

- retained feature: explicit image sharing to selected image host;
- retired feature: generic BYO cloud storage/upload-history/usage/password/
  transfer system;
- no remote capture history or video upload;
- credentials are provider-scoped in Keychain;
- public-link behavior and personal-only scope.

Avoid calling ImageKit/UploadThing a replacement for the retired generic cloud
architecture. They are thin image-host adapters for the handoff workflow.

### 8.4 `docs/PREFERENCES.md`

Document Preferences → Uploads as the owner of:

- provider selection;
- provider-specific credential configuration;
- image optimization/derivative settings;
- Keychain-only secret storage;
- no secret export.

Remove or qualify “ImgBB-only” wording while preserving historical plan
references where they explain why generic cloud controls are absent.

### 8.5 `docs/ANNOTATE.md` and `docs/QUICK_ACCESS.md`

Describe the action as selected-provider image sharing while preserving the
legacy persisted action identifier where the docs need to name it. Explain:

- explicit action only;
- final Annotate composition vs. Quick Access encoded file;
- copied public URL;
- missing credential behavior;
- videos/GIFs remain out of scope;
- provider selection is shared with Preferences.

Review action order/default placement and do not claim a new action was added
if the existing `uploadToImgBB` slot is being retargeted dynamically.

### 8.6 `docs/CONFIGURATION.md`

Document:

- which provider selection/encoding fields are persisted, if provider selection
  is intentionally part of TOML;
- that all provider credentials remain outside export/import;
- compatibility behavior for legacy `uploadToImgBB` values;
- no BYO cloud upload or after-capture generic cloud action;
- invalid provider values and safe default if applicable.

Do not put real keys or example-looking secrets in TOML snippets.

### 8.7 `docs/ui.md`

Preserve the existing invariant that Uploads owns provider configuration and
image encoding controls. Add only durable UI rules that were actually
introduced, such as:

- provider picker changes the configured-state and action label globally;
- credential fields show masked Keychain state;
- missing selected-provider credential is explained locally;
- upload progress/success/error states are provider-aware or intentionally
  provider-neutral;
- no new layout/material/animation rule is invented for this feature.

### 8.8 Additional references to audit

Use `rg` after edits for stale active claims in:

- `docs/POST_CAPTURE.md`;
- `docs/MIGRATION.md`;
- `docs/LOCALIZATION.md`;
- `docs/README.md`;
- `docs/STRUCTURE.md`;
- `docs/VIDEO_EDITOR.md` if it mentions upload availability;
- active `Notinhas/Shared/Localization/L10n.swift` comments/defaults;
- `docs/adr/070-retain-inherited-snapzy-surfaces.md` and
  `docs/adr/073-upload-image-derivatives.md` where historical ImgBB wording
  may need a scoped clarification.

Do not rewrite the upstream changelog solely for terminology cleanup. Historic
entries may retain historical names.

## 9. ADR decision record

Inspect `docs/adr/` and choose the next available number; never guess or reuse
an existing number. Create an ADR only if the direct-credential/no-server
decision is not already adequately recorded.

The ADR should record:

- context: personal macOS app, no server/no budget, ImgBB performance concern;
- decision: thin direct adapters, explicit provider choice, Keychain secrets;
- accepted tradeoff: personal-only credential exposure and public URLs;
- rejected alternatives: Notinhas server, serverless proxy, generic cloud
  abstraction, automatic fallback, background upload;
- compatibility: ImgBB remains available/default and legacy action identifiers
  decode;
- consequences: provider limits/terms are external, uploads may create remote
  objects, no remote cleanup/history is provided;
- revisit triggers: distribution to other users, private-link requirement,
  provider API/security changes, server budget/availability.

Use the repository's ADR format and link from the relevant docs. Do not create
an ADR for a benchmark result that belongs in the plan handoff unless it changes
a durable architectural rule.

## 10. Localization/content review

Search active strings/comments for stale assumptions:

```text
rg -n "ImgBB|imgbb|cloud upload|upload to cloud|UploadThing|ImageKit" \
  Notinhas docs NotinhasTests -g '*.swift' -g '*.md'
```

Classify each hit:

- active user-facing copy that must become provider-aware;
- active compatibility identifier that must remain unchanged;
- historical documentation that should remain historical;
- stale security/configuration claim that must be updated;
- unrelated upstream surface that must not be touched.

Check Portuguese and English copy where the project supports both. Preserve
proper brand capitalization and use “Keychain” consistently.

## 11. Manual verification matrix

Run with a non-sensitive screenshot and the user's own accounts:

| Scenario | ImgBB | ImageKit | UploadThing |
|---|---:|---:|---:|
| configure/save credential | [ ] | [ ] | [ ] |
| masked state after relaunch | [ ] | [ ] | [ ] |
| Annotate upload | [ ] | [ ] | [ ] |
| Quick Access upload | [ ] | [ ] | [ ] |
| copied URL opens | [ ] | [ ] | [ ] |
| clear credential | [ ] | [ ] | [ ] |
| missing credential message | [ ] | [ ] | [ ] |
| invalid credential message | [ ] | [ ] | [ ] |
| offline failure | [ ] | [ ] | [ ] |
| Light appearance | [ ] | [ ] | [ ] |
| Dark appearance | [ ] | [ ] | [ ] |
| video/GIF remains out of scope | [ ] | [ ] | [ ] |
| no secret in export/diagnostics | [ ] | [ ] | [ ] |

Also verify:

- no upload happens when a card/window merely appears;
- no automatic fallback occurs;
- previous successful URL is not replaced by a failed attempt;
- action labels track the selected provider;
- old persisted action/configuration values still decode;
- provider switching does not cross-save credential text.

Record manual results without saving screenshots, credentials, signed URLs, or
private response bodies in the repository.

## 12. Validation commands

Before running commands, load the repository's `delivery-workflow` skill and
Notinhas overlay. Use the quiet/default test mode and no visual/audio flags
unless a specific manual UI gate requires them.

```text
make guidance-check
make test
make format-check
make agent-check
./scripts/verify-local.sh --base 346857f4 --execute --strict
```

If the full `make test` command is unavailable or fails due to a known baseline,
run the focused provider/configuration tests from Plans 097/098 and record:

- exact command;
- first failure;
- failure classification (`deterministic-product`, `environment`,
  `shared-resource`, `flaky`, `procedure`, `baseline`, or `unknown`);
- whether retry was safe;
- remaining impact.

Do not report a retry as proof that the first failure was flaky without
evidence. If the same failure occurs twice, stop repeating it and document the
correction/workaround.

## 13. Evidence mapping

| Invariant | Implementation/document owner | Evidence |
|---|---|---|
| benchmark compares identical work | benchmark protocol/handoff | fixture metadata and run table |
| recommendation does not promise global performance | benchmark section/docs | review of wording and recorded medians |
| ImgBB compatibility remains | provider/config docs | upgrade scenarios and existing tests |
| secrets are Keychain-only | SECURITY, CONFIGURATION, Preferences docs | export/diagnostic inspection and docs review |
| no server/network-server entitlement | SECURITY, APP_LIFECYCLE, ADR | entitlement/source review |
| public-link limitation is clear | CLOUD, SECURITY, provider docs | manual URL check and copy review |
| retired generic cloud stays retired | CLOUD, ANNOTATE, QUICK_ACCESS, CONFIGURATION | `rg` audit and guidance-check |
| explicit action is required | feature docs and handlers | manual no-action observation |
| provider set is consistent | all listed docs/localization | cross-document `rg` audit |

## 14. External-state addendum

**Authority:** actual implementation and provider documentation are authoritative
for behavior; the benchmark handoff is authoritative only for the recorded
local comparison; provider dashboards/terms are authoritative for current
quotas and account limits.

**Identity:** each benchmark row is identified by provider, entry point, image
fixture metadata, encoding settings, run number, and date. Do not identify rows
with secrets or full remote URLs.

**Scope:** measure only explicit uploads made for this benchmark; update only
the documentation/ADR surfaces listed in this plan; do not alter provider
defaults or remote files as a side effect of measurement.

**Preflight:** verify the implementation revision, selected provider set,
account limits, fixture bytes/settings, network context, and documentation
baseline before measuring or editing.

**Idempotency:** benchmark uploads may create remote files. Use disposable test
images/account space and do not retry a timed-out request automatically. Record
possible remote success rather than claiming no file was created.

**Failure:** a failed benchmark run is data, not a reason to hide the provider.
Classify the failure and distinguish provider failure, network failure,
credential failure, and local UI/encoding failure.

**Concurrency:** run one provider/upload at a time where possible; do not
parallelize requests in a way that changes rate-limit or cold/warm behavior.

**Destructive actions:** do not delete remote files or credentials as part of
benchmark automation. Clear local credentials only during the explicit manual
verification and confirm the correct provider is affected.

**Admission:** benchmark only after the provider has passed its implementation
and account feasibility checks; edit docs only after the implementation diff is
reviewed.

**Execution:** preserve fixture/settings and record timestamps consistently;
keep provider-specific facts linked to official sources.

**Publication:** publish benchmark conclusions in the handoff and durable ADR
only when they represent a stable architectural decision. Do not publish raw
secrets, private URLs, or sensitive fixture data.

**Serialization:** one benchmark run at a time per provider/entry point unless
the protocol explicitly records concurrency.

**Recovery:** if a provider changes behavior during the run, mark the run
invalid, record the date/source change, and repeat only after the contract is
rechecked. Do not silently mix API versions in one comparison.

## 15. Done checklist and handoff

- [ ] Implementation state of Plans 097/098 was inspected, not assumed.
- [ ] Providers that failed feasibility are marked unavailable, not documented
      as shipped.
- [ ] Benchmark fixture and method are recorded without sensitive artifacts.
- [ ] At least five runs per provider/entry point were completed or a clear
      reason is recorded.
- [ ] Median timing, failures, URL usability, and free-tier constraints are
      considered together.
- [ ] Existing ImgBB users are not silently switched.
- [ ] SECURITY and APP_LIFECYCLE describe the actual network/credential model.
- [ ] CLOUD distinguishes image hosting from retired generic cloud storage.
- [ ] Preferences, Annotate, Quick Access, CONFIGURATION, UI, localization,
      and active cross-references are reconciled.
- [ ] ADR number was chosen by inspecting the directory and its decision is
      durable rather than a temporary benchmark note.
- [ ] `rg` audit found no stale active ImgBB-only claims or contradictory
      server/privacy/fallback promises.
- [ ] Guidance, tests, formatting, agent checks, and changed-surface checks
      are recorded.
- [ ] Manual credential/upload/clear/URL/open/appearance checks are recorded.
- [ ] Review findings and remaining external risks are recorded.

## 16. STOP conditions

Stop if:

- the benchmark would require telemetry, analytics, a server, or persistent
  timing instrumentation;
- results cannot be compared because providers receive different encoded data
  or API versions and the difference cannot be controlled;
- a provider's free limits are insufficient for intended personal use;
- a provider's public-link/privacy behavior is unclear;
- documentation would have to promise privacy, durability, free usage, or
  performance the direct-client model cannot guarantee;
- the implementation starts treating image hosts as generic cloud storage;
- a default switch would surprise existing users or require migration not
  covered by the plan;
- the docs conflict about secret storage, server presence, provider set, or
  automatic upload behavior;
- a manual check reveals a credential leak in export, diagnostics, logs,
  clipboard, or UI;
- unrelated worktree changes conflict with the planned documentation;
- the same validation failure occurs twice without a documented correction.

## 17. Maintenance notes

Provider plan pages, API versions, quotas, retention, and privacy terms are
external and can change. Keep links to official sources and date-sensitive
facts out of code. Recheck this decision if uploads become unreliable, if a
provider changes its free tier, or if the app's distribution scope changes.

The no-server/personal-only boundary is the key architectural constraint. If
Notinhas is ever shared with other users, revisit the security ADR before
shipping credentials in a client.

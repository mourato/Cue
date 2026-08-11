# Plan 087: Make background Annotate commit failures recoverable

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. Plan 085 already provides the Boolean local commit
> helper; this plan gives its failure result a user-visible and re-editable
> outcome. When done, update the status row for this plan in `plans/README.md`
> unless a reviewer dispatched you and told you they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat af7e2e99..HEAD -- Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift Notinhas/Features/Annotate/AnnotateManager.swift Notinhas/Features/Annotate/Services/AnnotateExporter.swift Notinhas/Services/Diagnostics/AppToastManager.swift`
> `AnnotateExporter` and `AppToastManager` are read-only dependencies. If the
> current-state excerpts do not match, stop before editing.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: [Plan 085](085-annotate-local-commit-tail.md); serialize
  after Plan 086 because both edit the Annotate controller
- **Category**: bug
- **Planned at**: commit `af7e2e99`, 2026-08-11

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — the detached commit tasks, Annotate window
  lifecycle, session cache, and recovery reopen must be changed as one flow.
- **Reviewer required**: yes — the fix crosses MainActor, detached work,
  Quick Access ownership, session restoration, and user-visible feedback.
- **Rationale**: The existing Boolean result and session snapshot are enough;
  the smallest safe recovery is to report failure and reopen the same editable
  snapshot with pending changes, without adding a coordinator or persistence
  service.
- **Escalate when**: Recovery requires a new persisted pending-session format,
  a new toast/panel system, a new localization subsystem, or changing the
  instant-close performance contract for successful commits.

## Why this matters

Normal Annotate Save, Save-and-Close, and Copy close the window and mark the
state clean before their detached rendered-file commit finishes. If rendering,
encoding, or writing fails, the current code only logs and discards the
Boolean, so the user sees apparent success and may lose the editable result.
The flow already captures `AnnotationSessionData` before closing; use that
snapshot to reopen the editor, mark the reopened state dirty, and show the
existing localized failure copy through the app's global toast surface.

## Current state

The app is a strict-concurrency Swift 6.2 macOS app. `AnnotateWindowController`
owns the fast-close paths; `AnnotateManager` owns window tracking and session
restoration; `AnnotateManager.sessionCache` is the in-memory recovery cache for
Quick Access items. Keep the recovery small and local to those owners.

Relevant current code:

- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:657-724`
  captures `sourceURL` and `sessionSnapshot`, marks the state saved, closes,
  and discards the result of `persistRenderedFileOffMain`. It also returns on
  missing render snapshot or rendered image after logging only.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:1079-1113`
  does the same for Save: it caches the snapshot before `forceClose()` and
  ignores the detached helper's `Bool`.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:1230-1279`
  does the same for Copy. The rendered image/cloud URL has already been put on
  the clipboard before the source-file commit finishes; preserve that success
  while reporting the failed source update.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:1541-1560`
  already returns `false` for a missing image/source or failed
  `AnnotateExporter.saveToFileOffMain` and only persists the committed sidecar
  after a successful file write.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:746`
  makes `forceClose()` set `hasUnsavedChanges = false`, so a normal reopen
  cannot infer that the detached write failed.
- `Notinhas/Features/Annotate/AnnotateManager.swift:125-130` restores a
  Quick Access item from `sessionCache` or the committed sidecar; normal
  restoration deliberately does not mark the editor dirty.
- `Notinhas/Features/Annotate/AnnotateManager.swift:179-198` supports opening
  a URL with an explicit `AnnotationSessionData` snapshot, but currently
  ignores the passed snapshot when a matching Quick Access item already exists.
- `Notinhas/Services/Diagnostics/AppToastManager.swift:144-176` is the existing
  `@MainActor` global toast presenter used by Annotate and other failure flows.
- `Notinhas/Shared/Localization/L10n.swift:5416-5425` exposes the already
  localized `L10n.AnnotateUI.saveFailedTitle` and `saveFailedMessage`; reuse
  `saveFailedMessage` for this first recovery pass instead of adding hardcoded
  copy or a second catalog key.

The recovery contract after a detached local commit failure is:

1. Show an error toast using `L10n.AnnotateUI.saveFailedMessage`.
2. Do not clear `AnnotateManager.sessionCache`, dismiss the Quick Access card,
   or pretend the source file was committed.
3. If `sourceURL` and `sessionSnapshot` exist, reopen through
   `AnnotateManager.openAnnotation(url:sessionData:pendingCommitRecovery:)`.
   If a matching Quick Access item exists, replace its cache entry with the
   passed snapshot before opening it.
4. The recovery-opened controller sets `state.hasUnsavedChanges = true`, so
   closing without a successful retry still follows the existing unsaved-change
   confirmation path. Normal session restores keep their current clean state.
5. If no snapshot is available, still show the toast and log the missing
   recovery inputs; do not invent a new disk format in this plan.

The existing localized message is intentionally reused even though the first
wording mentions the selected location. A copy rewrite and full translation
pass are not part of this recovery plumbing plan.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Drift | `git diff --stat af7e2e99..HEAD -- Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift Notinhas/Features/Annotate/AnnotateManager.swift Notinhas/Features/Annotate/Services/AnnotateExporter.swift Notinhas/Services/Diagnostics/AppToastManager.swift` | Empty on the planned baseline, or reviewed drift before proceeding |
| Focused Annotate tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateCoreTests -only-testing:NotinhasTests/AnnotateExportSaveTests -only-testing:NotinhasTests/AnnotationSessionStoreTests` | Exit 0; core, file-write, and sidecar contracts pass |
| Formatting | `make format-check` | Exit 0; no SwiftFormat violations |
| Changed-file lint | `make lint-changed` | Exit 0; no changed Swift lint violations |
| Project gate | `make agent-check` | Exit 0; no unhandled changed surface |
| Plan surface | `./scripts/verify-local.sh --base af7e2e99 --plan-only` | Exit 0; reports the Annotate manual-required surface |
| Full default suite | `make test` | Exit 0; no new failures |

## Suggested executor toolkit

- Use `.agents/skills/testing-xctest/SKILL.md`: keep the recovery test surface
  pure where possible and leave window/toast lifecycle to manual verification.
- Use `.agents/skills/data-persistence/SKILL.md`: the snapshot is an in-memory
  pending edit, not a committed sidecar; preserve signature-based sidecar
  semantics and do not persist a mismatched source/session pair.
- Use `.agents/skills/capture-annotate-export/SKILL.md`: a failed source commit
  must not erase the clipboard-ready visual handoff or editable annotations.
- Use `ux-writing` only as a review gate if this plan changes copy. The default
  implementation reuses existing localized strings and changes no catalog.

## Scope

**In scope** — the only production files to modify:

- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift`
- `Notinhas/Features/Annotate/AnnotateManager.swift`
- `plans/README.md` status row

Read-only dependencies:

- `Notinhas/Features/Annotate/Services/AnnotateExporter.swift`
- `Notinhas/Services/Diagnostics/AppToastManager.swift`
- `Notinhas/Shared/Localization/L10n.swift`

**Out of scope**:

- changing `AnnotateExporter`, `AnnotationSessionStore`, sidecar signatures,
  `PostCaptureActionHandler`, Quick Access timer policy, or cloud methods;
- adding a pending-session file format, retry queue, background scheduler, or
  generic commit coordinator;
- changing successful instant-close behavior, thumbnail generation, clipboard
  payloads, Save As, combine behavior, or `AnnotateState` decomposition;
- adding or rewriting localization catalog entries.

## Git workflow

- Branch: `advisor/087-annotate-background-commit-recovery`
- Commit: `fix(annotate): recover from background commit failure`
- Do not push or open a PR unless the operator instructs it.

## Steps

### Step 1: Add an explicit pending-recovery flag to Annotate restoration

Extend `AnnotateManager.openAnnotation(for:)` and
`AnnotateManager.openAnnotation(url:sessionData:)` with a defaulted
`pendingCommitRecovery: Bool = false` parameter. Pass it to the corresponding
`AnnotateWindowController` initializers, which should also receive a defaulted
flag so all existing call sites retain their current behavior.

When `openAnnotation(url:sessionData:pendingCommitRecovery:)` finds a matching
Quick Access item, first store the passed non-nil `sessionData` in
`AnnotateManager.sessionCache` for that item, then call the item overload with
the pending flag. This is required because the current matching-item branch
otherwise ignores its explicit snapshot.

After each relevant `AnnotateWindowController` initializer has restored its
state and before window presentation setup, set
`state.hasUnsavedChanges = true` only when `pendingCommitRecovery` is true.
Normal first opens and normal sidecar/session restores must remain clean.

**Verify**:

```sh
make format-check && make lint-changed
rg -n "pendingCommitRecovery" Notinhas/Features/Annotate/AnnotateManager.swift Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift
```

Expected: the flag appears on both URL/item restoration paths and their
controller initializers; formatting and lint exit 0.

### Step 2: Add one MainActor recovery presenter

Near `persistRenderedFileOffMain`, add one private MainActor helper in
`AnnotateWindowController` that accepts only `sourceURL` and
`sessionSnapshot`. It must:

- show `AppToastManager.shared.show(message: L10n.AnnotateUI.saveFailedMessage,
  style: .error, duration: 5)`;
- log a diagnostic when either recovery input is missing;
- when both exist, call
  `AnnotateManager.shared.openAnnotation(url:sourceURL,
  sessionData:sessionSnapshot, pendingCommitRecovery:true)`;
- never call `AnnotationSessionStore.persist` directly and never clear a
  Quick Access/session cache.

Call the helper with `await` from detached tasks through `Self`, not by
capturing the closed controller or its live `AnnotateState`. This preserves the
existing frozen-snapshot concurrency boundary.

**Verify**: `make format-check && make lint-changed` → exit 0; no detached task
captures `AnnotateState` or a closed window solely to show the failure.

### Step 3: Handle every normal local commit failure

Update only the normal local paths:

1. In `executeSaveAndClose()`, call the recovery helper when the render
   snapshot is nil, when `renderFinalImage(snapshot:)` returns nil, and when
   `persistRenderedFileOffMain` returns `false`. Preserve the existing
   thumbnail generation and successful commit ordering.
2. In `executeSave()`, capture the helper result instead of discarding it and
   call the recovery helper on `false`.
3. In `executeCopy()`, capture the helper result and call the recovery helper
   on `false`. Keep the already-completed clipboard action intact; the toast
   explains that the source update failed and the reopened editor carries the
   editable snapshot.

Do not report sidecar-persist failure separately: the existing helper's
Boolean means the rendered source-file commit succeeded, while sidecar
persist remains best-effort under Plan 085. Do not change cloud re-upload
methods; Plan 086 owns their local-write gate.

**Verify**:

```sh
rg -n -U "_ = await Self\\.persistRenderedFileOffMain|guard let renderedImage|presentBackgroundCommitFailure" Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift
./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateCoreTests -only-testing:NotinhasTests/AnnotateExportSaveTests
```

Expected: no normal local caller discards the helper result; all early render
failures use the same recovery helper; focused tests exit 0.

### Step 4: Run the delivery gates and manual recovery checks

Run `make format-check`, `make lint-changed`, `make agent-check`,
`./scripts/verify-local.sh --base af7e2e99 --plan-only`, and `make test`.
Record any manual-required output.

On macOS, use a disposable source file and an intentionally unwritable target
to verify each route:

- Save-and-Close: the window closes quickly, the write fails, the editor
  reopens with the annotations and dirty state, and an error toast appears;
- Save: the same recovery occurs, with no source overwrite;
- Copy: the rendered image/cloud URL that was already copied remains on the
  clipboard, while the editor reopens with the pending annotations and the
  error toast;
- URL-only open (no Quick Access item): the explicit snapshot is used to
  reopen and the next close still treats it as unsaved;
- a normal successful Save/Copy still closes once and does not show the error
  toast.

Do not use real credentials in screenshots or logs. Do not enable test sounds
or Screen Recording integration flags for the default XCTest run.

**Verify**: focused/default commands exit 0 and all manual recovery cases are
recorded before marking the plan done.

## Test plan

- Reuse `AnnotateCoreTests`, `AnnotateExportSaveTests`, and
  `AnnotationSessionStoreTests` for the pure/state/file/sidecar contracts.
- Do not add a global `NSPanel` toast test or a network/cloud test; both would
  be nondeterministic without a new test seam that is not justified here.
- The controller recovery contract is validated by the manual failure matrix
  above and by source review: every detached failure exits through the same
  MainActor helper, and no failure path clears the pending snapshot.
- Full verification: `make test` → default quiet XCTest suite passes.

## Done criteria

- [ ] Normal local Save, Save-and-Close, and Copy no longer discard a failed
      rendered-file commit result.
- [ ] Render-snapshot failure, render failure, and file-write failure all show
      the existing localized error toast and attempt the same snapshot-based
      recovery.
- [ ] Recovery reopening preserves the explicit snapshot for URL-only opens and
      for matching Quick Access items, and marks only recovery opens dirty.
- [ ] Successful local commits retain current instant-close, thumbnail,
      sidecar, clipboard, and cloud-stale behavior.
- [ ] `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateCoreTests -only-testing:NotinhasTests/AnnotateExportSaveTests` exits 0.
- [ ] `make format-check`, `make lint-changed`, `make agent-check`, and
      `make test` exit 0.
- [ ] `./scripts/verify-local.sh --base af7e2e99 --plan-only` exits 0 with its
      manual-required output recorded.
- [ ] Manual Save, Save-and-Close, Copy, URL-only recovery, and successful
      no-toast checks are recorded.
- [ ] No files outside Scope are modified; the Plan 087 status row is updated
      after delivery.

## STOP conditions

Stop and report instead of improvising if:

- the session snapshot is not available before any normal source-backed fast
  close and making it available requires changing persistence format;
- `AnnotateManager.openAnnotation(url:sessionData:)` cannot restore a supplied
  snapshot without changing sidecar signature semantics;
- reopening a failed commit would create duplicate live windows or clear the
  Quick Access cache in a normal existing-item flow;
- marking the recovery-opened state dirty changes normal session restoration;
- showing `AppToastManager` requires a new presenter, new localization key, or
  a new global state abstraction;
- a detached failure still captures live `AnnotateState` or a closed window;
- the fix requires changing cloud, exporter, sidecar, clipboard, or Quick
  Access timer implementations;
- a focused test or delivery gate fails twice after a reasonable fix attempt;
- the working tree contains unrelated changes in an in-scope file.

## Maintenance notes

- The pending flag is a recovery marker, not a general “restored session is
  dirty” rule. Keep normal sidecar/session opens clean.
- Do not persist a pending snapshot as a committed sidecar while the source file
  still has its old signature; the source and sidecar must remain coherent.
- If repeated failures show that reopening is too disruptive, measure that UX
  first and propose a separate retry/pending-session design rather than adding
  a queue to this path.

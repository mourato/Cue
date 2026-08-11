# Plan 085: Consolidate Annotate's local rendered-file commit tail

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. This plan assumes Plan 084 is integrated and its
> route tests are green. When done, update the status row for this plan in
> `plans/README.md` unless a reviewer dispatched you and told you they maintain
> the index.
>
> **Drift check (run first)**:
> `git diff --stat de1779c5..HEAD -- Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift Notinhas/Features/Annotate/Services/AnnotateExporter.swift Notinhas/Features/Annotate/Services/AnnotationSessionStore.swift Notinhas/Services/Capture/PostCaptureActionHandler.swift NotinhasTests/Features/Annotate/AnnotateExporterTests.swift NotinhasTests/Features/Annotate/AnnotationSessionStoreTests.swift plans/README.md`
> The exporter, session store, and post-capture handler are read-only
> dependencies in this plan. If their contracts drift, compare the excerpts
> below before proceeding; do not silently broaden Scope.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: [Plan 084](084-annotate-commit-routing.md)
- **Category**: tech-debt
- **Planned at**: commit `de1779c5`, 2026-08-10

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — three async save paths share the same controller
  helper and must preserve their different clipboard behavior.
- **Reviewer required**: yes — the refactor changes file-write scheduling and
  crosses MainActor/background boundaries in a user-data path.
- **Rationale**: Existing off-main writer and sidecar helpers already provide
  the needed seam. A local helper in the controller is the smallest change
  that removes duplication without creating a new service or protocol.
- **Escalate when**: The helper needs cloud upload, Save As, Quick Access
  ownership, a new dependency-injection protocol, or a change to commit
  failure semantics.

## Why this matters

The normal Save, Save-and-Close, and Copy paths all capture a rendered image,
close the window, and then repeat the same background file-write → sidecar
persist sequence. Save-and-Close already uses `saveToFileOffMain`, while Save
and Copy still capture the live `AnnotateState` and call the MainActor writer
from a detached task. Reuse one narrow controller helper around the existing
off-main primitives so the ownership and ordering are obvious without merging
cloud, Save As, or Quick Access behavior.

## Current state

The relevant contracts are already present:

- `Notinhas/Features/Annotate/Models/AnnotateRenderSnapshot.swift:10-16`
  — render inputs are frozen on MainActor and then consumed off-main; the
  snapshot is the existing concurrency seam.
- `Notinhas/Features/Annotate/Services/AnnotateExporter.swift:79-101`
  — `saveToFile(image:state:)` writes the rendered image to the state's source
  URL and records the history mutation, but the method is MainActor-isolated.
- `Notinhas/Features/Annotate/Services/AnnotateExporter.swift:103-125`
  — `saveToFileOffMain(image:sourceURL:)` encodes off-main and hops to MainActor
  only for scoped access and history bookkeeping.
- `Notinhas/Features/Annotate/Services/AnnotationSessionStore.swift:75-92`
  — `persist` and `persistOffMain` write the editable sidecar; the latter is
  the intended background path.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:658-667`
  — Save-and-Close writes off-main, then persists the committed sidecar, then
  re-copies the edited screenshot when that preference is enabled.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:1042-1054`
  — Save closes immediately but captures `state` for a detached task and calls
  the MainActor `saveToFile` before sidecar persistence and edited-capture
  clipboard copy.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:1211-1219`
  — Copy closes immediately and repeats the same write/sidecar tail, but does
  not call edited-capture clipboard automation because it already placed the
  rendered image or cloud URL on the clipboard before closing.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:1437-1475`
  — session snapshots and their MainActor/off-main persistence wrappers live
  in the controller already.
- `Notinhas/Services/Capture/PostCaptureActionHandler.swift:252-275`
  — edited-capture clipboard automation is serialized by the existing handler;
  call it only after a successful local file write on Save and Save-and-Close.

The target helper should remain local to `AnnotateWindowController` and have
the following behavior:

```swift
private nonisolated static func persistRenderedFileOffMain(
    image: NSImage?,
    sourceURL: URL?,
    sessionSnapshot: AnnotationSessionData?,
    copyEditedCapture: Bool,
) async -> Bool {
    guard let image,
          let sourceURL,
          await AnnotateExporter.saveToFileOffMain(image: image, sourceURL: sourceURL)
    else { return false }

    await persistCommittedSessionOffMain(sessionSnapshot, for: sourceURL)
    if copyEditedCapture {
        await PostCaptureActionHandler.shared.copyEditedCaptureToClipboardIfEnabled(
            for: .screenshot,
            url: sourceURL,
        )
    }
    return true
}
```

The exact spelling may follow repository formatting, but the ownership and
ordering are load-bearing:

1. Encode/write the already-rendered image.
2. Only after a successful write, persist the sidecar.
3. Only for Save and Save-and-Close, run edited-capture clipboard automation.

`state.markAsSaved()`, the in-memory session cache, Quick Access thumbnail
updates, cloud-stale flags, `forceClose()`, cloud upload, and Save As remain at
their current owners and ordering. The helper must not receive `AnnotateState`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Drift | `git diff --stat de1779c5..HEAD -- Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift Notinhas/Features/Annotate/Services/AnnotateExporter.swift Notinhas/Features/Annotate/Services/AnnotationSessionStore.swift Notinhas/Services/Capture/PostCaptureActionHandler.swift NotinhasTests/Features/Annotate/AnnotateExporterTests.swift NotinhasTests/Features/Annotate/AnnotationSessionStoreTests.swift plans/README.md` | No unreviewed drift in the referenced contracts |
| Route prerequisite | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateCoreTests` | Exit 0; Plan 084 routing tests pass |
| Focused persistence tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateExporterTests -only-testing:NotinhasTests/AnnotationSessionStoreTests -only-testing:NotinhasTests/AnnotateRenderSnapshotTests` | Exit 0; off-main writer, sidecar, and snapshot tests pass |
| Formatting | `make format-check` | Exit 0; no SwiftFormat violations |
| Changed-file lint | `make lint-changed` | Exit 0; no changed Swift lint violations |
| Project gate | `make agent-check` | Exit 0; planner/check reports no unhandled changed surface |
| Plan surface | `./scripts/verify-local.sh --base de1779c5 --plan-only` | Exit 0; reports XCTest coverage plus the manual-required Annotate application path |
| Full default suite | `make test` | Exit 0; no new failures |

## Suggested executor toolkit

- Use `.agents/skills/testing-xctest/SKILL.md` for async XCTest and the quiet
  test environment.
- Use `.agents/overlays/swift-conventions.md` for Swift 6.2 strict-concurrency
  and formatter/lint expectations.
- Use `.agents/overlays/code-quality.md`: keep one local owner, reuse the
  existing `AnnotateExporter` and `AnnotationSessionStore` seams, and do not
  create a generic commit service.
- Use `.agents/skills/plan-execute-review/SKILL.md` for the downstream execution
  and review loop.

## Scope

**In scope** — the only files to modify:

- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift`
- `NotinhasTests/Features/Annotate/AnnotateExporterTests.swift`
- `NotinhasTests/Features/Annotate/AnnotationSessionStoreTests.swift`
- `plans/README.md` status row

The following are read-only dependencies and must not be modified by this
plan: `AnnotateExporter.swift`, `AnnotationSessionStore.swift`,
`PostCaptureActionHandler.swift`, `QuickAccessManager.swift`, and all cloud
providers.

**Out of scope**:

- `performCloudReUploadAndClose()` and
  `performCloudReUploadCopyAndClose()`; their upload, old-object deletion,
  fallback, and cloud-link clipboard semantics need a separate plan;
- `performSaveAs()`, combine dialog behavior, manual-combine source safety,
  drag-to-app, Notinha rendering, and `AnnotateState` decomposition;
- moving `AnnotateExporter`, `AnnotationSessionStore`, or
  `PostCaptureActionHandler` into a new module;
- changing Quick Access thumbnail generation, generation guards, cloud-stale
  state, or window-close timing;
- adding protocols, mocks, or dependency injection solely to unit-test the
  AppKit controller.

## Git workflow

- Branch: `advisor/085-annotate-local-commit-tail`
- Commit: `refactor(annotate): share local rendered-file commit tail`
- Do not push or open a PR unless the operator instructs it.

## Steps

### Step 1: Lock the existing off-main writer contracts

Extend `NotinhasTests/Features/Annotate/AnnotateExporterTests.swift` with an
async test that creates a small temporary PNG source URL, creates a rendered
`NSImage`, calls `await AnnotateExporter.saveToFileOffMain(image:sourceURL:)`,
and verifies the call succeeds and the destination remains a readable image
with the expected pixel dimensions. Add a failure case for a missing source
directory or otherwise unwritable destination only if it can be deterministic
without changing global permissions; do not add a flaky filesystem test.

Extend `NotinhasTests/Features/Annotate/AnnotationSessionStoreTests.swift` with
an async `persistOffMain` round-trip using the existing temporary source/session
fixtures. Assert that the sidecar loads and preserves the annotation count and
Notinhas note payload. Keep the existing `shouldPersist` policy out of this
test; it is a separate MainActor decision owned by the controller wrapper.

**Verify**:

```sh
./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateExporterTests -only-testing:NotinhasTests/AnnotationSessionStoreTests
```

Expected: exit 0, including the new async writer and sidecar tests.

### Step 2: Add the narrow controller helper

In `AnnotateWindowController.swift`, add the private nonisolated helper
described in "Current state" near the existing
`persistCommittedSessionOffMain` wrapper. It must accept frozen values only:
rendered image, source URL, session snapshot, and the explicit
`copyEditedCapture` flag. Do not capture `AnnotateState` in the helper or in
the detached tasks after this step.

Use `AnnotateExporter.saveToFileOffMain`, not
`AnnotateExporter.saveToFile(image:state:)`. Preserve the current failure
short-circuit: if the image/source is absent or the file write fails, do not
persist the sidecar and do not run edited-capture clipboard automation.

**Verify**: `make format-check && make lint-changed` → exit 0; the helper is
nonisolated, uses no unchecked concurrency escape, and references only the
existing off-main seams.

### Step 3: Route all three local paths through the helper

Update only the local execution paths:

1. `executeSaveAndClose()` keeps its frozen render snapshot, instant thumbnail,
   authoritative Quick Access update, close timing, and generation guard. Replace
   only its repeated write → sidecar → edited-clipboard tail with the helper,
   passing `copyEditedCapture: true`.
2. `executeSave()` keeps MainActor render, state/cache/thumbnail updates, and
   immediate close. Stop capturing `state` for the detached task; pass its
   already-rendered image, captured source URL, and session snapshot to the
   helper with `copyEditedCapture: true`.
3. `executeCopy()` keeps its immediate cloud-link/image clipboard behavior,
   manual-combine early return, state/cache/thumbnail updates, and close. Use
   the helper with `copyEditedCapture: false`.

Do not change the route switch from Plan 084, the `performSaveAs()` branch, or
either cloud re-upload method. The local helper may be called three times; do
not make it a new top-level service.

**Verify**:

```sh
./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateCoreTests -only-testing:NotinhasTests/AnnotateExporterTests -only-testing:NotinhasTests/AnnotationSessionStoreTests -only-testing:NotinhasTests/AnnotateRenderSnapshotTests
rg -n "persistRenderedFileOffMain|saveToFile\(image: renderedImage, state: capturedState\)" Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift
```

Expected: exit 0; the helper has one definition and three local call sites,
and the old detached-task call using `capturedState` is absent. Existing cloud
methods may still use their own synchronous save path; that is intentional.

### Step 4: Run the delivery gates and manual handoff

Run `make format-check`, `make lint-changed`, `make agent-check`,
`./scripts/verify-local.sh --base de1779c5 --plan-only`, and `make test`.
Record any manual-required output. On macOS, manually verify:

- a normal source-backed Annotate Save updates the source file, Quick Access
  thumbnail, editable sidecar, and edited-capture clipboard when enabled;
- Copy still puts the rendered image or existing cloud URL on the clipboard,
  then writes the source-backed render without invoking a second clipboard
  automation pass;
- closing an edited window and choosing Save produces the same persisted file
  and sidecar result;
- manual combine Copy still avoids overwriting the picked source file;
- two quick saves do not regress the existing Quick Access generation guard.

Cloud re-upload is not a required manual gate for this plan because those
methods are out of scope; note that they were not changed.

**Verify**: commands exit 0, manual checklist is recorded, and `git status -sb`
shows only Scope files before the executor commits.

## Test plan

- `AnnotateExporterTests`: async success contract for
  `saveToFileOffMain(image:sourceURL:)`.
- `AnnotationSessionStoreTests`: async sidecar round-trip through
  `persistOffMain`.
- Existing `AnnotateRenderSnapshotTests`: confirm frozen render parity remains
  green; do not weaken byte-equivalence expectations.
- Existing `AnnotateCoreTests`: Plan 084 routing precedence remains green.
- Full verification: `make test` → default quiet suite passes.
- Manual Annotate/clipboard smoke is required because the controller path is
  application code and `scripts/verification-map.tsv` marks `Notinhas/**` as
  manual-required.

## Done criteria

- [ ] One private nonisolated controller helper owns local
      rendered-image write → sidecar persist → optional edited-clipboard order.
- [ ] `executeSaveAndClose`, `executeSave`, and `executeCopy` pass frozen values
      to that helper; no detached task captures `AnnotateState` for local file
      persistence.
- [ ] Save and Save-and-Close pass `copyEditedCapture: true`; Copy passes
      `false`.
- [ ] Sidecar persistence and edited-capture clipboard automation occur only
      after a successful file write.
- [ ] `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateExporterTests -only-testing:NotinhasTests/AnnotationSessionStoreTests -only-testing:NotinhasTests/AnnotateRenderSnapshotTests` exits 0.
- [ ] `make format-check`, `make lint-changed`, `make agent-check`, and `make test` exit 0.
- [ ] `./scripts/verify-local.sh --base de1779c5 --plan-only` exits 0 and its
      manual-required output is recorded.
- [ ] Manual Save, Copy, close-with-save, manual-combine, and rapid-save checks
      are recorded.
- [ ] No files outside Scope are modified; `plans/README.md` status row is
      updated after delivery.

## STOP conditions

Stop and report instead of improvising if:

- `saveToFileOffMain` or `persistOffMain` no longer has the contracts quoted
  above;
- the helper would need to know `AnnotateState`, render again, mutate Quick
  Access, upload/delete cloud objects, or decide Save As;
- preserving current behavior requires moving state/cache/thumbnail/close
  effects into the helper;
- the manual-combine or cloud methods need modification to make local calls
  compile;
- a test demonstrates that the current Copy path intentionally requires
  edited-capture clipboard automation a second time;
- a focused test or build check fails twice after a reasonable fix attempt;
- an unrelated change is present in an in-scope file.

## Maintenance notes

- This is deliberately a local helper, not a generic commit module. Revisit
  that decision only when a second concrete owner needs the same file-write
  transaction and its failure semantics are compatible.
- A future cloud plan may reuse the file-write portion only after specifying
  upload failure, old-object cleanup, state mutation, and clipboard fallback
  semantics separately.
- The render snapshot remains the boundary for background rendering; do not
  make `AnnotateExporter` reach back into `AnnotateState`.
- The large `AnnotateState` and shared selection architecture remain separate
  workstreams. Do not mix their decomposition into this commit-tail change.

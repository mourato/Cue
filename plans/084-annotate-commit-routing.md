# Plan 084: Make Annotate commit routing explicit and testable

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. This plan must preserve the current Save, Copy,
> Save-and-Close, combine, and cloud-gate behavior. When done, update the
> status row for this plan in `plans/README.md` unless a reviewer dispatched
> you and told you they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat de1779c5..HEAD -- Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift NotinhasTests/Features/Annotate/AnnotateCoreTests.swift plans/README.md`
> If any listed path changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. On a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `de1779c5`, 2026-08-10

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — the routing policy, its tests, and the three
  Annotate entry points must move together.
- **Reviewer required**: yes — this policy encodes product safety rules for
  manual combine files and cloud-overwrite confirmation.
- **Rationale**: The change is small and pure at its core, but it changes the
  control flow of a MainActor AppKit controller and establishes the contract
  used by Plan 085.
- **Escalate when**: Routing requires a new persistence/cloud abstraction,
  changes source-file write rules, or requires changing `AnnotateState` or an
  AppKit window lifecycle test.

## Why this matters

`AnnotateWindowController` currently repeats the same precedence decisions in
Save-and-Close, Save, and Copy: combine confirmation, cloud overwrite, manual
combine protection, and the normal operation. Those branches are not covered
by a dedicated controller test, so a future extraction can accidentally make
Copy overwrite a manually selected combine source or bypass the cloud gate.
Make only the routing decision pure and explicit; leave all rendering,
file-writing, clipboard, Quick Access, and window effects in their existing
methods.

## Current state

The app is a macOS Swift 6.2 app with complete strict concurrency and
nonisolated-by-default targets. UI and lifecycle code remains explicitly
`@MainActor`; pure policy types should not be actor-isolated. The product
workflow is capture → Annotate → clipboard-ready output. A route policy must
not broaden that workflow into recording, cloud, or generic editor behavior.

Relevant current code:

- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:37-44`
  — `@MainActor` controller owning the Annotate window and state.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:13-35`
  — existing pure `AnnotateDragCompletionPolicy` precedent for a small
  testable policy beside the controller.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:400-402`
  — cloud overwrite is required when a cloud URL exists and the rendered
  output is stale or required for sharing.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:974-995`
  — `combineSaveNeedsDialog` takes precedence for combine Save flows, while
  `protectsSourceFromImplicitCombineWrite` protects manual-combine source files
  on implicit-write paths.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:578-596`
  — Save-and-Close checks combine dialog, then cloud overwrite, then local
  Save-and-Close.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:999-1017`
  — Save checks image presence, then combine dialog, then cloud overwrite,
  then local Save.
- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift:1151-1169`
  — Copy checks image presence, then manual-combine source protection, then
  cloud overwrite, then local Copy.
- `NotinhasTests/Features/Annotate/AnnotateCoreTests.swift:53-96`
  — existing tests for `AnnotateDragCompletionPolicy`; use this file and style
  for the new pure routing tests.
- There is no `AnnotateWindowControllerTests.swift`; full AppKit controller
  lifecycle coverage is intentionally not introduced by this plan.

The route table to preserve is:

| Action | Precedence and result |
|---|---|
| Save-and-Close | `combineSaveNeedsDialog` → `.combineDialog`; otherwise `requiresCloudOverwriteConfirmation` → `.cloudReuploadAndClose`; otherwise `.saveAndClose`. `executeSaveAndClose()` continues to handle its own Save As fallback when there is no source URL. |
| Save | `hasImage == false` → `.noOp`; otherwise `combineSaveNeedsDialog` → `.combineDialog`; otherwise cloud confirmation → `.cloudReuploadAndClose`; otherwise `.save`. `executeSave()` continues to route no source URL to Save As. |
| Copy | `hasImage == false` → `.noOp`; otherwise `protectsSourceFromImplicitCombineWrite` → `.copyWithoutSourceWrite` even if cloud confirmation is otherwise true; otherwise cloud confirmation → `.cloudReuploadAndCopy`; otherwise `.copy`. |

Do not add `sourceURL` to the pure routing input. Save As remains an existing
fallback inside the execution methods, and changing that ownership would widen
this plan.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Drift | `git diff --stat de1779c5..HEAD -- Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift NotinhasTests/Features/Annotate/AnnotateCoreTests.swift plans/README.md` | Empty output on the clean baseline, or a reviewed drift report before proceeding |
| Focused tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateCoreTests` | Exit 0; routing and existing Annotate core tests pass |
| Formatting | `make format-check` | Exit 0; no SwiftFormat violations |
| Changed-file lint | `make lint-changed` | Exit 0; no changed Swift lint violations |
| Project gate | `make agent-check` | Exit 0; planner/check reports no unhandled changed surface |
| Plan surface | `./scripts/verify-local.sh --base de1779c5 --plan-only` | Exit 0; reports the focused XCTest selector and any `manual-required` application check |
| Full default suite | `make test` | Exit 0; no new failures |

## Suggested executor toolkit

- Use `.agents/skills/testing-xctest/SKILL.md` for XCTest placement and the
  quiet-test rules.
- Use the global `code-quality` guidance plus
  `.agents/overlays/code-quality.md`: reuse the existing policy pattern and do
  not create a protocol or service for this pure decision.
- Use `.agents/skills/plan-execute-review/SKILL.md` for the downstream execution
  and review loop after this plan is selected.

## Scope

**In scope** — the only production/test files to modify:

- `Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift`
- `NotinhasTests/Features/Annotate/AnnotateCoreTests.swift`
- `plans/README.md` status row

**Out of scope**:

- `AnnotateExporter`, `AnnotationSessionStore`, `PostCaptureActionHandler`,
  `QuickAccessManager`, `CloudManager`, and all persistence or clipboard
  implementations;
- the bodies of `executeSaveAndClose`, `executeSave`, `executeCopy`,
  `performCloudReUploadAndClose`, and `performCloudReUploadCopyAndClose`,
  except for replacing the three top-level routing branches;
- Save As dialogs, transparency-loss confirmation, drag-to-app, Notinha
  rendering, `AnnotateState`, and any capture or selection host;
- new protocols, dependency injection, a generic `AnnotateCommitCoordinator`,
  or a new source module.

## Git workflow

- Branch: `advisor/084-annotate-commit-routing`
- Commit: `refactor(annotate): centralize commit routing`
- Do not push or open a PR unless the operator instructs it.

## Steps

### Step 1: Add the pure route model beside the existing drag policy

In `AnnotateWindowController.swift`, add a small internal, non-actor-isolated
policy next to `AnnotateDragCompletionPolicy`. Keep the names coherent with the
following shape (minor naming adjustments are acceptable only if the tests and
call sites remain equally explicit):

```swift
enum AnnotateCommitAction: Equatable {
    case saveAndClose
    case save
    case copy
}

enum AnnotateCommitRoute: Equatable {
    case noOp
    case combineDialog
    case cloudReuploadAndClose
    case cloudReuploadAndCopy
    case saveAndClose
    case save
    case copyWithoutSourceWrite
    case copy
}

enum AnnotateCommitRouting {
    static func route(
        for action: AnnotateCommitAction,
        hasImage: Bool,
        combineSaveNeedsDialog: Bool,
        protectsSourceFromImplicitCombineWrite: Bool,
        requiresCloudOverwriteConfirmation: Bool,
    ) -> AnnotateCommitRoute { ... }
}
```

Implement the route table in "Current state" exactly. Keep the precedence
visible in the switch. Do not pass `AnnotateState`, `URL`, `NSWindow`, or a
manager into the policy.

**Verify**: `make format-check` → exit 0; the policy is pure Swift and no new
actor or unchecked-concurrency escape appears.

### Step 2: Add exhaustive route tests

Extend `NotinhasTests/Features/Annotate/AnnotateCoreTests.swift` with behavior
named tests covering at least:

- Save-and-Close: combine dialog wins over cloud; cloud wins over normal save;
  normal route otherwise.
- Save: no image is a no-op; combine wins over cloud; cloud wins over normal
  save; normal route otherwise.
- Copy: no image is a no-op; manual-combine source protection wins over cloud;
  cloud route otherwise; normal copy otherwise.
- The policy does not need a source URL and therefore cannot accidentally
  absorb Save As behavior.

Use `XCTAssertEqual` against `AnnotateCommitRoute` and avoid constructing an
`AnnotateWindowController`. Follow the existing drag-policy tests in the same
file.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateCoreTests` → exit 0, including all new route cases.

### Step 3: Route the three entry points through the policy

Replace only the duplicated decision trees in `performSaveAndClose()`,
`performSave()`, and `performCopy()` with calls to
`AnnotateCommitRouting.route(...)` and switches that invoke the existing
methods:

- `.combineDialog` → `performCombineSave()`;
- `.cloudReuploadAndClose` → `performCloudReUploadAndClose()`;
- `.cloudReuploadAndCopy` → `performCloudReUploadCopyAndClose()`;
- `.saveAndClose` → `executeSaveAndClose()`;
- `.save` → `executeSave()`;
- `.copyWithoutSourceWrite` and `.copy` → `executeCopy()`; the latter keeps
  the existing internal protection branch for safety;
- `.noOp` → return.

Keep the current no-image behavior for Save and Copy by routing it to `.noOp`
(the initial guards may be replaced by the policy switch if that leaves the
observable behavior identical). Do not add a new guard to Save-and-Close.
Leave `executeSave()` and `executeSaveAndClose()` responsible for Save As when
their source URL is absent. Do not modify cloud upload behavior.

**Verify**:

```sh
./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateCoreTests
rg -n "AnnotateCommitRouting\.route" Notinhas/Features/Annotate/Managers/AnnotateWindowController.swift
```

Expected: exit 0; the route call appears at the three entry points; the old
`combineSaveNeedsDialog`/cloud/protection precedence is no longer repeated as
three independent `if` ladders.

### Step 4: Run delivery checks and record the plan status

Run the focused tests, formatter, changed-file lint, `make agent-check`,
`./scripts/verify-local.sh --base de1779c5 --plan-only`, and `make test`.
The verification planner may report a manual-required Annotate application
surface; keep that report visible rather than suppressing it.

**Verify**: all commands exit 0, except an explicitly documented
environment-only/manual-required gate; `git status -sb` contains only the
files listed in Scope until the executor commits.

## Test plan

- Add pure truth-table coverage to
  `NotinhasTests/Features/Annotate/AnnotateCoreTests.swift`.
- Keep existing render, session, and post-capture tests unchanged; they cover
  lower-level effects and are not substitutes for route precedence.
- Focused verification:
  `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateCoreTests`
  → all route and existing core tests pass.
- Full verification: `make test` → default quiet XCTest suite passes.
- Manual smoke after implementation: open a normal Annotate session and invoke
  Save, Copy, and close-with-save once; then verify a manual combine Copy path
  does not overwrite the picked source. This is a behavior safety check, not a
  reason to expand the plan into cloud or capture UI work.

## Done criteria

- [ ] `AnnotateCommitRouting` is a pure policy with no `AnnotateState`, AppKit,
      file, cloud, or clipboard dependency.
- [ ] The precedence table is covered by tests in `AnnotateCoreTests`.
- [ ] Save-and-Close, Save, and Copy call the policy; existing execution
      methods still own their side effects and Save As fallback.
- [ ] `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateCoreTests` exits 0.
- [ ] `make format-check`, `make lint-changed`, `make agent-check`, and `make test` exit 0.
- [ ] `./scripts/verify-local.sh --base de1779c5 --plan-only` exits 0 and its
      manual-required output is recorded.
- [ ] No files outside Scope are modified; `plans/README.md` status row is
      updated after delivery.

## STOP conditions

Stop and report instead of improvising if:

- the current route precedence differs from the table in this plan;
- a route needs `sourceURL`, `AnnotateState`, a manager, or a new protocol to
  decide what to do;
- changing the entry points would alter Save As, manual-combine source
  protection, cloud confirmation, or no-image behavior;
- the implementation requires editing cloud, persistence, exporter, capture,
  or UI files outside Scope;
- a focused test or build check fails twice after a reasonable fix attempt;
- the working tree contains unrelated changes in an in-scope file.

## Maintenance notes

- Plan 085 depends on this route policy and may reuse its explicit operations.
- Keep the route table updated if a new Annotate command is added; add the
  pure case and its tests before adding another branch to the controller.
- Do not turn this policy into a generic commit service. A second concrete
  owner is required before extracting a shared module.
- Cloud re-upload and Save As failure semantics remain deliberately outside
  this plan and require their own evidence before consolidation.

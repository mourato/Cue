# Plan 088: Preserve Undo when creating text from the Annotate canvas

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. This is a narrow mutation-boundary fix, not a
> decomposition of `AnnotateState`. When done, update the status row for this
> plan in `plans/README.md` unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat f67a3ab9..HEAD -- Notinhas/Features/Annotate/AnnotateState.swift Notinhas/Features/Annotate/Components/AnnotateCanvasDrawingView.swift NotinhasTests/Features/Annotate/AnnotateCoreTests.swift`
> If any in-scope file changed, compare the excerpts below before proceeding;
> on a mismatch, stop and report.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `f67a3ab9`, 2026-08-11

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: yes — independent from the cloud/commit workstream;
  serialize only if another change is editing `AnnotateCoreTests.swift`.
- **Reviewer required**: yes — Undo is a user-visible editing invariant and
  the review must confirm that text editing still avoids duplicate checkpoints.
- **Rationale**: The bug is a single missing state-owned transaction at an
  existing mutation boundary. The smallest safe fix is one state method,
  one canvas call-site change, and a regression test; no protocol or state
  split is needed.
- **Escalate when**: Fixing the behavior requires changing text layout,
  `TextEditOverlay` cancellation semantics, the general undo model, or more
  than the three source/test files in Scope.

## Why this matters

The real canvas path creates a new empty text annotation by appending directly
to `state.annotations`, then starts text editing with `recordsUndo: false`.
Unlike shape creation, it does not save a pre-creation snapshot. As a result,
after the user types and commits, Undo cannot remove the newly created text.
The existing test is a false positive because it manually calls `saveState()`
before reproducing the mutation. Make the creation transaction state-owned and
test it without that manual checkpoint.

## Current state

`AnnotateState` is a large `@MainActor`-owned `ObservableObject` with existing
undo, text-editing, selection, auto-width, and callout-tail methods. Keep the
new method beside those responsibilities; do not split the 5,355-line type.

Relevant current code:

- `Notinhas/Features/Annotate/Components/AnnotateCanvasDrawingView.swift:1450-1471`
  computes the initial bounds in the view, appends the empty item directly,
  enables automatic text width, prepares a callout tail, selects the item, and
  begins editing with `recordsUndo: false`.
- `Notinhas/Features/Annotate/AnnotateState.swift:2339-2341`
  defines `saveState()`, which pushes the current annotation snapshot before a
  mutation and updates Undo availability.
- `Notinhas/Features/Annotate/AnnotateState.swift:2442-2470`
  defines `beginTextEditing`; `recordsUndo: false` is intentional for a new
  item because the creation checkpoint should be the single Undo transaction.
- `Notinhas/Features/Annotate/AnnotateState.swift:3060-3094`
  updates text and geometry while typing and records a text-edit transaction
  only when one was created. A new empty item must therefore have its creation
  checkpoint before append.
- `NotinhasTests/Features/Annotate/AnnotateCoreTests.swift:927-945`
  currently calls `state.saveState()` manually before appending a text item;
  rewrite this test so it exercises the new state-owned creation method.
- `Notinhas/Features/Annotate/Components/AnnotateCanvasDrawingView.swift:1280-1290`
  is the nearby shape-creation precedent: it calls `state.saveState()` before
  appending the new annotation.

The target state transaction should accept the view-computed `CGRect` and
`AnnotationProperties`, create the empty `.text("")` item, call `saveState()`
before append, preserve the existing automatic-width/callout/selection setup,
and call `beginTextEditing(id:recordsUndo:false)`. Returning the new UUID is
optional; use it only if it keeps the canvas call site clearer.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Drift | `git diff --stat f67a3ab9..HEAD -- Notinhas/Features/Annotate/AnnotateState.swift Notinhas/Features/Annotate/Components/AnnotateCanvasDrawingView.swift NotinhasTests/Features/Annotate/AnnotateCoreTests.swift` | Empty on the planned baseline, or reviewed drift before proceeding |
| Focused tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateCoreTests` | Exit 0; the new creation/Undo regression passes |
| Formatting | `make format-check` | Exit 0; no SwiftFormat violations |
| Changed-file lint | `make lint-changed` | Exit 0; no changed Swift lint violations |
| Project gate | `make agent-check` | Exit 0; no unhandled changed surface |
| Plan surface | `./scripts/verify-local.sh --base f67a3ab9 --plan-only` | Exit 0; Annotate XCTest coverage is visible |
| Full default suite | `make test` | Exit 0; no new failures |

## Suggested executor toolkit

- Use `.agents/skills/testing-xctest/SKILL.md`: test the state behavior, not
  the full AppKit canvas host.
- Use the global `code-quality` and `swift-conventions` guidance: keep the
  transaction in `AnnotateState`, match existing naming/`// MARK:` layout, and
  do not create a protocol for one caller.
- Use `.agents/skills/capture-annotate-export/SKILL.md` to preserve the
  annotation editor's handoff loop while changing only editor history.

## Scope

**In scope** — the only production/test files to modify:

- `Notinhas/Features/Annotate/AnnotateState.swift`
- `Notinhas/Features/Annotate/Components/AnnotateCanvasDrawingView.swift`
- `NotinhasTests/Features/Annotate/AnnotateCoreTests.swift`
- `plans/README.md` status row

**Out of scope**:

- `AnnotateTextEditOverlay.swift` cancellation or live typing behavior;
- undo/redo model redesign, snapshot representation, or all other direct
  `annotations` assignments used by restoration and gesture previews;
- the broad `AnnotateState` decomposition candidate;
- text layout, callout geometry, tool defaults, persistence, rendering, cloud,
  clipboard, or any UI copy/localization.

## Git workflow

- Branch: `advisor/088-annotate-text-creation-undo`
- Commit: `fix(annotate): preserve undo for new text annotations`
- Do not push or open a PR unless the operator instructs it.

## Steps

### Step 1: Add the state-owned text creation transaction

In `AnnotateState.swift`, add one focused method beside the annotation/text
mutation methods. It should accept the already computed bounds and properties,
then perform this order:

1. `saveState()` while the new item is absent;
2. append `AnnotationItem(type: .text(""), bounds: ..., properties: ...)`;
3. call `useAutomaticTextWidth(for:)`;
4. call `prepareTextCalloutTail(for:)`;
5. select the new ID;
6. call `beginTextEditing(id: ..., recordsUndo: false)`.

Keep bounds calculation in `AnnotateCanvasDrawingView`; the state method owns
only the mutation and its invariants. Do not call `commitTextEditing()` or
create a second text-editing undo transaction.

**Verify**: `make format-check && make lint-changed` → exit 0; the new method
has no AppKit view/window dependency and calls `saveState()` before append.

### Step 2: Route the canvas through the transaction

Replace the direct `state.annotations.append(item)` plus the following setup in
`createTextAnnotation(at:)` with the new state method. Keep the current
`AnnotateTextLayout` bounds calculation and the empty-text behavior unchanged.
There must be no duplicate automatic-width, callout, selection, or text-edit
setup left in the view.

**Verify**:

```sh
rg -n "createTextAnnotation|annotations\\.append|beginTextEditing|useAutomaticTextWidth|prepareTextCalloutTail" Notinhas/Features/Annotate/Components/AnnotateCanvasDrawingView.swift Notinhas/Features/Annotate/AnnotateState.swift
```

Expected: the canvas has one state-method call and no direct append for this
new-text path; the state method contains the transaction setup.

### Step 3: Replace the false-positive test with the real contract

Rewrite `testAnnotateState_undoAfterNewTextCreationRemovesTextAnnotation()` in
`AnnotateCoreTests.swift` to call the new state method without a preceding
manual `saveState()`. Assert that it:

- creates exactly one text annotation and enters text editing;
- after committing non-empty text, leaves the annotation present;
- after `undo()`, removes the newly created annotation;
- after `redo()`, restores the text annotation and its committed text.

Use the returned ID if the method provides one; otherwise read the selected
annotation ID. Keep the existing text-edit Undo/Redo test unchanged unless the
new transaction reveals a documented duplicate checkpoint.

**Verify**:

```sh
./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateCoreTests
```

Expected: exit 0; the regression fails if the state method loses the
pre-creation checkpoint or creates a second competing text transaction.

### Step 4: Run delivery gates and perform one manual editor check

Run `make format-check`, `make lint-changed`, `make agent-check`,
`./scripts/verify-local.sh --base f67a3ab9 --plan-only`, and `make test`.

On macOS, open Annotate, choose the Text tool, click the canvas, type a
non-empty note, commit it, press Undo, and confirm the new text disappears;
press Redo and confirm it returns. Check that editing an existing text item
still undoes only the text edit and does not gain an extra creation checkpoint.

**Verify**: commands exit 0, the manual check is recorded, and no unrelated
Annotate mutation path changed.

## Test plan

- `AnnotateCoreTests.testAnnotateState_undoAfterNewTextCreationRemovesTextAnnotation`
  becomes the direct regression test for the real state-owned creation path.
- Keep `AnnotateCoreTests`' existing text-edit and general Undo/Redo tests as
  compatibility coverage.
- Do not add an AppKit canvas-host test; `testing-xctest` keeps this behavior at
  the pure state boundary and the manual check covers the actual click/type UI.
- Full verification: `make test` → default quiet XCTest suite passes.

## Done criteria

- [ ] New text creation records its pre-append state checkpoint inside
      `AnnotateState`, not in a view or test.
- [ ] The canvas no longer mutates `state.annotations` directly for this
      creation transaction.
- [ ] New text → commit → Undo removes the annotation; Redo restores it.
- [ ] Existing text editing and cancellation behavior remains unchanged.
- [ ] `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateCoreTests` exits 0.
- [ ] `make format-check`, `make lint-changed`, `make agent-check`, and
      `make test` exit 0.
- [ ] `./scripts/verify-local.sh --base f67a3ab9 --plan-only` exits 0.
- [ ] Manual click/type/Undo/Redo verification is recorded.
- [ ] No files outside Scope are modified; the Plan 088 status row is updated
      after delivery.

## STOP conditions

Stop and report instead of improvising if:

- the canvas text path has already gained a state-owned transaction or its Undo
  semantics differ from the excerpt above;
- `beginTextEditing(recordsUndo: false)` must change to preserve existing text
  editing behavior;
- the smallest fix requires changing `TextEditOverlay`, text layout, or the
  general Undo/Redo representation;
- the test still needs a manual `saveState()` to pass after the new method is
  called;
- direct annotation assignment changes in restoration or gesture-preview paths
  appear necessary to make this fix compile;
- a focused test or delivery gate fails twice after a reasonable fix attempt;
- the working tree contains unrelated changes in an in-scope file.

## Maintenance notes

- This is the first narrow mutation boundary extracted from `AnnotateState`.
  Extract another boundary only when a second real caller needs the same
  coupled invariants and characterization tests exist first.
- Restoration assignments and gesture-local preview copies intentionally remain
  direct and out of scope; they do not represent interactive creation
  transactions.
- Review future text tools for the same rule: a new annotation must record its
  pre-mutation snapshot exactly once before entering live text editing.

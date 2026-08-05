# Plan 006: Move and delete Notinhas pins while the Note tool is active

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 18f2e96..HEAD -- Snapzy/Features/Notinhas Snapzy/Features/Annotate/Components/AnnotateCanvasDrawingView.swift SnapzyTests/Features/Notinhas`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none (can land before or after 004/005; no code dependency)
- **Category**: bug
- **Planned at**: commit `18f2e96`, 2026-07-20

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — gesture changes in `AnnotateCanvasDrawingView` need
  careful sequencing with create/select flows
- **Reviewer required**: `yes` — mouse gesture races (create vs move vs open
  editor) and undo checkpointing are easy to get wrong
- **Rationale**: Touches AppKit mouse/keyboard handling and undo; product
  behavior is specified but implementation has several edge cases.
- **Escalate when**: Selection-tool parity is requested (explicitly out of
  scope), or move must support resize handles like Counter.

## Why this matters

Users can place Notinhas pins, but cannot reposition them, and Delete does not
remove a selected pin the way Counter annotations do. Product decision:

- Keep the Notinhas model (not `AnnotationItem.counter`).
- **Only while the Note tool (`.notinhasNote`) is active**: drag to move;
  Delete/Backspace + existing editor/panel trash to delete.
- Selection tool must **not** start selecting/moving Notinhas pins in this plan.

## Current state

State API already supports add/update/delete/select
(`Snapzy/Features/Notinhas/Annotate/NotinhasAnnotateState.swift`) with
`saveState()` for undo on add/update/delete. There is **no** move API and no
drag-of-existing-note gesture.

**Critical coupling to design around**: `notinhasSelectNote(id:)` today does
**not** just select — it also sets `notinhasEditingNoteID = id`, which is what
opens the editor. There is no "select without editing" path:

```33:38:Snapzy/Features/Notinhas/Annotate/NotinhasAnnotateState.swift
  func notinhasSelectNote(id: UUID?) {
    notinhasSelectedNoteID = id
    if let id {
      notinhasEditingNoteID = id
    }
  }
```

This breaks two assumptions in the naive design below:

- "Mouse down on a note selects it *without* opening the editor" is impossible
  with the current `notinhasSelectNote`. You must add a select-only path
  (Step 2a) or the potential-move click will pop the editor on every mouse
  down.
- "Select a pin, then press Delete" has no reachable state today, because any
  selection also enters editing (editor open). See Step 4 and the revised test
  matrix for how a selected-not-editing pin actually occurs (post-move).

Canvas Note-tool handlers today
(`AnnotateCanvasDrawingView` ~1254–1291):

- Mouse down on existing note → select + **immediately** open editor.
- Mouse down on empty canvas → begin drawing a new note.
- Mouse drag/up only continue/commit **drawing**, not moving.
- `keyDown` Delete (keyCodes 51/117) only calls
  `state.deleteSelectedAnnotation()` for Annotate annotations — Notinhas
  selection is ignored:

```295:306:Snapzy/Features/Annotate/Components/AnnotateCanvasDrawingView.swift
  override func keyDown(with event: NSEvent) {
    // ...
    case 51, 117: // Delete, Forward Delete
      if state.hasSelectedAnnotations, state.editingTextAnnotationId == nil {
        Task { @MainActor in
          state.deleteSelectedAnnotation()
        }
        invalidateDrawing()
      }
```

Hit-testing already exists: `AnnotateState.notinhasNote(at:)` →
`NotinhasNoteGeometry.hitTest`.

Geometry constants: `NotinhasNoteGeometry.dragThreshold` (8pt) already used to
distinguish point vs rect **creation** — reuse the same threshold for
“click opens editor” vs “drag moves”.

Live side panel trash and editor Delete button already call
`notinhasDeleteNote` — keep them; this plan adds canvas Delete + drag move.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `./scripts/format.sh` | exit 0 |
| Tests | `./scripts/run-tests.sh` | all pass |
| Build | `xcodebuild -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug build` | `** BUILD SUCCEEDED **` |
| Manual run | `./scripts/build_and_run.sh` | app launches for gesture check |

## Scope

**In scope**:

- `Snapzy/Features/Notinhas/Annotate/NotinhasAnnotateState.swift`
- `Snapzy/Features/Notinhas/Services/NotinhasNoteGeometry.swift`
- `Snapzy/Features/Annotate/Components/AnnotateCanvasDrawingView.swift`
  (Notinhas handlers + Delete key branch only; minimal edits)
- `Snapzy/Features/Annotate/AnnotateState.swift` **only if** you must add
  published move-tracking properties next to existing `notinhas*` fields
  (prefer keeping move locals on the canvas view when possible)
- `SnapzyTests/Features/Notinhas/NotinhasAnnotateStateTests.swift`
- `SnapzyTests/Features/Notinhas/NotinhasNoteGeometryTests.swift`
- `plans/README.md` (status row only)

**Out of scope**:

- Selection-tool hit-testing / dragging of Notinhas pins
- Resize handles, multi-select, nudge arrows for notes
- Merging notes into `AnnotationItem.counter`
- Changing create-rect threshold behavior beyond reusing the constant
- Export compositor / badge drawing (plans 004/005)

## Git workflow

- Branch: `fix/notinhas-move-delete` (or `advisor/006-notinhas-move-delete`)
- Commit example: `fix: allow moving and deleting Notinhas pins with Note tool`
- Do NOT push or open a PR unless asked.

## Steps

### Step 1: Add pure geometry translation helpers

In `NotinhasNoteGeometry.swift`, add helpers roughly:

```swift
static func translated(
  _ target: NotinhasNoteTarget,
  by delta: CGPoint,
  within bounds: CGRect
) -> NotinhasNoteTarget

static func shouldBeginMove(dragDistance: CGFloat) -> Bool {
  dragDistance >= dragThreshold
}
```

Behavior:

- `.point`: new center = `clampedPoint(old + delta, within: bounds)`.
- `.rect`: translate origin by delta, then clamp so the full rect stays inside
  `bounds` (keep width/height; if rect is larger than bounds on an axis, clamp
  to the nearest legal origin — mirror how creation clamping works).

**Verify**: add unit tests in `NotinhasNoteGeometryTests.swift` for point and
rect translation + clamping. `./scripts/run-tests.sh` still green after step 2
wiring, but write the tests now.

### Step 2: Add state move APIs with a single undo checkpoint

In `NotinhasAnnotateState.swift` (extension on `AnnotateState`), add:

- `notinhasBeginMovingNote(id: UUID)` — remembers the note id being moved;
  does **not** call `saveState` yet.
- `notinhasUpdateMovingNote(to imagePoint: CGPoint, imageBounds: CGRect)` —
  or `notinhasTranslateMovingNote(by:within:)` — updates `target` live
  **without** `saveState` every frame.
- `notinhasCommitMovingNote()` — if the target actually changed from the
  pre-move snapshot, call `saveState()` once then clear move session; if no
  movement, clear without a checkpoint.
- `notinhasCancelMovingNote()` — restore pre-move target if needed / clear
  session without undo noise.

Store move session fields on `AnnotateState` next to other `notinhas*` vars
(`notinhasMovingNoteID`, `notinhasMoveStartPoint`, `notinhasMoveOriginalTarget`)
**or** keep them as private vars on `AnnotateCanvasDrawingView` and only call
`notinhasUpdateNote` once on mouse-up. Prefer **one undo checkpoint per
completed drag**:

- Option A (preferred): canvas holds originals; on mouse-up after a real move,
  `saveState()` then assign the new target via `notinhasUpdateNote` **or**
  mutate + single `saveState` carefully so undo restores the pre-drag target.
- Option B: `notinhasUpdateNote` already calls `saveState` — do **not** call it
  per drag frame. Only call it once when the drag ends (build a final note and
  update once).

Match existing undo tests style in `NotinhasAnnotateStateTests.swift`:
`testMovingNoteCreatesOneUndoCheckpoint`.

**Verify**: new XCTest proves one undo restores pre-move geometry.

### Step 2a: Add a select-only path (decouple selection from editing)

Because `notinhasSelectNote(id:)` currently forces `notinhasEditingNoteID`,
mouse-down cannot "just select". Add a way to select without opening the editor.
Prefer the smallest change:

- Option A (preferred): add a parameter with a safe default, e.g.
  `func notinhasSelectNote(id: UUID?, beginEditing: Bool = true)`, and set
  `notinhasEditingNoteID` only when `beginEditing` is true. Existing callers
  keep today's behavior; the canvas move path calls
  `notinhasSelectNote(id:, beginEditing: false)`.
- Option B: add a dedicated `notinhasSelectOnly(id: UUID?)` that sets only
  `notinhasSelectedNoteID`.

Neither call should mutate undo history (selection is not a `saveState` event —
matches current behavior).

**Verify**: `rg -n "beginEditing|notinhasSelectOnly" Snapzy/Features/Notinhas/Annotate/NotinhasAnnotateState.swift` → the new path exists; existing `notinhasSelectNote` callers still open the editor.

### Step 3: Change Note-tool mouse handling (create vs move vs edit)

Rewrite Notinhas mouse handlers in `AnnotateCanvasDrawingView` so that when
`selectedTool == .notinhasNote`:

1. **Mouse down on existing note**
   - Select it **without editing** via the Step 2a path
     (`notinhasSelectNote(id:, beginEditing: false)` or `notinhasSelectOnly`).
   - Start a *potential move* (store id, start point, original target).
   - Do **not** open the editor yet.
   - Do **not** begin drawing a new note.

   **Move hit region**: what counts as "on a note" for starting a move is
   whatever `state.notinhasNote(at:)` / `NotinhasNoteGeometry.hitTest` already
   returns. For `.rect` notes decide and document the region explicitly:
   - Recommended: allow the move to start anywhere the existing `hitTest`
     succeeds (badge **or** the rectangle area), so users can grab the whole
     annotation. Do **not** invent a badge-only grab region unless `hitTest`
     already restricts to the badge — if it does, keep that and note it.
   - Whatever you choose, the translation in Step 1 (`translated(_:by:within:)`)
     moves the entire target (badge follows the rect), so the visible grab
     behavior must match the region you accept here.

2. **Mouse drag**
   - If a potential move is active and
     `hypot(delta) >= NotinhasNoteGeometry.dragThreshold`, mark as moving and
     translate the note target (live redraw).
   - Else if drawing a new note (`notinhasIsDrawingNote`), keep existing
     create-rect behavior.
   - **Guard widening**: today `handleNotinhasMouseDragged` /
     `handleNotinhasMouseUp` early-return unless `notinhasIsDrawingNote`. A
     move is **not** a draw, so these guards must be widened to also run when a
     potential/active move session exists — otherwise the drag "falls through"
     to the generic annotation drag handling (create-vs-move race). Keep both
     the draw path and the move path reachable from the same handler.

3. **Mouse up**
   - If a move occurred: commit move (one undo), keep selection
     (still not editing), do **not** auto-open editor.
   - If mouse down was on a note but drag stayed under threshold: open editor
     (`presentNotinhasEditor` + set editing via the normal
     `notinhasSelectNote`/editor path) — preserves click-to-edit.
   - If drawing a new note: keep existing commit + open editor behavior.
   - Always clear the move session (id/start/original) on mouse up.

4. Empty-canvas mouse down still begins drawing as today.

Ensure `handleNotinhasMouseDown` still returns early when an editor is open
(existing dismiss-on-click-outside behavior).

**Verify**: code review of the three handlers; confirm the drag/up guards run
for a move (not only when drawing); build succeeds. Manual check listed in
Done criteria.

### Step 4: Delete / Forward Delete while Note tool is active

In `keyDown`, extend the Delete branch:

```swift
case 51, 117:
  if state.selectedTool == .notinhasNote,
     let noteID = state.notinhasSelectedNoteID,
     state.notinhasEditingNoteID == nil,   // do NOT hijack Delete while typing a note
     state.editingTextAnnotationId == nil {
    state.notinhasDeleteNote(id: noteID)
    dismissNotinhasEditor() // if helper exists / safe to call
    invalidateDrawing()
    return
  }
  if state.hasSelectedAnnotations, state.editingTextAnnotationId == nil {
    // existing annotation delete
  }
```

Rules:

- Only when Note tool is active (per product choice “1”).
- **Guard against active Notinhas editing**: require `notinhasEditingNoteID ==
  nil`. Because selecting a pin normally opens the editor, without this guard a
  Delete/Backspace pressed while typing a comment would delete the whole pin
  instead of a character. (The editor overlay's own text field will usually be
  first responder and consume the key, but keep this guard so the canvas branch
  is unambiguous even if focus routing changes.)
- A selected-but-not-editing pin — the state this branch actually fires in —
  arises after a drag-move (Step 3 keeps selection without editing), or if you
  expose a select-only interaction. Editor-open selection is intentionally not
  deletable via this key.
- Prefer Notinhas delete over annotation delete when both could apply.
- Keep editor/panel trash working unchanged.

**Verify**: unit-level coverage via state delete already exists; add a test only
if you introduce a new state helper. Manual: select pin with Note tool, press
Delete, pin and list row disappear; Undo restores.

### Step 5: Format, test, build

**Verify**: `./scripts/format.sh`; `./scripts/run-tests.sh`; Debug build.

## Test plan

- `NotinhasNoteGeometryTests`: translate point/rect; clamp inside bounds.
- `NotinhasAnnotateStateTests`: move commits exactly one undo checkpoint;
  cancel/no-op move creates none.
- Manual:
  1. Note tool → click empty → create + editor (unchanged).
  2. Note tool → click existing pin without dragging → editor opens.
  3. Note tool → drag existing pin → pin moves; editor does **not** open; pin
     stays selected (not editing); Undo restores position.
  4. Note tool → drag a pin slightly to leave it selected-not-editing (or use
     the select-only path) → press Delete → pin and list row disappear; Undo
     restores. (You cannot reach this by a plain click, since a click opens the
     editor — that is expected.)
  5. Note tool → open a pin's editor, type text, press Delete/Backspace →
     edits the comment text; the pin is **not** deleted (editing guard holds).
  6. Selection tool → click pin → must **not** drag/select as an annotation
     (unchanged; pins only interactive under Note tool).

## Done criteria

- [ ] A select-only path exists (Step 2a) so mouse-down can select a pin
      without opening the editor; existing `notinhasSelectNote` callers still
      open it
- [ ] Existing Notinhas notes can be dragged to a new position with Note tool
      (grab region for `.rect` notes documented and matches `hitTest`)
- [ ] Drag/up handlers run for a move even though `notinhasIsDrawingNote` is
      false (no fall-through to annotation drag)
- [ ] Sub-threshold click still opens the note editor
- [ ] Delete/Forward Delete removes `notinhasSelectedNoteID` when Note tool is
      active **and** no note is being edited (`notinhasEditingNoteID == nil`)
- [ ] Delete/Backspace while a note editor is open edits text and does not
      delete the pin
- [ ] A completed move creates exactly one undo checkpoint
- [ ] Selection tool still ignores Notinhas pins
- [ ] `./scripts/format.sh` exits 0
- [ ] `./scripts/run-tests.sh` exits 0
- [ ] Debug build succeeds
- [ ] No files outside the in-scope list are modified
- [ ] `plans/README.md` status row for 006 updated

## STOP conditions

- Implementing move appears to require Selection-tool integration — stop and
  report; do not expand scope.
- Undo cannot be limited to one checkpoint without rewriting Annotate's global
  history — stop and report with the attempted approach.
- Mouse handler structure drifted so Notinhas is no longer gated through
  `handleNotinhasMouseDown/Dragged/Up` — refresh plan before coding.
- Drag-to-create and drag-to-move cannot be disambiguated without breaking
  rect creation — stop rather than removing area notes.

## Maintenance notes

- If Selection-tool parity is desired later, that is a new plan (product
  choice “2”), not a silent follow-up inside this one.
- Reviewers should watch for `saveState()` inside drag-move frames (undo spam)
  and for editor opening on every mouse-up after a move.
- Reviewers should verify the Delete branch keeps the `notinhasEditingNoteID ==
  nil` guard, and that the new select-only path does not silently start
  editing (regression: click-to-move popping the editor).
- Arrow-key nudge for notes remains deferred.

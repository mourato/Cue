# Plan 001: Add the Notes editor extension

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, report it; do not improvise. Update this plan's row in
> `plans/README.md` only after the code-review gate passes.
>
> **Drift check (run first)**: `git diff --stat bad6da2..HEAD -- Snapzy/Features/Annotate Snapzy/Features/Notinhas SnapzyTests/Features/Annotate SnapzyTests/Features/Notinhas Snapzy/Resources/Localization`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `bad6da2`, 2026-07-20

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — it defines the shared Notes model and canvas seam.
- **Reviewer required**: yes — gesture handling, undo, and session persistence
  must remain compatible with upstream annotation flows.
- **Rationale**: This crosses AppKit canvas input, SwiftUI popover UI, editable
  sessions, and Core Graphics rendering.
- **Escalate when**: the work requires a broad rewrite of `AnnotateState`, a
  new global capture permission, or modifications outside the listed seams.

## Why this matters

Notinhas needs a precise visual-feedback primitive, not another generic shape:
a numbered pin plus a short note, optionally attached to a selected region.
The feature must behave like a self-contained extension so future Snapzy
updates remain mergeable. It must also share the editor's coordinate system,
undo behavior, and persisted session lifecycle.

## Current state

- `Snapzy/Features/Annotate/Models/AnnotateAnnotationToolType.swift` is a
  closed tool enum; `drawableTools` drives the toolbar and the inline editor.
  It already treats `.counter` as click-to-place.
- `Snapzy/Features/Annotate/Components/AnnotateCanvasDrawingView.swift`
  differentiates click/drag and commits one gesture on mouse-up.
- `Snapzy/Features/Annotate/AnnotateState.swift` owns annotation state and
  derives the next counter from committed annotations (`nextCounterValue()`).
- `Snapzy/Features/Annotate/Models/PersistedAnnotationSession.swift` uses
  additive optional properties so older sidecars can decode safely.

Existing pattern to preserve:

```swift
// PersistedAnnotationSession.swift
// Optional additions keep schemaVersion at 1 and older sidecars decodable.
var combineSession: PersistedCombineSession?
```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `./scripts/format.sh` | SwiftFormat exits 0 |
| Tests | `./scripts/run-tests.sh` | `success: Tests passed.` |
| Build | `xcodebuild -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug build` | `** BUILD SUCCEEDED **` |
| Run | `./scripts/build_and_run.sh` | `Snapzy Debug` launches |

## Scope

**In scope**

- Create `Snapzy/Features/Notinhas/{Models,Services,Components}/` for all
  Notes types, rendering geometry, editor popover, and pure helpers.
- Add only the minimum Annotate seams: one `.notinhasNote` tool, state-owned
  `[NotinhasVisualNote]`, selection/hit-testing callbacks, session snapshot
  fields, and canvas overlay invocation.
- Add focused XCTest files under `SnapzyTests/Features/Notinhas/` and additive
  session round-trip coverage under `SnapzyTests/Features/Annotate/`.
- Add localized strings through the existing localization catalog workflow.

**Out of scope**

- Changing existing Snapzy shapes, counters, cloud providers, app identity,
  capture behavior, or the final side-panel layout (Plan 002).
- Renaming `Snapzy/`, `Snapzy.xcodeproj`, or existing upstream types.

## Steps

### Step 1: Define the extension's stable model and pure geometry

Create `NotinhasVisualNote`, `NotinhasNoteTarget` (`point` or `rect`),
`NotinhasAreaStyle` (`outline`, `tinted`, `hatched`), and a color value that is
Codable without archiving AppKit objects. Keep all types in
`Features/Notinhas/Models`. Each note carries a stable UUID, text, target,
color, style, and creation-order value; its visible number is derived from the
ordered array, never stored as a second mutable truth.

Add pure helpers for: drag threshold classification, clamped image-space
rectangles, pin placement, sequential renumbering after deletion, and style
geometry. Use one renderer-facing style representation so the live canvas and
exporter cannot drift in Plan 002.

**Verify**: `./scripts/run-tests.sh -only-testing:SnapzyTests/Features/Notinhas` →
new model/geometry tests pass.

### Step 2: Integrate one dedicated Notes tool into the editor

Add `.notinhasNote` as the smallest necessary `AnnotationToolType` integration
and place its button next to the existing counter in `AnnotateToolbarView`.
Give it a rebindable local shortcut through `AnnotateShortcutManager`; select
it only when the user explicitly chooses Notes. Do not hijack selection,
crop, or other drawing tools.

Route this tool in `DrawingCanvasNSView`: a click creates a point draft and a
drag beyond the existing drawing threshold creates a rectangular draft. Keep
gesture-local previews local until mouse-up, matching the canvas's current
annotation gesture pattern. Append a draft only long enough to render and edit
it; opening a different tool or dismissing an empty draft must remove it.

**Verify**: `xcodebuild -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug build` →
`** BUILD SUCCEEDED **`.

### Step 3: Add the floating note editor and live overlay

Implement a compact SwiftUI editor anchored to the selected note. It must
focus the text field immediately and expose: text editing, a trash action that
deletes the note/draft, a color picker using the existing Annotate palette, and
an area-style menu only when the target is rectangular. The styles are exact:
outline; outline plus semi-transparent fill; outline plus the same fill and
diagonal hatch. The selected color applies to the pin, outline, fill, and
hatch. A click-only note has a circular numbered pin and no style control.

Reuse `AnnotateState` as the main-actor owner through narrow methods such as
create/update/delete/select Notes. Opening an existing note from its pin or
region reopens this editor. Reject blank text on editor dismissal: remove the
draft. Deletion must renumber remaining notes in creation order and make one
undo checkpoint.

Render the live note overlay through a Notinhas renderer called by the existing
canvas layers; do not add a competing `NSView` hierarchy or duplicate image
coordinate conversion.

**Verify**: `./scripts/run-tests.sh -only-testing:SnapzyTests/Features/Notinhas` →
tests cover click, drag, blank discard, style selection, delete/renumber, and
color persistence.

### Step 4: Persist editable Notes sessions compatibly

Extend `AnnotationSessionData` and `PersistedAnnotationSession` with an
optional Notes payload. Decode a missing or malformed payload as an empty note
array; preserve all existing annotations and schema behavior. Persist notes
when the editor saves its sidecar and restore them when reopening it.

Do not turn a Note into a new upstream `AnnotationType`: keeping it as a
Notinhas payload limits merge conflicts and avoids changing all existing
annotation switches.

**Verify**: `./scripts/run-tests.sh -only-testing:SnapzyTests/Features/Annotate/AnnotationSessionStoreTests` →
old-sidecar and Notes round-trip tests pass.

### Step 5: Perform mandatory code review

Have a reviewer inspect the diff before merging. Confirm: the new code is
contained in `Features/Notinhas`; only narrow integration edits exist in
Annotate; no standard tool behavior changed; canvas interactions commit only
on mouse-up; empty notes never render/export; Codable decoding fails soft; and
the added tests cover every Notes model branch. The reviewer must run the full
test command and record the result in the PR.

**Verify**: `git diff --check && ./scripts/run-tests.sh` → no whitespace
errors and `success: Tests passed.`

## Test plan

- Model tests: point/rect target classification, style defaults, sequential
  numbering, deletion, and malformed persisted values.
- Session tests: Notes survive save/reopen; an old sidecar with no Notes field
  opens with an empty Notes array.
- Manual macOS test: select Notes, click and drag, edit/delete/reselect, undo
  and redo, zoom/pan/crop, then reopen a saved annotation session.

## Done criteria

- [ ] Notes source is under `Snapzy/Features/Notinhas/`; no broad source move
  or rename occurred.
- [ ] Click creates a pin; drag creates a rectangular note with the three
  specified styles; blank drafts disappear.
- [ ] Deleting a note renumbers markers and note order to `1...N`.
- [ ] Saved sessions restore text, color, target, and area style.
- [ ] Build and full XCTest suite pass.
- [ ] Mandatory code review completed and the README status is updated.

## STOP conditions

- The canvas no longer has one clear mouse-up commit seam.
- The only viable implementation requires adding Notinhas data to every
  `AnnotationType` switch across the app.
- Session restoration cannot tolerate a missing Notes payload.
- Existing selection/crop behavior regresses during manual verification.

## Maintenance notes

Treat `Features/Notinhas` as a plugin boundary: new note variants belong there
first. A future upstream change to canvas layers or `AnnotationSessionData`
must retain the two narrow adapters added here. Plan 002 owns final-image
composition; do not add a side panel in this plan.

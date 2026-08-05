# Plan 008: Show export-parity Notinhas composition in Annotate Preview mode

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat dfdfa83..HEAD -- Snapzy/Features/Annotate/AnnotateMainView.swift Snapzy/Features/Annotate/Components/AnnotateCanvasView.swift Snapzy/Features/Annotate/Services/AnnotateExporter.swift Snapzy/Features/Annotate/AnnotateState.swift SnapzyTests/Features/Annotate SnapzyTests/Features/Notinhas`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none (independent of 007/009; can land in parallel)
- **Category**: direction
- **Planned at**: commit `dfdfa83`, 2026-07-20

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `yes` — independent of editor modal and pin-size work
- **Reviewer required**: `yes` — must match Copy/Done output and avoid heavy
  re-render loops
- **Rationale**: Preview must call the same final render path as export; wrong
  wiring shows a lie relative to clipboard output.
- **Escalate when**: `renderFinalImage` while `editorMode == .preview` diverges
  from Copy in a way that cannot be fixed without changing export semantics
  for all modes.

## Why this matters

Annotate’s bottom segmented control includes **Preview**, which today mainly
hides editing chrome while still showing the live canvas. Designers with
Notinhas notes cannot see the **side Notes panel composition** that Copy/Done
will produce. Product decision (A): Preview must show the **same composition
as export/copy** (annotated image + Notes panel on the configured side) as a
read-only view.

When there are **no** renderable Notinhas notes, keep the existing Preview
behavior (canvas / mockup preview as today).

## Current state

- Mode toggle: `AnnotateBottomBarView.modeToggle` binds `$state.editorMode`
  with `.annotate` / `.mockup` / `.preview`.
- `AnnotateMainView` hides toolbar, quick bar, sidebar, and the live Notinhas
  side panel when `editorMode == .preview`, but still hosts
  `AnnotateCanvasView` (editable drawing surface underneath).
- Final export already composes Notinhas via
  `AnnotateExporter.renderFinalImage` → `composeNotinhasIfNeeded` →
  `NotinhasNotesComposer.addPanelOnly`.

```372:380:Snapzy/Features/Annotate/Services/AnnotateExporter.swift
  static func renderFinalImage(state: AnnotateState) -> NSImage? {
    guard let snapshot = state.makeRenderSnapshot() else { return nil }
    if snapshot.editorMode == .mockup {
      // mockup path ...
      return composeNotinhasIfNeeded(...)
    }
    return composeNotinhasIfNeeded(renderFlatFinalImage(snapshot: snapshot), snapshot: snapshot)
  }
```

```50:61:Snapzy/Features/Annotate/AnnotateMainView.swift
        if !state.notinhasNotes.isEmpty, state.editorMode != .preview {
          // live NotinhasNotesSidePanelView
        }
```

Important: when `editorMode == .preview`, `makeRenderSnapshot()` currently
stores `.preview`, so `renderFinalImage` takes the **flat** branch (not
mockup). Copy from Preview therefore already ignores mockup transforms.
Preview-with-notes must match **that same** `renderFinalImage(state:)`
output — do not invent a parallel compositor.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format (touched only) | `swiftformat <paths>` | exit 0 |
| Tests | focused Annotate/Notinhas tests with `CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Build | Debug `xcodebuild` with `CODE_SIGNING_ALLOWED=NO` | `** BUILD SUCCEEDED **` |

## Scope

**In scope**:

- `Snapzy/Features/Annotate/AnnotateMainView.swift`
- `Snapzy/Features/Annotate/Components/AnnotateCanvasView.swift` **or** a new
  small `AnnotateExportPreviewView.swift` under Annotate/Components
- `Snapzy/Features/Annotate/AnnotateState.swift` — optional
  `@Published var previewCompositionImage: NSImage?` + refresh helper
- Thin reuse of `AnnotateExporter.renderFinalImage(state:)` (do not duplicate
  drawing logic)
- Tests under `SnapzyTests/Features/Annotate/` or Notinhas if you extract a
  pure “shouldShowExportPreview” helper
- `plans/README.md` status row

**Out of scope**:

- Changing Copy/Done/export pixel pipeline except fixing a Preview-mode
  snapshot bug if Preview render would otherwise differ from Copy while still
  in Preview (see STOP)
- Live Notinhas side panel in Preview (composition image already includes the
  panel)
- Editor modal / pin sizing plans

## Git workflow

- Branch: `feat/notinhas-preview-composition`
- Commit example: `feat: show Notinhas export composition in Preview mode`
- Do NOT push/PR unless asked.

## Steps

### Step 1: Define when export Preview replaces the canvas

Add a clear helper (on `AnnotateState` or a small enum helper):

```swift
var showsNotinhasExportPreview: Bool {
  editorMode == .preview
    && !NotinhasNoteGeometry.orderedRenderableNotes(notinhasNotes).isEmpty
}
```

**Verify**: unit test true/false for empty text notes vs notes with text.

### Step 2: Refresh composition image when entering Preview

When `editorMode` becomes `.preview` and `showsNotinhasExportPreview`:

1. Call `AnnotateExporter.renderFinalImage(state: self)` on the main actor
   (same entry Copy uses).
2. Store result in `@Published private(set) var notinhasExportPreviewImage: NSImage?`.
3. Clear the cached image when leaving Preview or when notes become
   non-renderable.
4. Optionally refresh when `notinhasNotes` / annotations / crop / mockup
   inputs change **while** still in Preview — debounce (~100–200ms) if needed
   to avoid hitching. Minimum acceptable: refresh on mode enter + when
   returning to Preview after edits.

**Verify**: after switching to Preview with ≥1 note with text, cached image
non-nil and wider than source when panel side adds width (composer grows
width by `NotinhasNotesComposer.panelWidth`).

### Step 3: Present the image in the main layout

In `AnnotateMainView` (or canvas wrapper):

- If `state.showsNotinhasExportPreview`, show a read-only SwiftUI `Image`
  (or `NSImage` representable) scaled with `.resizable().scaledToFit()`,
  centered on the same chrome background as the canvas area.
- Else keep `AnnotateCanvasView` as today (including Preview-without-notes and
  mockup preview transforms).
- Ensure the live `NotinhasNotesSidePanelView` stays hidden in Preview (already
  true) so the panel is not double-shown.

Disable interaction (no drawing) on the export preview image.

**Verify**: manual — Annotate with notes → Preview shows panel+pins matching
Copy; switch back to Annotate → editor returns; Preview with zero notes → old
behavior.

### Step 4: Guard renderFinalImage mode semantics

Document in code comments: Preview composition uses `renderFinalImage(state:)`
verbatim so Copy and Preview cannot drift.

If you discover that leaving `editorMode == .preview` inside the snapshot
causes missing annotations vs Copy from Annotate mode, STOP and report —
do not silently rewrite export for all callers. A possible fix (only if
needed and approved by STOP resolution) is to render from a snapshot copy
with `editorMode` forced to `.annotate` or `.mockup` based on whether mockup
transforms are active — but that is an escape hatch, not the default step.

**Verify**: Copy while in Preview produces the same pixel size as the Preview
image (spot-check width/height equality in a test if cheap).

### Step 5: Format touched files + build + tests

## Test plan

- Helper tests for `showsNotinhasExportPreview`.
- Optional: renderFinalImage with a tiny fixture note asserts output width >
  base width when panelSide is set.
- Manual checklist above.

## Done criteria

- [ ] Preview + renderable Notinhas notes shows export composition (image +
      Notes panel)
- [ ] Preview without renderable notes keeps prior Preview behavior
- [ ] Composition comes from `AnnotateExporter.renderFinalImage` (no forked
      drawer)
- [ ] Leaving Preview restores Annotate/Mockup editing UI
- [ ] Tests + Debug build succeed
- [ ] Scope respected; README row 008 updated

## STOP conditions

- `renderFinalImage` while `editorMode == .preview` visibly differs from Copy
  performed in Annotate mode for the same document — stop; do not ship a
  lying Preview.
- Refreshing on every keystroke / drag makes Preview unusable — stop and
  propose debounce/on-enter-only before expanding scope.
- Mockup+Notinhas Preview requires ImageRenderer on a background thread —
  stay on MainActor; do not force off-main SwiftUI rendering.

## Maintenance notes

- Any future change to `composeNotinhasIfNeeded` automatically updates
  Preview if this plan’s wiring is preserved.
- Reviewers should reject a second compositor implemented only for Preview.

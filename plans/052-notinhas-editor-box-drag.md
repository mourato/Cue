# Plan 052: Make the Notinhas contextual editor freely draggable

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If a STOP condition occurs, stop and report instead of
> improvising. When done, update the status row for this plan in
> `plans/README.md`, unless the reviewer maintains the index.
>
> **Drift check (run first)**: `git diff --stat df0302d9..HEAD -- Notinhas/Features/Annotate Notinhas/Features/Notinhas NotinhasTests/Features/Notinhas Notinhas/Shared/Localization/L10n.swift Notinhas/Resources/Localization/Features/Annotate.xcstrings`
> If any in-scope file changed since this plan was written, compare the
> current-state excerpts below with live code before proceeding.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED — this changes an AppKit/SwiftUI overlay's coordinate space and hit-testing behavior.
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `df0302d9`, 2026-07-23

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — overlay hosting, geometry, and interaction tests must be changed as one coordinate-space contract.
- **Reviewer required**: yes — the behavior depends on real SwiftUI hit-testing, window resizing, focus, and the editor's visual bounds.
- **Rationale**: The feature is narrowly scoped but crosses a pure geometry helper, a nested SwiftUI overlay, the Annotate canvas host, and interactive controls inside the editor.
- **Escalate when**: the implementation requires persisted session data, changes `NotinhasVisualNote`, moves the panel into the exported render tree, covers the toolbar/sidebar, or changes the existing click-away/selection state machine.

## Why this matters

The Notinhas contextual editor currently auto-positions beside the selected point/rectangle and can cover image content that the user needs to read while writing the comment. The requested behavior lets the user move that box anywhere in the editor's usable center area, including canvas background/padding, so the target and surrounding evidence remain visible while the comment is written. The position is transient UI state: it is shared while switching between Notinhas in the open window, then discarded when the editor closes; the side-panel summary, persisted note data, export composition, and clipboard output remain unchanged.

## Current state

The project vocabulary is defined in `CONTEXT.md`:

- A **Notinha visual** is the numbered point/rectangle plus its text comment.
- The **caixa contextual de edição** is the temporary editor with text, color, and area-style controls.
- The **painel lateral de resumo** is the separate list of notes in the editor window. It is explicitly out of scope.
- The **área útil do editor** is the center editing area, including canvas/background/padding but excluding toolbar, quick-properties bar, bottom bar, and side panels.

Relevant code:

- `Notinhas/Features/Annotate/AnnotateMainView.swift:17-80` builds the window as top toolbar + quick-properties bar, a center `HStack`, and bottom bar. The canvas occupies the middle view; the optional left Annotate sidebar is 240 points wide, and the Notinhas summary panel is 264 points including padding on the right. Therefore the `AnnotateCanvasView` host is the correct usable-area boundary; do not place the editor over the outer `VStack` or either sidebar.
- `Notinhas/Features/Annotate/Components/AnnotateCanvasView.swift:303-339` currently puts `NotinhasNoteEditorCanvasOverlay` inside the scaled/panned image group and applies the mockup transform to it. This restricts it to `foregroundDisplaySize` and makes it follow image transforms, which prevents placement in canvas padding and is the main hosting constraint to remove.
- `Notinhas/Features/Notinhas/Views/NotinhasNoteEditorCanvasOverlay.swift:14-55` derives the selected note's display bounds, panel size, and an automatic origin, then offsets the editor to that origin. Its `@State` draft/snapshot lifecycle already survives text and appearance edits and is destroyed when the conditional overlay disappears.
- `Notinhas/Features/Notinhas/Services/NotinhasNoteGeometry.swift:103-152` owns the current automatic `editorOrigin` and `editorPanelSize` helpers. `editorOrigin` prefers the right side, then the left, then clamps to its container; it should remain available as the initial-placement policy, but it must no longer be recomputed after every note selection once the user has dragged the box.
- `Notinhas/Features/Notinhas/Views/NotinhasNoteEditorView.swift:20-73` renders the material box. The root contains the header/color menu, a multiline `TextField`, optional rectangle style controls, and delete/cancel/save buttons. There is currently no drag gesture or drag affordance.
- `Notinhas/Features/Annotate/AnnotateState.swift:1284-1295` has note selection/editing state but no editor-panel position. Do not add the position to `AnnotateState`, `NotinhasVisualNote`, `PersistedAnnotationSession`, or `PersistedNotinhasNotesSession`; the requirement is window-lifetime UI state only.
- `Notinhas/Features/Notinhas/Annotate/NotinhasAnnotateState.swift:143-161` clears editing state on close. The overlay's local position must reset naturally with this close/reopen lifecycle; do not add persistence or an undo checkpoint for moving the UI box.
- `Notinhas/Features/Annotate/Components/AnnotateCanvasDrawingView.swift:1244-1267` treats any canvas click while a Notinhas editor is active as click-away/cancel. Moving the box must not route its own clicks into this handler; empty host space must continue to pass through to the canvas.
- `NotinhasTests/Features/Notinhas/NotinhasNoteGeometryTests.swift:86-180` already characterizes automatic origin and panel-size clamping. Preserve those tests and add pure tests for free-placement clamping rather than deleting the automatic-placement coverage.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused geometry tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/NotinhasNoteGeometryTests` | Exit 0; all geometry tests pass. |
| Focused interaction tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/NotinhasNoteEditorInteractionTests` | Exit 0 after the optional focused interaction test class is created; otherwise use the exact test identifier added by the executor. |
| Full local suite without on-screen visual suites | `./scripts/run-tests.sh --skip-visual` | Exit 0; no regressions outside this feature. |
| Debug build | `xcodebuild -project Notinhas.xcodeproj -scheme Notinhas -configuration Debug build CODE_SIGNING_ALLOWED=NO` | Exit 0. |
| Diff hygiene | `git diff --check` | Exit 0 with no whitespace errors. |

Do not use the optional Video module for this plan. The requested flow is the default screenshot Annotate/Notinhas path.

## Suggested executor toolkit

- Use `capture-annotate-export` for Notinhas scope and the capture → annotate → export invariants.
- Use `macos-app-engineering` for SwiftUI/AppKit hosting and coordinate-space behavior.
- Use `accessibility-audit` for the drag hint, text-field focus, Escape dismissal, and VoiceOver behavior.
- Use `testing-xctest` and `swift-conventions` for focused XCTest structure and Swift formatting.

## Scope

**In scope** (modify only these paths, plus the already-created `CONTEXT.md` must remain unchanged):

- `Notinhas/Features/Annotate/Components/AnnotateCanvasView.swift`
- `Notinhas/Features/Notinhas/Views/NotinhasNoteEditorCanvasOverlay.swift`
- `Notinhas/Features/Notinhas/Views/NotinhasNoteEditorView.swift`
- `Notinhas/Features/Notinhas/Services/NotinhasNoteGeometry.swift`
- `NotinhasTests/Features/Notinhas/NotinhasNoteGeometryTests.swift`
- `NotinhasTests/Features/Notinhas/NotinhasNoteEditorInteractionTests.swift` (create if a focused state/interaction test is useful)
- `Notinhas/Features/Notinhas/NotinhasL10n.swift` and the matching localization source only if an accessibility hint is added.

**Out of scope**:

- `Notinhas/Features/Notinhas/Views/NotinhasNotesSidePanelView.swift` and `NotinhasNotesPanelSide.swift` — the summary list and its left/right preference are unrelated.
- `AnnotateState`, `NotinhasVisualNote`, `PersistedAnnotationSession`, `PersistedNotinhasNotesSession`, and `AnnotationSessionStore` — no persistence or note-model change is requested.
- `AnnotateExporter`, `NotinhasNoteRenderer`, `NotinhasNotesComposer`, clipboard code, and preview/export behavior — the editor box is UI chrome and must never be rendered into output.
- Toolbar, quick-properties bar, bottom bar, and sidebar layout changes.
- Generic draggable-window infrastructure or a new user preference.

## Git workflow

- Match the repository's existing Conventional Commit style if committing is requested by the operator; an appropriate message would be `feat(notinhas): make note editor box draggable`.
- Do not push or open a pull request unless separately instructed.

## Steps

### Step 1: Define and test free-placement geometry

Extend `NotinhasNoteGeometry` with a pure helper that clamps a panel origin to an editor-work-area rectangle using the panel's measured size and the existing inset convention. The helper must handle a panel smaller than the work area, a panel larger than one or both dimensions, negative/out-of-range proposed origins, and a work area whose origin is not zero. Keep `editorOrigin` for first-open automatic placement and keep `editorPanelSize` as the preferred-size policy. Do not mix image-space coordinates, crop coordinates, mockup transforms, or export offsets into this UI-space helper.

Add XCTest coverage in `NotinhasNoteGeometryTests.swift` for: origin already inside bounds, left/top clamping, right/bottom clamping, non-zero container origin, and oversized panel behavior. Preserve the existing `editorOrigin` tests.

**Verify**: `./scripts/run-tests.sh -only-testing:NotinhasTests/NotinhasNoteGeometryTests` → exit 0, including the new clamp cases.

### Step 2: Host the contextual editor in the full usable center area

Refactor `AnnotateCanvasView` so the editor overlay is a sibling of the scaled/panned/mockup-transformed canvas content, hosted by the outer center-pane `GeometryReader` coordinate space. The overlay must receive the full center-pane size as its work area, not `foregroundDisplaySize`. The image, annotation pins, zoom/pan, and mockup transforms must continue to use their current group unchanged. The editor box must remain upright and at UI scale while the image is zoomed, panned, or shown in mockup mode.

Preserve the existing hit-testing contract: only the actual editor box consumes pointer events; the overlay's empty host area must remain transparent to hit testing so canvas click-away still cancels the edit. Do not let the box extend into the top/bottom chrome or either sidebar; the outer `AnnotateMainView` clipping and the center-pane frame are the boundary.

**Verify**: `xcodebuild -project Notinhas.xcodeproj -scheme Notinhas -configuration Debug build CODE_SIGNING_ALLOWED=NO` → exit 0, with no SwiftUI type-check or preview errors.

### Step 3: Add transient shared panel position and drag interaction

In `NotinhasNoteEditorCanvasOverlay`, add local SwiftUI state for the panel origin and the active drag's starting origin. On the first render for an open editor, compute the current automatic `editorOrigin` once. After that, retain the origin even when `editingID` changes to another note. Re-clamp the retained origin when panel size or center-pane size changes, so resizing the window cannot leave the box clipped. When the conditional overlay disappears on close/cancel/delete/tool switch, the local state must be discarded; reopening a note starts with automatic placement again.

The drag contract is:

- The entire material box is draggable except the multiline text field.
- The text field keeps normal click, caret, selection, typing, submit, and focus behavior; it must not move the panel when the user drags inside it.
- Color, area-style, stroke-width, delete, cancel, and save controls retain their existing tap/menu/slider behavior. A control click must not trigger an accidental panel move; use an interaction composition that preserves control gestures rather than attaching an unconditional gesture that steals them.
- Dragging uses the editor host's local UI coordinates, clamps continuously to the work area, and does not mutate the note target, note text, undo stack, or persisted session.
- A click on empty host space still reaches `DrawingCanvasNSView` and follows the existing click-away cancellation path.

Implement the interaction in the narrowest way that satisfies “whole box except text field”; if SwiftUI gesture precedence cannot preserve button/menu/slider semantics, stop and report rather than replacing the controls with custom AppKit behavior without evidence.

**Verify**: `./scripts/run-tests.sh -only-testing:NotinhasTests/NotinhasNoteGeometryTests` plus the exact new interaction/state test identifier → exit 0.

### Step 4: Preserve accessibility and localize any new affordance

Make the draggable surface understandable to VoiceOver without treating the text field as a draggable control. If a hint is needed, add it through the existing `NotinhasL10n`/localization ownership pattern; do not hardcode user-facing copy in the view. Confirm that Escape still cancels the editor, the text field remains the focused text input on open, and all existing color/style/action labels remain intact.

**Verify**: `git diff --check` → exit 0; focused tests → exit 0. Manually confirm VoiceOver can reach the text field and action controls without an invisible full-frame hit target blocking them.

### Step 5: Run the full verification and manual handoff gate

Run the full default-scheme suite with visual tests skipped, then perform the manual UI gate with Screen Recording permission available:

1. Open a screenshot in Annotate and create both a point Notinha and a rectangular Notinha.
2. Confirm the contextual editor initially uses the existing automatic placement.
3. Drag the box from its header, controls, and non-text body to locations over canvas content, canvas padding/background, and both horizontal extremes of the center pane. Confirm it never enters the toolbar, quick-properties bar, bottom bar, or side panels.
4. Drag inside the text field and confirm text selection/editing works without moving the box. Click color/style/slider/delete/cancel/save controls and confirm their actions remain correct.
5. Select another Notinha from the canvas or summary panel; confirm the box remains at the last user-selected location while editing the new note.
6. Zoom, pan, resize the editor window, and enter mockup mode; confirm the box stays upright, remains in UI coordinates, and is re-clamped when necessary.
7. Close the editor and reopen the same capture; confirm the box does not restore its previous position. Enter Preview/copy and confirm only the normal Notinhas markers and summary composition are exported.

**Verify**: `./scripts/run-tests.sh --skip-visual` → exit 0; manual flow shows no panel/sidebar overlap, no focus regression, and no export change.

## Test plan

- Extend `NotinhasNoteGeometryTests.swift` using its existing pure-helper style for all panel-origin clamping edge cases.
- Add `NotinhasNoteEditorInteractionTests.swift` only if the chosen local-state/interaction seam can be tested without launching a real window; cover initial automatic placement, retaining origin across note-ID changes, resetting after overlay removal, and clamping after work-area/panel-size changes.
- Do not add brittle pixel snapshots for this feature. The visual gate must verify actual SwiftUI/AppKit hit-testing and window layout.
- Use `AnnotateTextEditingTests.swift` as the lifecycle-testing style reference for MainActor state tests, while keeping note-panel position out of `AnnotateState` unless the current code proves local view state cannot survive note selection.

## Done criteria

- [ ] The contextual Notinhas editor, not the summary side panel, can be dragged freely throughout the center editor work area.
- [ ] The work area includes canvas background/padding and excludes toolbar, quick-properties bar, bottom bar, left sidebar, and right summary panel.
- [ ] Every part of the box except the text field can initiate a drag without breaking color/style/action controls.
- [ ] The text field preserves normal focus, caret, selection, typing, and submit behavior.
- [ ] The panel position remains while switching between Notinhas and is continuously clamped after resize/size changes.
- [ ] Closing the editor resets the transient position; no persisted model/sidecar/UserDefaults field is introduced.
- [ ] The editor is not part of the export/clipboard render tree and mockup/zoom transforms do not rotate or scale it.
- [ ] `./scripts/run-tests.sh -only-testing:NotinhasTests/NotinhasNoteGeometryTests` exits 0.
- [ ] `./scripts/run-tests.sh --skip-visual` exits 0.
- [ ] The default Debug build exits 0.
- [ ] `git diff --check` exits 0 and no out-of-scope files are modified.
- [ ] Manual capture → Notinhas → drag/edit → Preview/copy smoke passes.

## STOP conditions

Stop and report instead of improvising if:

- `AnnotateCanvasView` no longer has the center-pane `GeometryReader`/layout shape described above.
- Moving the overlay outside the transformed group causes pins or annotations to lose their existing image-space alignment in a way that requires changing render/export code.
- SwiftUI cannot exclude the text field while preserving menu, slider, delete, cancel, and save interactions without replacing controls or adding broad AppKit infrastructure.
- The implementation requires persisting panel position to make it survive note selection, or changes `NotinhasVisualNote`, sidecar schema, undo, or export behavior.
- The available center pane is smaller than the editor panel and there is no existing product decision for a scrollable/partially clipped editor; do not invent one.
- Any test or build failure is unrelated to this plan and cannot be distinguished from a pre-existing failure.

## Maintenance note

Future changes to Annotate chrome widths, canvas zoom/pan hosting, mockup transforms, or Notinhas editor controls must preserve the distinction between image-space annotations and UI-space panel placement. If the summary side panel becomes resizable or movable later, give it a separate layout contract; do not reuse the contextual editor's transient origin. Any new interactive child inside the editor must be checked against the “whole box except text field” drag exclusion and accessibility behavior.

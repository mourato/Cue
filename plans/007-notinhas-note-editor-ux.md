# Plan 007: Redesign the Notinhas note editor modal with live style updates

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat dfdfa83..HEAD -- Snapzy/Features/Notinhas/Views Snapzy/Features/Annotate/Components/AnnotateCanvasDrawingView.swift SnapzyTests/Features/Notinhas`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `dfdfa83`, 2026-07-20

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — overlay live-apply and Cancel/Save semantics must stay coherent
- **Reviewer required**: `yes` — undo, Cancel revert, and live canvas redraw are easy to get wrong
- **Rationale**: Touches AppKit overlay bindings, SwiftUI modal layout, and AnnotateState updates.
- **Escalate when**: live-apply appears to require rewriting Annotate undo globally, or Cancel cannot restore without data loss.

## Why this matters

The note editor modal is the primary place designers write handoff text. Current
pain points from QA: a text-labeled Delete button, always-visible color row
crowding the modal, a one-line text field that is too short, and color/area
style changes that only appear after Save. Product decisions locked for this
plan:

- Delete = icon-only trash, destructive (red).
- Header `HStack`: badge number + “Note” title + `Spacer` + color button that
  reveals the existing palette (popover/menu), not a permanently visible row.
- Text field height ≈ **three lines**.
- **Color and area style apply live** on the canvas while the modal is open.
- **Text** stays in the draft until Save (or equivalent commit).
- **Cancel** restores color, area style, **and** text to the values captured
  when the modal opened (decision A).

## Current state

- `Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift` — modal UI:
  header is badge + title only; palette is always shown; Delete is a text
  button; `TextField` uses `.lineLimit(1 ... 4)` without a fixed min height.
- `Snapzy/Features/Notinhas/Views/NotinhasNoteEditorOverlay.swift` — keeps a
  local `draftNote`; color/style bindings mutate only the draft; canvas state
  updates only in `onCommit` via `notinhasUpdateNote`.
- Cancel path (`AnnotateCanvasDrawingView.presentNotinhasEditor` → `onCancel`)
  calls `notinhasCloseEditor(discardIfEmpty: true)` and does **not** restore
  prior color/style if those were live-applied (they are not live-applied yet).

Header / delete / palette excerpt:

```26:79:Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift
      HStack(spacing: 8) {
        Text("\(displayNumber)")
        // ...
        Text(NotinhasL10n.noteEditorTitle)
      }
      TextField(..., axis: .vertical)
        .lineLimit(1 ... 4)
      HStack(spacing: 8) { /* always-visible palette */ }
      HStack {
        Button(NotinhasL10n.deleteNote, role: .destructive) { onDelete() }
        // Cancel / Save
      }
```

Overlay commit-only apply:

```75:82:Snapzy/Features/Notinhas/Views/NotinhasNoteEditorOverlay.swift
      onCommit: { [weak self] in
        if let draftNote = self?.draftNote {
          self?.state.notinhasUpdateNote(draftNote)
        }
        self?.onCommit()
      },
```

Conventions: keep Notinhas UI under `Snapzy/Features/Notinhas/`; thin Annotate
seams only. Localization via `NotinhasL10n` / Annotate strings catalog. Two-space
indent.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format (touched files only) | `swiftformat <paths>` | exit 0 |
| Tests | `xcodebuild ... CODE_SIGNING_ALLOWED=NO -only-testing:SnapzyTests/NotinhasAnnotateStateTests test` | `** TEST SUCCEEDED **` |
| Build | `xcodebuild -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug build CODE_SIGNING_ALLOWED=NO` | `** BUILD SUCCEEDED **` |

Avoid `./scripts/format.sh` on the whole tree unless the operator asks — it
reformats hundreds of unrelated files.

## Scope

**In scope**:

- `Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift`
- `Snapzy/Features/Notinhas/Views/NotinhasNoteEditorOverlay.swift`
- `Snapzy/Features/Notinhas/Annotate/NotinhasAnnotateState.swift` (only if a
  small helper is needed for live partial update / revert)
- `Snapzy/Features/Annotate/Components/AnnotateCanvasDrawingView.swift`
  (invalidate drawing on live apply; Cancel restore wiring)
- `Snapzy/Features/Notinhas/NotinhasL10n.swift` and Annotate xcstrings **only**
  for accessibility labels of the new icon buttons
- `SnapzyTests/Features/Notinhas/NotinhasAnnotateStateTests.swift` (live + cancel)
- `plans/README.md` (status row)

**Out of scope**:

- Preview mode composition (plan 008)
- Pin diameter / Counter sizing (plan 009)
- Changing export panel layout
- Selection-tool parity for notes

## Git workflow

- Branch: `feat/notinhas-note-editor-ux` (or work directly on operator branch)
- Commit style: Conventional Commits, e.g.
  `feat: redesign Notinhas note editor with live style updates`
- Do NOT push/PR unless asked.

## Steps

### Step 1: Restructure the modal header and actions

In `NotinhasNoteEditorView`:

1. Header `HStack`:
   - Number badge (filled with current `color`)
   - Title `NotinhasL10n.noteEditorTitle`
   - `Spacer(minLength: 0)`
   - Color button: circular swatch of current `color` (or `paintpalette` /
     circle). Tapping toggles a popover / menu that contains the **same six**
     palette swatches currently inline. Use `@State private var isColorPickerPresented`.
2. Remove the always-visible palette `HStack` from the body.
3. Keep the area-style segmented picker below the text field when
   `showsAreaStyle` is true.
4. Footer: replace text Delete with

```swift
Button(role: .destructive) { onDelete() } label: {
  Image(systemName: "trash")
}
.help(NotinhasL10n.deleteNote)
.accessibilityLabel(NotinhasL10n.deleteNote)
```

Keep Cancel + Save on the trailing side.

5. Text field: keep vertical axis; set an explicit three-line minimum, e.g.
   `.lineLimit(3 ... 6)` and/or `.frame(minHeight: …)` so the control is ~3
   lines tall when empty (not a single-line field).

Adjust overlay `panelSize` height upward so the taller field + popover chrome
still fit (today ~180/220).

**Verify**: build succeeds; visually inspect in a debug run if available.

### Step 2: Capture opening snapshot and live-apply color / areaStyle

In `NotinhasNoteEditorOverlay.show(for:in:)`:

1. Store `openingSnapshot = note` (full `NotinhasVisualNote` at open).
2. Keep `draftNote` for text + pending values.
3. When `color` or `areaStyle` binding is set:
   - Update `draftNote`
   - Immediately call `state.notinhasUpdateNote` with a note that has the new
     color/areaStyle but **prefer not** to spam undo: either
     - update live fields **without** `saveState` (add
       `notinhasApplyLiveAppearance(_:)` that mutates without checkpoint), **or**
     - debounce and use a single checkpoint on first live change after open.
   - Product minimum: canvas pin/rect must update **immediately** when clicking
     a swatch or area style. Prefer **no undo checkpoint per swatch click**;
     one checkpoint on Save (text+final appearance) and Cancel restores
     `openingSnapshot` without leaving junk undo entries.
4. Recommended API on `AnnotateState` extension:

```swift
/// Mutates color/areaStyle/target appearance without undo. Text is not applied here.
func notinhasApplyLiveAppearance(_ note: NotinhasVisualNote)

/// Restores a note to `snapshot` (Cancel). Uses one undo checkpoint only if
/// live appearance diverged, OR simply assigns without undo if live applies
/// never pushed checkpoints — pick one approach and document it in the PR.
func notinhasRevertNote(to snapshot: NotinhasVisualNote)
```

Recommended approach (simplest, matches decision A):

- Live appearance writes go **directly** to `notinhasNotes[index]` **without**
  `saveState`.
- Save: `notinhasUpdateNote(draft)` **with** `saveState` if text or anything
  differs from `openingSnapshot` (including appearance).
- Cancel: assign `openingSnapshot` back without `saveState` if live writes were
  checkpoint-free; clear editor.

Invalidate the canvas after live writes (`invalidateDrawing` from the overlay
callback / canvas presenter).

**Verify**: unit tests below; manual: change color → pin updates before Save;
Cancel → pin returns to opening color; text typed then Cancel → text reverted.

### Step 3: Wire Cancel to restore opening snapshot

Update `onCancel` in `presentNotinhasEditor` (or inside the overlay) to:

1. `notinhasRevertNote(to: openingSnapshot)` (or equivalent)
2. Then existing `notinhasCloseEditor` / dismiss — **do not** discard a
   non-empty note that the user Cancelled after editing text only; Cancel must
   restore text too via the snapshot restore.
3. If the note was newly created empty and Cancelled with empty text, keep
   existing discard-empty behavior.

**Verify**: testCancelRestoresLiveAppearanceAndText (new).

### Step 4: Tests

Add to `NotinhasAnnotateStateTests` (or overlay-focused tests if pure state
helpers exist):

- Live appearance update changes `notinhasNotes` color without requiring a
  separate commit helper that uses `saveState` every time.
- Revert restores opening color/style/text.
- Save persists draft text + appearance and undo restores opening snapshot in
  one step (if Save uses one checkpoint).

**Verify**: Notinhas annotate state tests pass.

### Step 5: Format touched files only + build

**Verify**: `swiftformat` on in-scope paths; Debug build succeeds.

## Test plan

- XCTest: live apply + cancel revert + save undo.
- Manual:
  1. Open note → header shows badge, “Note”, color button; no permanent palette row.
  2. Color button opens swatches; choosing one updates pin immediately.
  3. Area style (rect notes) updates hatch/tint/outline live.
  4. Text field ~3 lines; typing does not require Save to keep focus, but canvas
     note list / export text still uses committed text until Save.
  5. Cancel restores appearance + text; Delete (trash icon, red) removes note.
  6. Save commits text and closes.

## Done criteria

- [ ] Delete is icon-only trash with destructive role
- [ ] Color palette is header-triggered, not always visible
- [ ] Text field presents ~3 lines of height
- [ ] Color/areaStyle update the canvas without pressing Save
- [ ] Cancel restores opening color, areaStyle, and text
- [ ] Save still commits text and closes
- [ ] New/updated tests pass; Debug build succeeds
- [ ] No files outside scope modified
- [ ] `plans/README.md` row 007 updated

## STOP conditions

- Live apply cannot avoid undo spam without a new Annotate undo primitive —
  stop and report with the attempted design.
- Cancel + discard-empty conflict (new notes) cannot be resolved without
  changing create flow — stop and report.
- Popover cannot host the palette in the AppKit `NSHostingView` without
  clipping — try `.menu` / `Picker` first; if still impossible, STOP.

## Maintenance notes

- Reviewers: ensure Save creates at most one undo checkpoint for the whole
  edit session when possible.
- Follow-up: optional live text preview in the side panel is explicitly
  deferred (decision A keeps text commit on Save).

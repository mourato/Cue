# Plan 016: Make the Notinhas note tool discoverable via its tooltip (shortcut + click/drag gesture)

> **Numbering note**: Originally drafted as "004" then renumbered to 016 to avoid
> colliding with the pre-existing plans in this directory. References to
> "001/002/003" in an earlier draft now mean 013/014/015.

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 0370153..HEAD -- Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift Snapzy/Features/Notinhas/NotinhasL10n.swift Snapzy/Shared/Localization/L10n.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx (discoverability)
- **Planned at**: commit `0370153`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes` — independent of 013, 014, 015.
- **Reviewer required**: `no` — one dedicated tooltip for one toolbar button, plus one localized string.
- **Rationale**: Replaces the generic `.help(tool.displayName)` for the Notinhas button only, without altering shared tool-button behavior.
- **Escalate when**: the maintainer wants the shortcut hint applied to every tool's tooltip (shared `annotationToolButton`) — that changes all tools and leaves the Notinhas scope; reclassify.

## Why this matters

The Notinhas note tool has two undiscoverable behaviors. First, it has a
single-key shortcut (`i` by default) that the toolbar never surfaces — its
tooltip only shows the tool name. Second, its core interaction is dual-mode:
a **click places a pin**, while a **drag creates an area rectangle**
(`NotinhasAnnotateState.notinhasUpdateDrawing` branches on drag distance via
`NotinhasNoteGeometry.shouldCreateRect`). Nothing tells the user this, so the
area-note capability — central to precise visual handoff — is effectively
hidden. A richer tooltip on this one button teaches both in the place the user
looks first.

## Current state

- `Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift` — the note tool
  button reuses the generic tool button, whose tooltip is just the tool name:

```135:137:Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift
  private var notinhasNoteButton: some View {
    annotationToolButton(for: .notinhasNote)
  }
```

```160:171:Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift
  @ViewBuilder
  private func annotationToolButton(for tool: AnnotationToolType) -> some View {
    ToolbarButton(
      icon: tool.icon,
      isSelected: state.selectedTool == tool
    ) {
      state.activateTool(tool)
    }
    .help(tool.displayName)
    .disabled(state.editorMode == .mockup && tool != .selection)
    .opacity(state.editorMode == .mockup && tool != .selection ? 0.4 : 1)
  }
```

- The dual-mode creation logic (evidence the gesture hint is accurate):

```205:214:Snapzy/Features/Notinhas/Annotate/NotinhasAnnotateState.swift
  func notinhasUpdateDrawing(to point: CGPoint, imageBounds: CGRect) {
    guard let start = notinhasNoteDrawStart, var draft = notinhasDraftNote else { return }
    let distance = hypot(point.x - start.x, point.y - start.y)
    if NotinhasNoteGeometry.shouldCreateRect(dragDistance: distance) {
      draft.target = .rect(NotinhasNoteGeometry.clampedRect(from: start, to: point, within: imageBounds))
    } else {
      draft.target = .point(NotinhasNoteGeometry.clampedPoint(start, within: imageBounds))
    }
    notinhasDraftNote = draft
  }
```

- The tool's default shortcut is `i`
  (`AnnotateAnnotationToolType.swift:89`), and the current, possibly-customized
  binding + enabled state are available from the shortcut manager:
  `AnnotateShortcutManager.shared.shortcut(for: .notinhasNote) -> Character?` and
  `isShortcutEnabled(for: .notinhasNote) -> Bool`
  (`Snapzy/Features/Annotate/Services/AnnotateShortcutManager.swift:104-110`).
  The bottom bar already `@ObservedObject`s this manager and builds
  shortcut-augmented tooltips via `L10n.Common.withShortcut(_:_:)`
  (`AnnotateBottomBarView.swift:49,447-450`).
- The tool display name is `NotinhasL10n.noteTool` ("Note")
  (`AnnotateAnnotationToolType.swift:111`).
- Localization convention: add the new string in
  `Snapzy/Shared/Localization/L10n.swift` inside `enum Notinhas` and re-export in
  `Snapzy/Features/Notinhas/NotinhasL10n.swift`.

## Commands you will need

| Purpose        | Command                        | Expected on success |
|----------------|--------------------------------|---------------------|
| Format         | `./scripts/format.sh`          | exit 0              |
| Build + run    | `./scripts/build_and_run.sh`   | app builds and launches |
| Tests          | `./scripts/run-tests.sh`       | build + test suite pass |

## Suggested executor toolkit

- Read `.agents/skills/capture-annotate-export/SKILL.md` (owns Notinhas
  geometry: pin vs rect) to confirm the gesture wording matches behavior.

## Scope

**In scope** (the only files you should modify):
- `Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift`
- `Snapzy/Shared/Localization/L10n.swift` (append one string inside `enum Notinhas`)
- `Snapzy/Features/Notinhas/NotinhasL10n.swift` (re-export the new string)

**Out of scope** (do NOT touch):
- `annotationToolButton(for:)` — do NOT change the shared helper; other tools
  must keep their current tooltips. Add a dedicated button for Notinhas instead.
- The note editor footer (Save/Cancel keycaps) — that is plan 015.
- Any creation/geometry logic in `NotinhasAnnotateState` / `NotinhasNoteGeometry`.

## Git workflow

- Branch: `advisor/016-notinhas-note-tool-tooltip`
- Commit style: Conventional Commits. Suggested:
  `feat(notinhas): explain the note tool shortcut and click/drag in its tooltip`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add the gesture-hint string

In `Snapzy/Shared/Localization/L10n.swift`, inside `enum Notinhas` (near
`noteTool`), append:

```swift
static let noteToolGestureHint = string(
  "annotate.notinhas.note-tool-gesture-hint",
  defaultValue: "Click to pin · Drag for area",
  comment: "Tooltip hint explaining the Notinhas note tool: a click places a numbered pin, a drag creates an area rectangle"
)
```

In `Snapzy/Features/Notinhas/NotinhasL10n.swift`, add:

```swift
static let noteToolGestureHint = L10n.Notinhas.noteToolGestureHint
```

### Step 2: Observe the shortcut manager in the toolbar view

`AnnotateToolbarView` does not yet observe shortcuts. Add the observed object
alongside the existing `@ObservedObject var state` / `@AppStorage` declarations
at the top of `struct AnnotateToolbarView` (lines ~16-18):

```swift
@ObservedObject private var annotateShortcutManager = AnnotateShortcutManager.shared
```

### Step 3: Build a dedicated tooltip for the note tool button

Replace `notinhasNoteButton` (lines ~135-137) with a dedicated `ToolbarButton`
that mirrors `annotationToolButton`'s behavior but uses a custom `.help`:

```swift
private var notinhasNoteButton: some View {
  ToolbarButton(
    icon: AnnotationToolType.notinhasNote.icon,
    isSelected: state.selectedTool == .notinhasNote
  ) {
    state.activateTool(.notinhasNote)
  }
  .help(notinhasNoteTooltip)
  .disabled(state.editorMode == .mockup)
  .opacity(state.editorMode == .mockup ? 0.4 : 1)
}

private var notinhasNoteTooltip: String {
  let base: String
  if annotateShortcutManager.isShortcutEnabled(for: .notinhasNote),
     let key = annotateShortcutManager.shortcut(for: .notinhasNote) {
    base = L10n.Common.withShortcut(NotinhasL10n.noteTool, String(key).uppercased())
  } else {
    base = NotinhasL10n.noteTool
  }
  return "\(base) · \(NotinhasL10n.noteToolGestureHint)"
}
```

Notes:
- `.disabled(state.editorMode == .mockup)` reproduces the generic helper's
  disabling rule for a non-`.selection` tool (mockup mode disables drawing
  tools). Keep it so the note tool behaves identically to before, minus the
  tooltip.
- Result tooltip reads e.g. `Note (I) · Click to pin · Drag for area`.

**Verify**: `./scripts/build_and_run.sh` → compiles and launches.

### Step 4: Format

Run `./scripts/format.sh`.

## Test plan

- No unit test: tooltip composition is trivial view code depending on a
  MainActor singleton; the repo does not unit-test tooltips. Do not add one.
- **Manual verification (acceptance gate)**:
  1. Open an Annotate window (annotate mode). Hover the Notinhas note tool
     (pin-in-circle icon): tooltip reads "Note (I) · Click to pin · Drag for
     area" (the letter reflects the current binding; default `I`).
  2. If you clear/disable the Notinhas tool shortcut in Preferences → Shortcuts,
     the tooltip drops the "(I)" and still shows the gesture hint.
  3. Switch to mockup mode: the note tool button dims/disables exactly as before.
  4. Click on the canvas → a numbered pin note is created; drag on the canvas →
     an area rectangle note is created (behavior unchanged — you only changed the
     tooltip).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `./scripts/build_and_run.sh` builds and launches
- [ ] `./scripts/run-tests.sh` passes (no regressions)
- [ ] `rg -n "noteToolGestureHint" Snapzy/` returns the string definition, the re-export, and the usage
- [ ] `rg -n "annotationToolButton\(for: .notinhasNote\)" Snapzy/` returns **no matches** (the button no longer uses the generic helper)
- [ ] `./scripts/format.sh` exits 0
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row for 016 updated
- [ ] Manual verification above performed and passing

## STOP conditions

Stop and report back (do not improvise) if:

- `notinhasNoteButton` or `annotationToolButton(for:)` no longer matches the
  "Current state" excerpt.
- `AnnotateShortcutManager.shortcut(for:)` / `isShortcutEnabled(for:)` signatures
  differ from the excerpt.
- The note tool button behaves differently from other drawing tools after the
  change (e.g. stops disabling in mockup mode) and you cannot reconcile it —
  report before altering the shared helper.
- A verification command fails twice after a reasonable fix attempt.

## Maintenance notes

- If a future refactor makes `annotationToolButton(for:)` accept a custom
  tooltip parameter, prefer collapsing `notinhasNoteButton` back into it rather
  than keeping a near-duplicate — but only if that refactor is in scope.
- Keep the gesture wording in sync with `NotinhasNoteGeometry.shouldCreateRect`
  if the click-vs-drag threshold logic ever changes.
- A reviewer should confirm no other tool's tooltip changed (`git diff` should
  only touch the Notinhas button + one new string).

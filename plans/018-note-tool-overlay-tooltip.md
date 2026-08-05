# Plan 018: Give the Notinhas note tool an Arc-like overlay tooltip

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat f125844..HEAD -- Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift`
> If this file changed since this plan was written, compare the "Current state"
> excerpt against the live code before proceeding; on a mismatch, treat it as a
> STOP condition. Also confirm plan 017 landed:
> `rg -n "func overlayTooltip" Snapzy/Shared/Components/OverlayTooltip/OverlayTooltipModifier.swift`
> must return a match; if not, STOP — this plan depends on 017.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: `plans/017-overlay-tooltip-component.md`
- **Category**: dx (discoverability)
- **Planned at**: commit `f125844`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes` — independent of plan 019 (different file); both depend on 017.
- **Reviewer required**: `no` — swaps one button's tooltip mechanism from `.help(...)` to `.overlayTooltip(...)` and adds an explicit accessibility label; no behavior/state change.
- **Rationale**: One toolbar button, one tooltip mechanism swap, reusing the component built in 017. The shortcut/enabled lookup already exists in this file.
- **Escalate when**: the maintainer wants overlay tooltips on every tool button (shared `annotationToolButton`) — that leaves the Notinhas scope and changes all tools; reclassify.

## Why this matters

The Notinhas note tool is the entry point to the whole visual-handoff loop, and
its two non-obvious behaviors — a keyboard shortcut, and click-to-pin vs
drag-for-area — are currently taught only through a flat `.help(...)` string
(`Note (N) · Click to pin · Drag for area`). Per the maintainer's direction we
are replacing the plain system tooltip with the Arc-like overlay tooltip
(built in plan 017), so the shortcut renders as a real keycap and the gesture
hint sits on a secondary line, matching the browser-style bubble the maintainer
referenced. This is the first adopter of the new component in the toolbar.

## Current state

- `Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift` — the note tool
  button and its current flat-string tooltip. The view already observes the
  shortcut manager (`annotateShortcutManager`, declared at line ~18):

```140:152:Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift
  private var notinhasNoteButton: some View {
    annotationToolButton(for: .notinhasNote, help: notinhasNoteTooltip)
  }

  private var notinhasNoteTooltip: String {
    let title: String = if annotateShortcutManager.isShortcutEnabled(for: .notinhasNote),
                           let key = annotateShortcutManager.shortcut(for: .notinhasNote) {
      L10n.Common.withShortcut(NotinhasL10n.noteTool, String(key).uppercased())
    } else {
      NotinhasL10n.noteTool
    }
    return NotinhasL10n.noteToolTooltip(title: title)
  }
```

- The generic tool-button helper it currently routes through (do NOT change this
  helper — other tools depend on its `.help(...)`):

```175:185:Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift
  private func annotationToolButton(for tool: AnnotationToolType, help: String? = nil) -> some View {
    ToolbarButton(
      icon: tool.icon,
      isSelected: state.selectedTool == tool
    ) {
      state.activateTool(tool)
    }
    .help(help ?? tool.displayName)
    .disabled(state.editorMode == .mockup && tool != .selection)
    .opacity(state.editorMode == .mockup && tool != .selection ? 0.4 : 1)
  }
```

- **Facts the tooltip needs** (all already in scope in this file / already
  imported):
  - `annotateShortcutManager.isShortcutEnabled(for: .notinhasNote) -> Bool` and
    `annotateShortcutManager.shortcut(for: .notinhasNote) -> Character?`
    (`Snapzy/Features/Annotate/Services/AnnotateShortcutManager.swift:104-110`).
  - `NotinhasL10n.noteTool` → "Note"; `NotinhasL10n.noteToolGestureHint` →
    "Click to pin · Drag for area"
    (`Snapzy/Shared/Localization/L10n.swift:2994-2998`, re-exported in
    `Snapzy/Features/Notinhas/NotinhasL10n.swift:4-5`).
  - `NotinhasL10n.noteToolTooltip(title:)` and `L10n.Common.withShortcut(_:_:)`
    remain useful for the **accessibility label** (VoiceOver reads text, not
    keycaps).
- **Component API from plan 017**:
  `func overlayTooltip(_ title: String, keys: [String] = [], secondary: String? = nil, edge: OverlayTooltipEdge = .below, delay: TimeInterval = 0.35) -> some View`
  in `Snapzy/Shared/Components/OverlayTooltip/OverlayTooltipModifier.swift`.
  For a top toolbar, use `edge: .below` (matches Arc's reload-button example,
  where the tooltip drops below the control).

## Commands you will need

| Purpose      | Command                                                                     | Expected on success     |
|--------------|----------------------------------------------------------------------------|-------------------------|
| Format       | `swiftformat Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift` | exit 0                  |
| Build + run  | `./scripts/build_and_run.sh`                                                | app builds and launches |
| Tests        | `./scripts/run-tests.sh`                                                    | build + test suite pass |

(`swiftformat` is the current formatter per `AGENTS.md`; `scripts/format.sh` was removed in commit `32e7567`.)

## Suggested executor toolkit

- Read `.agents/skills/capture-annotate-export/SKILL.md` (owns Notinhas
  pin-vs-rect geometry) to confirm the gesture wording still matches behavior.
- Read `.agents/skills/accessibility-audit/SKILL.md` — keycaps are decorative;
  the button must expose a text accessibility label with the shortcut spelled out.

## Scope

**In scope** (the only file you should modify):
- `Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift`

**Out of scope** (do NOT touch):
- `annotationToolButton(for:help:)` — the shared helper stays; other tools keep
  their `.help(...)` tooltips. Build the note button as a dedicated `ToolbarButton`.
- The note editor footer (Save/Cancel/Delete tooltips) — that is plan 019.
- Any Notinhas state/geometry logic.
- The `OverlayTooltip` component files from plan 017 — reuse as-is.

## Git workflow

- Branch: `advisor/018-note-tool-overlay-tooltip`
- Commit style: Conventional Commits. Suggested:
  `feat(notinhas): show an Arc-like overlay tooltip on the note tool`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Replace the note button to use the overlay tooltip

Replace the `notinhasNoteButton` / `notinhasNoteTooltip` block (lines ~140-152)
with a dedicated `ToolbarButton` that reproduces the shared helper's activation +
mockup-disable behavior, drops `.help(...)`, and attaches `.overlayTooltip(...)`
plus an explicit accessibility label. Compute the shortcut keycap once:

```swift
private var notinhasNoteButton: some View {
  ToolbarButton(
    icon: AnnotationToolType.notinhasNote.icon,
    isSelected: state.selectedTool == .notinhasNote
  ) {
    state.activateTool(.notinhasNote)
  }
  .disabled(state.editorMode == .mockup)
  .opacity(state.editorMode == .mockup ? 0.4 : 1)
  .overlayTooltip(
    NotinhasL10n.noteTool,
    keys: notinhasNoteShortcutKeys,
    secondary: NotinhasL10n.noteToolGestureHint,
    edge: .below
  )
  .accessibilityLabel(notinhasNoteAccessibilityLabel)
}

/// Keycap symbol for the current note-tool shortcut, or empty when disabled/unset.
private var notinhasNoteShortcutKeys: [String] {
  guard annotateShortcutManager.isShortcutEnabled(for: .notinhasNote),
        let key = annotateShortcutManager.shortcut(for: .notinhasNote)
  else { return [] }
  return [String(key).uppercased()]
}

/// Spoken label for VoiceOver — includes the shortcut and gesture in words.
private var notinhasNoteAccessibilityLabel: String {
  let title: String = if let key = notinhasNoteShortcutKeys.first {
    L10n.Common.withShortcut(NotinhasL10n.noteTool, key)
  } else {
    NotinhasL10n.noteTool
  }
  return NotinhasL10n.noteToolTooltip(title: title)
}
```

Notes:
- `.disabled(state.editorMode == .mockup)` reproduces the helper's rule for a
  non-`.selection` tool (mockup mode disables drawing tools). Behavior is
  unchanged; only the tooltip mechanism changes.
- The visible bubble reads "Note" + a `N` keycap + secondary "Click to pin ·
  Drag for area"; VoiceOver reads "Note (N) · Click to pin · Drag for area".

**Verify**: `./scripts/build_and_run.sh` → compiles and launches.

### Step 2: Format

Run `swiftformat Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift`.

**Verify**: exits 0.

## Test plan

- No unit test: this is view-only tooltip wiring depending on a MainActor
  singleton; the repo does not unit-test tooltips (see plan 016 precedent).
- **Manual verification (acceptance gate)**:
  1. Open a full Annotate window. Hover the Notinhas note tool (pin-in-circle
     icon) and wait ~0.35s: an Arc-like floating bubble appears **below** the
     button with the text "Note", an `N` keycap, and the secondary line "Click
     to pin · Drag for area". Move the mouse away → the bubble fades out.
  2. No plain gray system tooltip appears (the `.help(...)` is gone).
  3. In Preferences → Shortcuts, clear/disable the Notinhas tool shortcut → the
     bubble shows no keycap but still shows the title + gesture line.
  4. Switch to mockup mode → the note button dims/disables exactly as before.
  5. Click on the canvas → a numbered pin note is created; drag → an area
     rectangle note is created (behavior unchanged).
  6. VoiceOver (optional): the button announces "Note (N) · Click to pin · Drag
     for area"; the keycap pill is not announced separately.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `./scripts/build_and_run.sh` builds and launches
- [ ] `./scripts/run-tests.sh` passes (no regressions)
- [ ] `rg -n "overlayTooltip" Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift` returns the note-button usage
- [ ] `rg -n "\.help\(notinhasNoteTooltip\)|annotationToolButton\(for: .notinhasNote" Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift` returns **no matches** (old path removed)
- [ ] `rg -n "accessibilityLabel" Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift` returns the note-button label
- [ ] `swiftformat Snapzy/Features/Annotate/Components/AnnotateToolbarView.swift` exits 0
- [ ] `git status` shows only `AnnotateToolbarView.swift` + `plans/README.md` modified
- [ ] `plans/README.md` status row for 018 updated
- [ ] Manual verification above performed and passing

## STOP conditions

Stop and report back (do not improvise) if:

- Plan 017's `overlayTooltip(...)` API is missing or its signature differs from
  the excerpt in "Current state".
- `notinhasNoteButton` / `annotationToolButton(for:help:)` no longer matches the
  "Current state" excerpt.
- `AnnotateShortcutManager.shortcut(for:)` / `isShortcutEnabled(for:)` signatures
  differ from the excerpt.
- The note button behaves differently from other drawing tools after the change
  (e.g. stops disabling in mockup mode) and you cannot reconcile it.
- The overlay bubble appears in the wrong place (wrong monitor, far from the
  button) — this indicates a plan-017 coordinate bug; report it against 017.
- A verification command fails twice after a reasonable fix attempt.

## Maintenance notes

- Keep the gesture wording (`noteToolGestureHint`) in sync with
  `NotinhasNoteGeometry.shouldCreateRect` if the click-vs-drag threshold changes.
- If Save/Cancel or other tools later adopt overlay tooltips, prefer factoring a
  shared helper rather than duplicating the shortcut-keys computation.
- A reviewer should confirm no other tool's tooltip changed (`git diff` touches
  only the Notinhas button members).

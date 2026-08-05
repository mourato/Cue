# Plan 015: Surface keyboard-shortcut hints (kbd keycaps + tooltips) in the Notinhas note editor

> **Numbering note**: Originally drafted as "003" then renumbered to 015 to avoid
> colliding with the pre-existing plans in this directory. References to
> "001/002/004" in an earlier draft now mean 013/014/016.

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 0370153..HEAD -- Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift Snapzy/Shared/Components/KeyCapView.swift`
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
- **Parallelizable**: `yes` — independent of 013, 014, 016.
- **Reviewer required**: `no` — presentation-only change to one SwiftUI view, reusing an existing component.
- **Rationale**: Adds tooltips and reuses the existing `KeyCapView` keycap component in one view's footer. No behavior/state changes.
- **Escalate when**: the maintainer wants keycaps applied across the whole Annotate toolbar (all tools), not just Notinhas — that widens scope beyond the Notinhas journey; reclassify.

## Why this matters

The Notinhas note editor already wires real keyboard shortcuts — Save is the
default action (`⌘⏎`) and Cancel is the cancel action (`Esc`) — but nothing on
screen tells the user they exist, so the fastest path through the annotate loop
stays hidden. The app already ships a semantic "kbd" component (`KeyCapView` /
`KeyCapGroupView`) used in the global shortcut overlay, but it is unused in
Notinhas. Showing keycaps in the editor footer and enriching the button tooltips
teaches the shortcuts in place, matching the product's speed-first intent.

## Current state

- `Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift` — the note
  editor. Its footer wires the shortcuts but shows no hint:

```47:60:Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift
      HStack {
        Button(role: .destructive) { onDelete() } label: {
          Image(systemName: "trash")
        }
        .help(NotinhasL10n.deleteNote)
        .accessibilityLabel(NotinhasL10n.deleteNote)

        Spacer()

        Button(NotinhasL10n.cancel) { onCancel() }
          .keyboardShortcut(.cancelAction)
        Button(NotinhasL10n.save) { onCommit() }
          .keyboardShortcut(.defaultAction)
      }
```

- The keycap component (same build target, only `import SwiftUI` needed):

```11:50:Snapzy/Shared/Components/KeyCapView.swift
struct KeyCapView: View {
  let symbol: String
  var fontSize: CGFloat = 12
  ...
}

struct KeyCapGroupView: View {
  let parts: [String]
  var fontSize: CGFloat = 12
  ...
}
```

- The tooltip-with-shortcut helper already used elsewhere in Annotate:
  `L10n.Common.withShortcut(_ title:, _ shortcut:) -> String` → "title (shortcut)"
  (`Snapzy/Shared/Localization/L10n.swift:1203`). It is used in
  `AnnotateBottomBarView.tooltipText` (line ~447).
- The `Save` / `Cancel` / `Delete note` strings already exist:
  `NotinhasL10n.save`, `NotinhasL10n.cancel`, `NotinhasL10n.deleteNote`.

## Commands you will need

| Purpose        | Command                        | Expected on success |
|----------------|--------------------------------|---------------------|
| Format         | `./scripts/format.sh`          | exit 0              |
| Build + run    | `./scripts/build_and_run.sh`   | app builds and launches |
| Tests          | `./scripts/run-tests.sh`       | build + test suite pass |

## Suggested executor toolkit

- Read `.agents/skills/apple-design/SKILL.md` (typography/keycap feel) and
  `.agents/skills/accessibility-audit/SKILL.md` (keep keycaps decorative so
  VoiceOver reads the button, not the pill).

## Scope

**In scope** (the only files you should modify):
- `Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift`

**Out of scope** (do NOT touch):
- `Snapzy/Shared/Components/KeyCapView.swift` — reuse as-is; do not modify.
- The Annotate toolbar / other tools' tooltips — not this plan.
- The note tool button tooltip (shortcut + click/drag gesture) — that is plan
  016. This plan only touches the note **editor** footer.
- Any state/commit logic in the editor — presentation only.

## Git workflow

- Branch: `advisor/015-notinhas-shortcut-hints`
- Commit style: Conventional Commits. Suggested:
  `feat(notinhas): show shortcut keycaps and tooltips in the note editor`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Enrich the footer button tooltips with their shortcuts

In the footer `HStack` (lines ~47-60), add `.help(...)` with the shortcut to the
Cancel and Save buttons (Delete has no keyboard shortcut, keep its plain help):

```swift
Button(NotinhasL10n.cancel) { onCancel() }
  .keyboardShortcut(.cancelAction)
  .help(L10n.Common.withShortcut(NotinhasL10n.cancel, "esc"))
Button(NotinhasL10n.save) { onCommit() }
  .keyboardShortcut(.defaultAction)
  .help(L10n.Common.withShortcut(NotinhasL10n.save, "⌘⏎"))
```

**Verify**: `./scripts/build_and_run.sh` → compiles and launches.

### Step 2: Show decorative keycaps next to Cancel and Save

Wrap each of Cancel and Save with its keycap so the shortcut is visible, not just
in a tooltip. Keep the keycaps small (`fontSize: 10`) and mark them decorative so
they are not announced separately by VoiceOver. Target shape for the footer:

```swift
HStack(spacing: 8) {
  Button(role: .destructive) { onDelete() } label: {
    Image(systemName: "trash")
  }
  .help(NotinhasL10n.deleteNote)
  .accessibilityLabel(NotinhasL10n.deleteNote)

  Spacer()

  HStack(spacing: 5) {
    Button(NotinhasL10n.cancel) { onCancel() }
      .keyboardShortcut(.cancelAction)
      .help(L10n.Common.withShortcut(NotinhasL10n.cancel, "esc"))
    KeyCapView(symbol: "esc", fontSize: 10)
      .accessibilityHidden(true)
  }

  HStack(spacing: 5) {
    Button(NotinhasL10n.save) { onCommit() }
      .keyboardShortcut(.defaultAction)
      .help(L10n.Common.withShortcut(NotinhasL10n.save, "⌘⏎"))
    KeyCapGroupView(parts: ["⌘", "⏎"], fontSize: 10)
      .accessibilityHidden(true)
  }
}
```

Keep everything within the existing `.frame(width: panelWidth ...)` — the editor
panel is narrow, so verify (Step 4) that the footer does not clip or wrap
awkwardly. If width is tight, drop the `esc` keycap text to the symbol only
(already minimal) before removing any tooltip.

**Verify**: `./scripts/build_and_run.sh` → compiles and launches.

### Step 3: Format

Run `./scripts/format.sh`.

## Test plan

- No unit test: this is a pure SwiftUI presentation change. The repo has no
  snapshot-test harness for these overlays; do not add a flaky one.
- Optionally exercise the `#Preview` in `KeyCapView.swift` in Xcode canvas to
  confirm the component renders — no code change there.
- **Manual verification (acceptance gate)**:
  1. Capture an area, pick the Notinhas note tool, click to place a pin — the
     editor opens.
  2. Confirm two keycaps are visible in the footer: `esc` next to Cancel and
     `⌘ + ⏎` next to Save; the panel does not clip.
  3. Hover Cancel → tooltip "Cancel (esc)"; hover Save → tooltip "Save (⌘⏎)".
  4. Press `Esc` to cancel and `⌘⏎` to save on another note — both still work
     (you did not change the `.keyboardShortcut` modifiers).
  5. VoiceOver (optional): the keycaps are not announced as separate elements;
     the buttons announce as "Cancel"/"Save".

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `./scripts/build_and_run.sh` builds and launches
- [ ] `./scripts/run-tests.sh` passes (no regressions)
- [ ] `rg -n "KeyCapView|KeyCapGroupView" Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift` returns the new usages
- [ ] `rg -n "withShortcut" Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift` returns the two enriched tooltips
- [ ] `./scripts/format.sh` exits 0
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row for 015 updated
- [ ] Manual verification above performed and passing

## STOP conditions

Stop and report back (do not improvise) if:

- The footer `HStack` no longer matches the "Current state" excerpt.
- `KeyCapView` / `KeyCapGroupView` initializers differ from the excerpt.
- The keycaps force the editor panel to clip/scroll and reducing to symbol-only
  does not fix it (the panel is width-constrained by
  `NotinhasNoteGeometry.editorPanelSize`) — report before hacking the geometry.
- A verification command fails twice after a reasonable fix attempt.

## Maintenance notes

- If Save/Cancel are ever rebound to non-default shortcuts, update the hardcoded
  `"esc"` / `"⌘⏎"` strings here (they mirror `.cancelAction` / `.defaultAction`).
- A reviewer should confirm the keycaps are decorative (`accessibilityHidden`)
  so screen-reader users are not read a redundant "esc" after the button label.
- This intentionally does not add keycaps to every Annotate tool — that broader
  consistency pass is out of the Notinhas-scoped intent and should be its own
  decision.

# Plan 019: Move the note editor footer hints into Arc-like overlay tooltips (remove inline keycaps)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat f125844..HEAD -- Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift`
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
- **Category**: dx (discoverability) / tech-debt (removes inline-keycap workaround)
- **Planned at**: commit `f125844`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes` — independent of plan 018 (different file); both depend on 017.
- **Reviewer required**: `no` — replaces inline keycaps + `.help(...)` on three footer buttons with `.overlayTooltip(...)`; presentation-only, no state/commit logic changes.
- **Rationale**: One SwiftUI view's footer, reusing the plan-017 component. Removes the always-visible `KeyCapGroupView` that was cluttering the footer.
- **Escalate when**: removing the inline keycap forces a footer relayout that changes panel sizing/geometry beyond spacing — reclassify and report.

## Why this matters

The current note editor footer is the clearest symptom of the failed first
attempt: the Save shortcut is shown with an **always-visible** `KeyCapGroupView`
pinned next to the button (a workaround because `.help(...)` can't render
keycaps), while Cancel only gets a plain-text `.help("Cancel (esc)")`. The
result is inconsistent and cluttered — the footer comment even admits Cancel was
denied a keycap "to avoid footer clip." Per the maintainer's direction we move
**all** of these hints into the Arc-like overlay tooltip (plan 017): keycaps
appear on hover inside the floating bubble, exactly as Arc does, and the footer
returns to a clean row of buttons.

## Current state

- `Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift` — the footer.
  Note the inline `KeyCapGroupView` on Save and the `.help(withShortcut(...))`
  on Cancel/Save that this plan removes/replaces:

```47:68:Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift
      HStack(spacing: 6) {
        Button(role: .destructive) { onDelete() } label: {
          Image(systemName: "trash")
        }
        .help(NotinhasL10n.deleteNote)
        .accessibilityLabel(NotinhasL10n.deleteNote)

        Spacer(minLength: 4)

        Button(NotinhasL10n.cancel) { onCancel() }
          .keyboardShortcut(.cancelAction)
          .help(L10n.Common.withShortcut(NotinhasL10n.cancel, "esc"))

        HStack(spacing: 4) {
          Button(NotinhasL10n.save) { onCommit() }
            .keyboardShortcut(.defaultAction)
            .help(L10n.Common.withShortcut(NotinhasL10n.save, "⌘⏎"))
          // Compact keycap only on Save — Cancel keeps esc in the tooltip to avoid footer clip.
          KeyCapGroupView(parts: ["⌘", "⏎"], fontSize: 9)
            .accessibilityHidden(true)
        }
      }
```

- **Component API from plan 017**:
  `func overlayTooltip(_ title: String, keys: [String] = [], secondary: String? = nil, edge: OverlayTooltipEdge = .below, delay: TimeInterval = 0.35) -> some View`
  in `Snapzy/Shared/Components/OverlayTooltip/OverlayTooltipModifier.swift`.
  The editor panel floats over the canvas and its footer sits near the panel
  bottom, so use `edge: .above` here so the bubble appears above the buttons.
- **Strings already exist** — do not add any: `NotinhasL10n.save`,
  `NotinhasL10n.cancel`, `NotinhasL10n.deleteNote`
  (`Snapzy/Features/Notinhas/NotinhasL10n.swift:12,13,17`).
- **Keyboard shortcuts are wired via `.keyboardShortcut`** (`.defaultAction` =
  ⌘⏎, `.cancelAction` = Esc). Those modifiers **stay** — only the *hints* change.
- The `KeyCapGroupView` inline pill and the `.help(...)` calls are the only
  things being removed. `KeyCapGroupView` may become unused in this file; that is
  fine (the type still lives in `KeyCapView.swift` and is used elsewhere).

## Commands you will need

| Purpose      | Command                                                                       | Expected on success     |
|--------------|-------------------------------------------------------------------------------|-------------------------|
| Format       | `swiftformat Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift`     | exit 0                  |
| Build + run  | `./scripts/build_and_run.sh`                                                   | app builds and launches |
| Tests        | `./scripts/run-tests.sh`                                                       | build + test suite pass |

(`swiftformat` is the current formatter per `AGENTS.md`; `scripts/format.sh` was removed in commit `32e7567`.)

## Suggested executor toolkit

- Read `.agents/skills/apple-design/SKILL.md` (footer spacing/feel after the
  inline keycap is removed).
- Read `.agents/skills/accessibility-audit/SKILL.md` — the buttons already carry
  text labels ("Save"/"Cancel") or an explicit `accessibilityLabel` (Delete);
  keep keycaps out of the accessibility tree (they now live only in the visual
  tooltip bubble).

## Scope

**In scope** (the only file you should modify):
- `Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift`

**Out of scope** (do NOT touch):
- `Snapzy/Shared/Components/KeyCapView.swift` — leave `KeyCapGroupView` defined
  even if it becomes unused here; other views use it.
- `Snapzy/Shared/Components/OverlayTooltip/*` — reuse plan 017's component as-is.
- The `.keyboardShortcut(.defaultAction)` / `.keyboardShortcut(.cancelAction)`
  modifiers — the actual shortcuts must keep working; only remove the *hints*.
- The note tool toolbar button — that is plan 018.
- Any commit/cancel/delete logic or panel geometry (`panelWidth`, `maxPanelHeight`).

## Git workflow

- Branch: `advisor/019-note-editor-overlay-tooltip`
- Commit style: Conventional Commits. Suggested:
  `refactor(notinhas): move note editor shortcut hints into overlay tooltips`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Replace the footer hints with overlay tooltips

Rewrite the footer `HStack` (lines ~47-68): remove the inline `KeyCapGroupView`
and its wrapping `HStack`, remove the three `.help(...)` calls, and attach
`.overlayTooltip(...)` to each button. Keep the buttons, their actions, the
`.keyboardShortcut` modifiers, the `.accessibilityLabel` on Delete, and the
spacing structure. Target shape:

```swift
HStack(spacing: 6) {
  Button(role: .destructive) { onDelete() } label: {
    Image(systemName: "trash")
  }
  .overlayTooltip(NotinhasL10n.deleteNote, edge: .above)
  .accessibilityLabel(NotinhasL10n.deleteNote)

  Spacer(minLength: 4)

  Button(NotinhasL10n.cancel) { onCancel() }
    .keyboardShortcut(.cancelAction)
    .overlayTooltip(NotinhasL10n.cancel, keys: ["esc"], edge: .above)

  Button(NotinhasL10n.save) { onCommit() }
    .keyboardShortcut(.defaultAction)
    .overlayTooltip(NotinhasL10n.save, keys: ["⌘", "⏎"], edge: .above)
}
```

Notes:
- Delete has no keyboard shortcut → text-only tooltip (`keys` omitted).
- Cancel → single `esc` keycap; Save → `⌘` and `⏎` keycaps (rendered side by
  side, no `+`, per the component's Arc styling).
- The inline `KeyCapGroupView(parts: ["⌘", "⏎"], fontSize: 9)` and its wrapping
  `HStack(spacing: 4)` are **gone** — Save is now a plain button again.

**Verify**: `./scripts/build_and_run.sh` → compiles and launches.

### Step 2: Format

Run `swiftformat Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift`.

**Verify**: exits 0.

## Test plan

- No unit test: pure SwiftUI presentation change; the repo has no snapshot
  harness for these overlays (see plans 015/016 precedent). Do not add a flaky one.
- **Manual verification (acceptance gate)**:
  1. Capture an area, pick the Notinhas note tool, click to place a pin → the
     editor opens.
  2. The footer shows a clean row: trash icon, Cancel, Save — **no** always-on
     keycap next to Save anymore.
  3. Hover Save (~0.35s) → an Arc-like bubble appears **above** it with "Save"
     and the `⌘` `⏎` keycaps; hover Cancel → bubble with "Cancel" and an `esc`
     keycap; hover the trash → text-only bubble "Delete note". Each fades out on
     mouse-out.
  4. No plain gray system tooltip appears for these buttons.
  5. Press `Esc` to cancel and `⌘⏎` to save on another note → both still work
     (the `.keyboardShortcut` modifiers were untouched).
  6. The editor panel does not clip or resize awkwardly after the inline keycap
     removal.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `./scripts/build_and_run.sh` builds and launches
- [ ] `./scripts/run-tests.sh` passes (no regressions)
- [ ] `rg -n "overlayTooltip" Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift` returns three usages (Delete, Cancel, Save)
- [ ] `rg -n "KeyCapGroupView|\.help\(" Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift` returns **no matches** (inline keycap + help hints removed)
- [ ] `rg -n "keyboardShortcut\(\.defaultAction\)|keyboardShortcut\(\.cancelAction\)" Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift` still returns the two shortcut modifiers (unchanged)
- [ ] `swiftformat Snapzy/Features/Notinhas/Views/NotinhasNoteEditorView.swift` exits 0
- [ ] `git status` shows only `NotinhasNoteEditorView.swift` + `plans/README.md` modified
- [ ] `plans/README.md` status row for 019 updated
- [ ] Manual verification above performed and passing

## STOP conditions

Stop and report back (do not improvise) if:

- Plan 017's `overlayTooltip(...)` API is missing or its signature differs from
  the excerpt in "Current state".
- The footer `HStack` no longer matches the "Current state" excerpt.
- Removing the inline keycap forces the editor panel to clip/scroll or visibly
  relayout beyond the removed pill's width, and simple spacing tweaks do not
  resolve it (the panel is width-constrained by
  `NotinhasNoteGeometry.editorPanelSize`) — report before touching geometry.
- The overlay bubble appears in the wrong place (behind the editor, wrong
  monitor) — this indicates a plan-017 coordinate/level bug; report against 017.
- A verification command fails twice after a reasonable fix attempt.

## Maintenance notes

- If Save/Cancel are ever rebound away from `.defaultAction` / `.cancelAction`,
  update the hardcoded `["⌘", "⏎"]` / `["esc"]` keycap arrays here to match.
- Keeping keycaps out of the accessibility tree is intentional — Delete carries
  an explicit `accessibilityLabel`; Save/Cancel are announced by their text
  titles. A reviewer should confirm no redundant "esc"/"command return" is read
  by VoiceOver.
- This removes the last inline-keycap workaround from the Notinhas flow; the
  footer is now purely buttons with on-hover tooltips.

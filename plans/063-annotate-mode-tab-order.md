# Plan 063: Reorder editor mode tabs to Annotate / Preview / Mockup

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 9f7ff8c8..HEAD -- \
>   Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift \
>   Notinhas/Features/Annotate/AnnotateState.swift \
>   docs/ANNOTATE.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: direction (usability)
- **Planned at**: commit `9f7ff8c8`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes` — independent of 064–066 chrome/tool workstreams once sequenced by product order
- **Reviewer required**: `no` — mechanical reorder; spot-check segmented control only
- **Rationale**: Two localized labels swap order; mode behavior unchanged.
- **Escalate when**: Something other than display order of `EditorMode` must change (default mode, keyboard cycling, Mockup removal).

## Why this matters

The bottom segmented control today reads **Annotate → Mockup → Preview**. Product wants **Annotate → Preview → Mockup** so Preview sits next to Annotate (the primary handoff path) and Mockup is last. Mode semantics stay the same; only chrome order changes.

## Current state

- Picker order is hardcoded in `AnnotateBottomBarView.modeToggle`:

```248:256:Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift
  private var modeToggle: some View {
    Picker("", selection: $state.editorMode) {
      Label(L10n.AnnotateUI.modeAnnotate, systemImage: "pencil.and.outline")
        .tag(AnnotateState.EditorMode.annotate)
      Label(L10n.AnnotateUI.modeMockup, systemImage: "cube.transparent")
        .tag(AnnotateState.EditorMode.mockup)
      Label(L10n.AnnotateUI.modePreview, systemImage: "eye")
        .tag(AnnotateState.EditorMode.preview)
    }
```

- Enum declaration order matches the old UI (CaseIterable, but the Picker does not iterate `allCases`):

```218:222:Notinhas/Features/Annotate/AnnotateState.swift
  nonisolated enum EditorMode: String, CaseIterable {
    case annotate // Normal annotation editing (flat image)
    case mockup // 3D perspective transforms with controls
    case preview // Preview combined result (hides all editing UI)
  }
```

- Docs narrative in `docs/ANNOTATE.md` may still describe Mockup before Preview — update if it asserts tab order.

**Product decisions (already confirmed):**

1. New order: Annotate / Preview / Mockup.
2. Default remains Annotate; Mockup stays in the product.
3. No behavior change to what each mode does.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift Notinhas/Features/Annotate/AnnotateState.swift` | exit 0 |
| Drift | `git diff --stat 9f7ff8c8..HEAD -- <in-scope paths>` | empty or reviewed |
| Build/run smoke | `./scripts/build_and_run.sh --no-video-module` (optional for this plan) | app launches |
| Focused tests | `./scripts/run-tests.sh --skip-visual` | exit 0 (no new failures) |

## Suggested executor toolkit

- Global `apple-design` / `macos-app-engineering` if adjusting segmented control chrome.
- Do **not** open Counter/Notinha work (066) or toolbar undo (064) in this plan.

## Scope

**In scope:**

- `Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift` — Picker label/tag order
- `Notinhas/Features/Annotate/AnnotateState.swift` — `EditorMode` case order → `annotate`, `preview`, `mockup` (keep `String` raw values unchanged)
- `docs/ANNOTATE.md` — only if it documents tab order; align to Annotate / Preview / Mockup
- `plans/README.md` — status row for 063

**Out of scope:**

- Undo/Redo toolbar move (064)
- Quick properties wrap (065)
- Counter → Notinha absorption (066)
- Changing Preview/Mockup behavior, shortcuts, or default mode
- Localization string *wording* (only order)

## Git workflow

- Branch: `advisor/063-annotate-mode-tab-order` (or orchestrator worktree convention)
- Commit style: Conventional Commits, e.g. `fix(annotate): order mode tabs Annotate Preview Mockup`
- Do NOT push/PR unless the operator instructed it.

## Steps

### Step 1: Reorder the Picker

In `modeToggle`, emit tags in this order: `.annotate`, `.preview`, `.mockup` (labels/icons unchanged).

**Verify**: `rg -n "modeAnnotate|modePreview|modeMockup" Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift` → Preview appears before Mockup in the file.

### Step 2: Align `EditorMode` declaration order

Reorder cases to `annotate`, `preview`, `mockup`. Do **not** rename raw values (`"annotate"`, `"preview"`, `"mockup"`).

**Verify**: `rg -A5 "enum EditorMode" Notinhas/Features/Annotate/AnnotateState.swift` → cases in Annotate / Preview / Mockup order.

### Step 3: Docs touch-up (if needed)

If `docs/ANNOTATE.md` lists modes as Annotate/Mockup/Preview as UI order, update to Annotate/Preview/Mockup. Do not rewrite unrelated sections.

**Verify**: `rg -n "Mockup|Preview|EditorMode" docs/ANNOTATE.md` → no stale “Annotate / Mockup / Preview” UI order claim.

### Step 4: Format + smoke

Run swiftformat on touched Swift files. Manually (or via build_and_run): open Annotate → confirm segmented control L→R is Annotate | Preview | Mockup; switching modes still works.

**Verify**: format exit 0; visual order matches product decision.

## Test plan

- No new XCTest required (pure chrome order).
- If any test asserts `EditorMode.allCases` order, update expectations to `[.annotate, .preview, .mockup]`.
- Search: `rg -n "EditorMode\.allCases|\\.mockup.*\\.preview" NotinhasTests`

## Done criteria

- [ ] Bottom segmented control order is Annotate → Preview → Mockup
- [ ] `EditorMode` case order matches (raw values unchanged)
- [ ] Mode behavior unchanged (Preview still hides chrome; Mockup still shows mockup controls)
- [ ] No files outside Scope modified
- [ ] `plans/README.md` 063 status → DONE (or IN PROGRESS per orchestrator)

## STOP conditions

- Raw `EditorMode` string values would need to change to satisfy persistence — STOP (should not be required).
- A keyboard shortcut or menu cycles modes via `allCases` and product wants a *different* cycle order than the new tab order — STOP and report.
- Any request to remove Mockup or change default mode — out of scope; STOP.

## Maintenance notes

- Keep Picker tags and `EditorMode` declaration order in sync when adding a fourth mode.
- Follow-up chrome: 064 (undo/redo), 065 (quick bar wrap), 066 (Counter absorption) are separate plans.

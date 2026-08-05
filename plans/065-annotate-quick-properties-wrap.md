# Plan 065: Wrap Annotate quick properties when controls overflow

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 9f7ff8c8..HEAD -- \
>   Notinhas/Features/Annotate/AnnotateMainView.swift \
>   Notinhas/Features/Annotate/Components/AnnotateQuickPropertiesBar.swift \
>   NotinhasTests/Features/Annotate`
> On blocking mismatch vs "Current state" excerpts, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none (product sequence: after 063–064 preferred)
- **Category**: direction (usability) / bug (layout overflow)
- **Planned at**: commit `9f7ff8c8`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` with 066 if both touch AnnotateMainView chrome height — serialize
- **Reviewer required**: `yes` — multi-line chrome height + clipping interactions
- **Rationale**: Layout algorithm + host height change; easy to regress narrow windows.
- **Escalate when**: Fix requires rewriting every Quick* control or changing sidebar property model.

## Why this matters

With Rectangle selected, Color + **Stroke** + **Corners** (each “label + steppers + slider”) overflow the quick properties bar. The bar uses a non-wrapping `HStack` with `.fixedSize(horizontal: true)` inside `ViewThatFits` → compact density, then `.clipped()`, so Stroke and Corners **visually overlap**. The same pattern affects other multi-control tools (text, watermark, arrow, spotlight). Product wants **automatic wrap by available width** for **all** overflowing combinations — not a fixed primary/secondary split.

## Current state

Host fixes the bar to **48pt** — wrapping cannot work until this becomes flexible:

```14:27:Notinhas/Features/Annotate/AnnotateMainView.swift
  private let quickPropertiesBarHeight: CGFloat = 48
  ...
        AnnotateQuickPropertiesBar(state: state)
          .frame(height: quickPropertiesBarHeight)
```

Bar content:

```157:164:Notinhas/Features/Annotate/Components/AnnotateQuickPropertiesBar.swift
    ViewThatFits(in: .horizontal) {
      barContent(density: .regular)
      barContent(density: .compact)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .clipped()
```

Active row ends with:

```460:463:Notinhas/Features/Annotate/Components/AnnotateQuickPropertiesBar.swift
    }
    .fixedSize(horizontal: true, vertical: false)
    .padding(.horizontal, density.horizontalPadding)
    .padding(.vertical, Spacing.sm)
```

Fixed slot widths (`strokeControlWidth` ~184/146, `cornerControlWidth` ~190/154) plus Color and chips exceed typical window widths.

**Product decisions (already confirmed):**

1. Strategy: **automatic wrap by width** (no prescribed “Corners always on row 2”).
2. Scope: fix the **pattern** for every tool combo that overflows, not only rectangle.
3. Keep existing controls and stepped sliders (plan 034); do not hide props behind a “⋯” menu.

Deployment target is **macOS 13** — SwiftUI `Layout` protocol is available for a wrapping layout.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat Notinhas/Features/Annotate/AnnotateMainView.swift Notinhas/Features/Annotate/Components/AnnotateQuickPropertiesBar.swift` (+ any new layout file) | exit 0 |
| Tests | `./scripts/run-tests.sh --skip-visual` | exit 0 |
| Manual | Resize annotate window narrow with Rectangle + Stroke + Corners | no overlap; second row visible |

## Suggested executor toolkit

- Global `apple-design` for multi-line toolbar density / spacing.
- Match existing `ToolbarDivider` / `Spacing` tokens; do not invent a new design system.

## Scope

**In scope:**

- `Notinhas/Features/Annotate/AnnotateMainView.swift` — replace fixed 48pt height with min height + intrinsic/flexible height when wrapped
- `Notinhas/Features/Annotate/Components/AnnotateQuickPropertiesBar.swift` — wrapping layout; remove clip-as-overflow strategy for the active row
- Optional new small helper under `Notinhas/Features/Annotate/Components/` or `Notinhas/Shared/` for a horizontal-flow `Layout` (only if kept Annotate-local is awkward)
- Tests under `NotinhasTests/Features/Annotate/` if you add a pure `Layout` size measurement helper worth unit-testing
- `docs/ANNOTATE.md` — one-line note that quick properties may wrap to multiple rows
- `plans/README.md`

**Out of scope:**

- Changing which properties each tool exposes
- Preferences steppers / VideoEditor chrome
- Counter/Note unification (066) — except incidental Color-for-Note lands in 066
- Rewriting sidebar `AnnotationPropertiesSection`
- Fixed “primary vs secondary row” policy (explicitly rejected)

## Git workflow

- Branch: `advisor/065-annotate-quick-properties-wrap`
- Commit example: `fix(annotate): wrap quick properties instead of clipping`

## Steps

### Step 1: Make the host height flexible

In `AnnotateMainView`, stop forcing a single `frame(height: 48)`.

Preferred shape:

- Keep a **minimum** height of 48 for the idle/single-row case.
- Allow the bar to grow vertically when content wraps (e.g. `frame(minHeight: 48)` without max height clamp that clips, or bind height to the bar’s measured ideal size).

Do **not** leave `.clipped()` on a parent that still forces one row height.

**Verify**: with Rectangle tool and a narrow window, the chrome between toolbar and canvas can grow past 48pt.

### Step 2: Replace non-wrapping active HStack

In `activePropertiesContent`:

1. Keep control **order** as today (context chip → … → stroke → corners → arrow…).
2. Replace the single `HStack` + `.fixedSize(horizontal: true)` with a **width-constrained wrapping layout** that places the next control on a new row when the remaining width is insufficient.
3. Keep `ViewThatFits` regular→compact **density** if still useful; wrap must work even in compact when content still overflows.
4. Remove reliance on `.clipped()` as the overflow strategy for overlapping sliders (clipping the window edge is OK only if content already wrapped and is fully visible).

Implementation guidance:

- Prefer a small `Layout` (e.g. `QuickPropertiesFlowLayout`) with configurable horizontal/vertical spacing from `QuickPropertiesDensity.rowSpacing`.
- Each `activePropertySlot` remains a subview; invisible slots should take **no** space (existing `isVisible` behavior must continue to collapse).

**Verify**: Rectangle Color+Stroke+Corners at ~1000pt window width — no overlapping hit targets; Corners fully visible on row 1 or 2.

### Step 3: Audit other overflowing tools

Manually or via preview: activate text, watermark, arrow, spotlight — confirm controls wrap instead of overlapping. Idle bar (selection style only) stays single row.

**Verify**: no tool shows overlapping slider groups at window width 900–1200.

### Step 4: Format + tests

Run swiftformat. Run `./scripts/run-tests.sh --skip-visual`. Add a focused test only if the layout helper has pure sizing logic worth asserting; otherwise document manual gate in the PR/plan status.

**Verify**: test suite exit 0; manual narrow-window rectangle case passes.

## Test plan

- Manual (required): Annotate → Rectangle → Color+Stroke+Corners visible without overlap at default and narrowed widths.
- Manual: Watermark / Text multi-control rows wrap cleanly.
- Optional unit: flow layout places N fixed-width items into 2 rows given a max width.

## Done criteria

- [ ] Stroke+Corners (and other multi-slider tools) do not overlap at typical annotate window widths
- [ ] Wrap is automatic by width; control order preserved
- [ ] Host height grows when wrapped; single-row remains ~48pt min
- [ ] `.clipped()` no longer hides/overlaps quick property controls
- [ ] Scope respected; README 065 updated

## STOP conditions

- Wrapping requires raising deployment target above macOS 13 — STOP.
- Parent window chrome elsewhere assumes exactly 48pt and breaks (e.g. absolute Y math) — STOP and report call sites before inventing offsets.
- Temptation to hide Corners in a menu — violates product decision; STOP.
- Combining Counter Color absorption into this PR — belongs in 066; STOP.

## Maintenance notes

- New quick controls must participate in the same flow layout (don’t reintroduce a fixedSize HStack row).
- Reviewers: check narrow window + watermark (widest row) and that canvas height still feels usable with a 2-row bar.
- Deferred: pin resize handles (explicitly out of Counter absorption phase 1).

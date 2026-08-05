# Plan 067: Fix quick-properties internal control overlap

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat d33a2883..HEAD -- \
>   Notinhas/Features/Annotate/Components/AnnotateQuickPropertiesBar.swift \
>   Notinhas/Features/Annotate/Components/QuickPropertiesFlowLayout.swift \
>   NotinhasTests/Features/Annotate`
> On blocking mismatch vs "Current state", STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: 065 (wrap between slots already landed)
- **Category**: bug / usability
- **Planned at**: commit `d33a2883`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` with 068 if both touch annotate chrome height heavily — serialize by policy after 067
- **Reviewer required**: `yes` — density + wrap interaction
- **Rationale**: Changes fixed slot widths and/or internal group layout used by many tools.
- **Escalate when**: Fix requires redesigning SteppedSliderControl itself across Preferences.

## Why this matters

Plan 065 stopped **slots** from clipping each other by wrapping rows. Watermark (and similar) still show **internal** overlap: label “Text” over the text field, “Rotation” over the slider. Root cause: each slot is forced into a **fixed compact width** too narrow for `QuickPropertiesGroup` (label `fixedSize` + steppers + slider).

## Current state

- Active bar always uses `.compact` density ([`AnnotateQuickPropertiesBar.body`](Notinhas/Features/Annotate/Components/AnnotateQuickPropertiesBar.swift)).
- Compact widths (examples): `watermarkTextControlWidth` 158, `rotationControlWidth` 196, `sliderWidth` 56.
- `stableSlot` applies `.frame(width:)` then places content.
- `QuickPropertiesGroup` is an `HStack` with title `.fixedSize(horizontal: true)` + content — does not shrink gracefully inside a tight frame.

**Product decision:** Fix internal overflow for all stepped/labeled controls (not only watermark); keep automatic inter-slot wrap from 065.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Format | `swiftformat` on touched Swift | exit 0 |
| Tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/QuickPropertiesFlowLayoutTests` then `--skip-visual` | pass |
| Manual | Watermark tool: Text field + Opacity + Rotation readable, no overlap | visual OK |

## Scope

**In scope:**

- [`AnnotateQuickPropertiesBar.swift`](Notinhas/Features/Annotate/Components/AnnotateQuickPropertiesBar.swift) — density widths and/or `stableSlot` / `QuickPropertiesGroup` layout so content fits or slots size intrinsically
- Tests if you add measurable min-width helpers
- `docs/ANNOTATE.md` one-liner if documenting wrap+fit behavior
- `plans/README.md`

**Out of scope:**

- Sidebar shell / Notes dock (068)
- Renaming Toggle sidebar
- Changing which properties watermark exposes
- Preferences slider chrome outside Annotate quick bar

## Approach (required)

Implement **both**:

1. **Intrinsic slot width for labeled controls** — stop forcing a fixed width that is smaller than the control’s ideal size. Prefer measuring / using the content’s ideal width as the flow-layout item width (pass `width: nil` into `stableSlot` for watermark text/opacity/rotation, stroke, corners, font size, spotlight opacity, etc.), so the flow layout wraps whole controls instead of crushing them.

2. **Raise compact slider width** enough that label + `SteppedSliderControl` + value label fit when a fixed width is still needed (if any remain). Target: no overlap at compact density for Watermark Text / Opacity / Rotation at annotate window ≥ ~1000pt.

Do **not** reintroduce horizontal `ViewThatFits(regular→compact)` as the primary fix (065 thermo already dropped it).

Keep `QuickPropertiesFlowLayout` wrapping between slots.

## Steps

### Step 1: Reproduce mentally / assert widths

Confirm watermark Text/rotation slots still use fixed compact widths < ideal content.

### Step 2: Intrinsic sizing

Change `activePropertySlot` / `stableSlot` usage so slider+label groups use `width: nil` (or a **minimum** width ≥ measured ideal), letting flow layout place full-width items on the next row when needed.

### Step 3: Watermark Text field

Ensure `QuickWatermarkTextControl` text field has a sensible **min** width (e.g. ≥ 120) so “Text” label and field never stack on the same pixels.

### Step 4: Format + tests + manual

Run format and tests. Manual: Watermark + Rectangle stroke/corners still wrap without internal overlap.

## Done criteria

- [ ] Watermark Text / Opacity / Rotation show no overlapping label vs field/slider
- [ ] Rectangle Stroke+Corners still wrap without clipping
- [ ] Inter-slot wrap from 065 still works
- [ ] Scope respected; README 067 updated

## STOP conditions

- Fix requires rewriting all of Preferences stepped sliders — STOP and report.
- Flow layout starts overlapping slots again — STOP.
- Scope creep into 068 sidebar work — STOP.

## Maintenance notes

- Any new quick control must declare a realistic min width or use intrinsic sizing.
- Reviewer: check watermark + arrow + text font-size rows at ~900–1200pt window width.

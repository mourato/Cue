# Plan 064: Move Undo/Redo before Crop with a divider

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 9f7ff8c8..HEAD -- \
>   Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift \
>   docs/ANNOTATE.md \
>   docs/SHORTCUTS.md`
> On blocking mismatch vs "Current state" excerpts, STOP.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (product sequence: after 063 preferred, not a code dependency)
- **Category**: direction (usability)
- **Planned at**: commit `9f7ff8c8`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes` — toolbar-only; do not combine with 066 Counter work
- **Reviewer required**: `no` — layout reorder; verify divider + tooltips still present
- **Rationale**: Relocate an existing `undoRedoGroup`; no behavior change to undo stacks.
- **Escalate when**: Crop-mode action buttons (Apply/Cancel) or window undo selectors need redesign.

## Why this matters

Undo/Redo currently sit after the full annotation tool strip (near Save As / Done). Product wants them as the **first** toolbar controls (after traffic-light inset), **before Crop**, with a **divider** between Redo and Crop — matching common editor muscle memory.

## Current state

Toolbar body order today:

```21:39:Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift
  var body: some View {
    HStack(spacing: WindowSpacingConfiguration.default.toolbarItemSpacing) {
      Spacer().frame(width: 0)

      // Left group: Capture tools
      captureToolsGroup

      ToolbarDivider()

      // Center group: Annotation tools
      annotationToolsGroup

      ToolbarDivider()

      // Undo/Redo
      undoRedoGroup

      ToolbarDivider()
```

`captureToolsGroup` starts with Crop, then sidebar, divider, rotate:

```86:109:Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift
    return HStack(spacing: 4) {
      ToolbarButton(
        icon: "crop",
        ...
      )
      ToolbarButton(
        icon: "rectangle.on.rectangle",
        ...
      )
      ToolbarDivider()
      rotateButtonsGroup
    }
```

`undoRedoGroup` already has overlay tooltips / accessibility (⌘Z / ⌘⇧Z) — **preserve** those when moving.

**Product decisions (already confirmed):**

Target L→R after traffic lights:

`Undo | Redo ‖ Crop | Sidebar ‖ Rotate… ‖ annotation tools… ‖ (combine add image) ‖ Spacer ‖ Save As / Done`

Undo/Redo leave their current mid-toolbar position (no duplicate controls).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift` | exit 0 |
| Drift | `git diff --stat 9f7ff8c8..HEAD -- <in-scope>` | empty or reviewed |
| Tests | `./scripts/run-tests.sh --skip-visual` | exit 0 |

## Scope

**In scope:**

- `Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift` — body group order only
- `docs/ANNOTATE.md` / `docs/SHORTCUTS.md` — only if they describe toolbar L→R order
- `plans/README.md` — status row

**Out of scope:**

- Changing undo/redo stack behavior (`AnnotateState.undo` / `redo`)
- `AnnotateWindow` selector wiring
- Counter / Note tool changes (066)
- Quick bar (065)
- Mode tabs (063)
- Redesigning Save As / Done / crop Apply-Cancel trailing cluster

## Git workflow

- Branch: `advisor/064-annotate-undo-redo-leading`
- Commit example: `fix(annotate): lead toolbar with undo and redo`

## Steps

### Step 1: Lead with undo/redo + divider

In `AnnotateToolbarView.body`, place:

1. `undoRedoGroup`
2. `ToolbarDivider()`
3. `captureToolsGroup` (unchanged internals: Crop, Sidebar, divider, Rotate)
4. `ToolbarDivider()`
5. `annotationToolsGroup`
6. Remove the **old** undo/redo block that sat after annotation tools (and its trailing divider if it would create a double divider before combine/spacer)

Preserve combine-mode add-image block, Spacer, and `registeredActionButtons` as today.

**Verify**: `rg -n "undoRedoGroup|captureToolsGroup|annotationToolsGroup" Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift` → first content group is undoRedo, then captureTools; undoRedo appears only once.

### Step 2: Docs (if needed)

If docs claim undo/redo sit after tools, update to “leading, before crop”.

**Verify**: no stale “undo after tools” claim in `docs/ANNOTATE.md`.

### Step 3: Format + manual smoke

Confirm: Undo/Redo first; divider; Crop; sidebar; rotate; tools; Save As/Done still trailing. Undo/Redo still disabled when stacks empty; tooltips still show.

**Verify**: visual L→R matches product decision; `canUndo`/`canRedo` opacity unchanged.

## Test plan

- No new unit tests required.
- Manual: place a shape → Undo → Redo; crop still activates from new position.

## Done criteria

- [ ] Toolbar L→R starts with Undo, Redo, divider, then Crop
- [ ] Single undo/redo pair (not duplicated)
- [ ] Overlay tooltips / AX labels on undo/redo preserved
- [ ] No behavior change to undo stacks
- [ ] Scope respected; README 064 updated

## STOP conditions

- Moving undo/redo appears to require changing `AnnotateWindow` first-responder undo — STOP (should be unnecessary).
- Crop interaction mode relocates Apply/Cancel into the leading cluster — STOP; leave trailing actions alone.
- Request to also reorder annotation tools or merge Counter/Note — belongs in 066; STOP widening.

## Maintenance notes

- Keep `ToolbarDivider` between history controls and destructive geometry (crop/rotate).
- Plan 032 tooltips assumed undo near tools; verify overlay edge still `.below` after move (should be fine).

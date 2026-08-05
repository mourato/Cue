# Plan 066: Absorb Counter into Notinha (remove Counter tool)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 9f7ff8c8..HEAD -- \
>   Notinhas/Features/Annotate \
>   Notinhas/Features/Notinhas \
>   NotinhasTests/Features/Annotate \
>   NotinhasTests/Features/Notinhas \
>   CONTEXT.md \
>   docs/ANNOTATE.md \
>   docs/SHORTCUTS.md \
>   docs/adr`
> On blocking mismatch vs "Current state" excerpts, STOP.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: none code-wise; product sequence **after** 063–065
- **Category**: migration / direction
- **Planned at**: commit `9f7ff8c8`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no` — touches tools, shortcuts, persistence, inline capture, docs, ADR
- **Reviewer required**: `yes` — thermo-nuclear after integrate; migration + numbering semantics
- **Rationale**: Removes a first-class tool, migrates persisted annotations, changes shortcuts defaults, and expands Notinha into inline drawable tools.
- **Escalate when**: Product asks to keep Counter creatable, preserve baked counter integers, or add pin drag-handles in the same PR.

## Why this matters

Counter (`list.number`) and Notinha (`pin.circle.fill`) both place numbered badges. Product decided to **unify on Notinha**: one toolbar/inline tool, text optional, Counter removed from UI. Size already exists on Notinha (plan 009). Remaining gaps for this plan: quick-bar **Color** for Note, **shortcut `n`**, **inline** presence, **session migration** of legacy counters → empty Notinhas, docs + ADR. Numeração stays Notinha semantics (recomputed `creationOrder`; export panel only for non-empty text).

## Decisions already confirmed

1. **Unify = absorb into Notinha** — Counter tool leaves UI; Notinha is the only way to place numbered markers.
2. **Text optional** — empty-text Notinha is a valid badge (CONTEXT.md already updated).
3. **Numbering = Notinha** — renumber by `creationOrder`; do **not** adopt Counter’s baked stable ints.
4. **Migration = one-shot on editor session open** — convert counters → empty Notinhas; **append** after existing notes (relative order among counters = annotation array order); persist on next save.
5. **Shortcuts** — Notinha default `n`; **`i` retired**; one-shot prefs cleanup (orphan Counter keys; remap Notinha off `i` onto `n`).
6. **Inline** — put Notinha into `drawableTools` / inline groups where Counter was.
7. **Deferred** — pin drag-handle resize; Selection multi-edit restyle of pins.
8. **ADR** — write a short ADR under `docs/adr/` for this absorption.

## Current state

### Tools / shortcuts

```36:39:Notinhas/Features/Annotate/Models/AnnotateAnnotationToolType.swift
  static let drawableTools: [AnnotationToolType] = [
    .rectangle, .filledRectangle, .oval, .arrow, .line, .text, .highlighter,
    .blur, .spotlight, .counter, .watermark, .pencil,
  ]
```

```75:93:Notinhas/Features/Annotate/Models/AnnotateAnnotationToolType.swift
  var defaultShortcut: Character {
    switch self {
    ...
    case .counter: "n"
    case .notinhasNote: "i"
```

```140:146:Notinhas/Features/Annotate/Models/AnnotateAnnotationToolType.swift
  var supportsQuickStrokeColor: Bool {
    switch self {
    case .rectangle, .filledRectangle, .oval, .arrow, .line, .text, .highlighter, .counter, .watermark, .pencil:
      true
    case .selection, .crop, .blur, .spotlight, .mockup, .notinhasNote:
      false
```

Toolbar injects Note **after** Counter:

```134:138:Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift
      ForEach(drawingTools, id: \.self) { tool in
        annotationToolButton(for: tool)
        if tool == .counter {
          notinhasNoteButton
        }
      }
```

`AnnotateShortcutManager.configurableTools` includes both `.counter` and `.notinhasNote`. Keys: `annotate.shortcut.counter`, `annotate.shortcut.notinhasNote`.

### Models

- Counters: `AnnotationType.counter(Int)` on `AnnotationItem` in `annotations`.
- Notinhas: `NotinhasVisualNote` in `notinhasNotes` (`text` default `""`, `pinControlValue`, `color`, `creationOrder`, `target`).
- Pin size already shared via `AnnotationProperties.counterDiameter(for:)`.
- Separate numbering: `nextCounterValue()` vs `NotinhasNoteGeometry.nextCreationOrder` / `canvasDisplayNumber`.

### Session restore hook (migrate here)

`AnnotateWindowController` (both session inits): set `state.annotations`, then optionally `state.notinhasRestoreNotes(...)`. **After both are applied**, run migration: extract counters → notes → strip counters from `annotations`.

### Vocabulary

`CONTEXT.md`:

> **Notinha visual**: Uma marcação numerada associada a um ponto ou área da imagem; o comentário textual é opcional (badge válido sem texto).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat Notinhas NotinhasTests` (scoped paths touched) | exit 0 |
| Focused tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/<NewOrUpdatedSuites>` | exit 0 |
| Default suite | `./scripts/run-tests.sh --skip-visual` | exit 0 |
| Preflight (optional) | `./scripts/plan-preflight.sh plans/066-absorb-counter-into-notinhas.md --scope Notinhas/Features/Annotate --scope Notinhas/Features/Notinhas` | pass / reported |

## Suggested executor toolkit

- `.agents/skills/capture-annotate-export/SKILL.md`
- `.agents/skills/data-persistence/SKILL.md`
- `.agents/skills/testing-xctest/SKILL.md`
- Global `swift-conventions` / `delivery-workflow`

## Scope

**In scope:**

- `AnnotateAnnotationToolType.swift` — drawable/inline tools; shortcuts; quick Color for `.notinhasNote`; retire Counter from creatable surfaces
- `AnnotateToolbarView.swift` — single Note button (no Counter; no post-Counter injection hack)
- Inline annotate tool groups consuming `drawableTools`
- `AnnotateShortcutManager.swift` (+ any preferences shortcut UI listing tools) — drop Counter; migration helper for defaults/`i`→`n`
- `AnnotateWindowController.swift` (+ shared helper preferably under `Notinhas/Features/Notinhas/` or Annotate Services) — Counter→Notinha migration
- Quick-bar path so Note shows **Color** + Size (enable `supportsQuickStrokeColor` for `.notinhasNote`; wire bindings to note color / tool default as existing Size does)
- Tests for migration, shortcut defaults uniqueness, tool list
- `docs/ANNOTATE.md`, `docs/SHORTCUTS.md` — remove Counter as active tool; document Note + `N`
- `docs/adr/NNNN-absorb-counter-into-notinhas.md` — short ADR
- `plans/README.md`

**Keep for decode / migration safety (do not delete in this plan unless tests prove unused):**

- `AnnotationType.counter(Int)` persistence + renderer path so mid-flight / unmigrated data still draws until converted
- Factory/test helpers may remain but must not be reachable from UI

**Out of scope:**

- Pin drag-handle resize
- Selection-tool multi-edit of Notinha pins as `AnnotationItem`s
- Changing export panel rules (still text-only for panel)
- Reintroducing baked integer display numbers
- Plans 063–065 chrome (unless trivial conflict resolution)
- Removing `AnnotationType.counter` enum case entirely (follow-up once migration proven)

## Git workflow

- Branch: `advisor/066-absorb-counter-into-notinhas`
- Prefer 2 commits if helpful: (1) tool/UI/shortcuts + Color, (2) migration + ADR + docs
- Examples: `feat(notinhas): absorb Counter into Note tool`, `feat(annotate): migrate counters to empty Notinhas`

## Steps

### Step 1: ADR

Create `docs/adr/` if missing. Next number after existing ADRs (scan directory). Content ≈:

> Notinhas absorbs the Counter tool. Numbered markers are only created as Notinhas (text optional). Counter remains a legacy annotation type for one-shot session migration. Numbering stays Notinha `creationOrder` (not baked Counter ints). Shortcut `n` activates Note; `i` is retired. Pin resize handles and Selection multi-edit of pins are deferred.

**Verify**: ADR file exists and is linked from this plan’s README notes if the index mentions ADRs.

### Step 2: Make Note the only numbered tool in UI

1. In `drawableTools`, **replace** `.counter` with `.notinhasNote` (same list position Counter occupied).
2. Remove toolbar `if tool == .counter { notinhasNoteButton }` hack; Note comes from `drawableTools` like other tools **or** keep a single dedicated button if Note must stay out of `ForEach` styling — prefer one path only (no duplicate Note buttons).
3. Remove `.counter` from `AnnotateShortcutManager.configurableTools`.
4. Set `notinhasNote.defaultShortcut` to `"n"`. Counter’s default must not remain `"n"` if the case stays on the enum — use a non-conflicting placeholder or exclude Counter from uniqueness tests / configurable set.
5. Update `testAnnotationToolTypeDefaultShortcutsAreUnique…` and any tests that create via `.counter` tool activation from UI lists.

**Verify**: `rg -n "\\.counter" Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift` → no Counter button. `drawableTools` contains `.notinhasNote`, not `.counter`. Shortcut uniqueness test passes with Note = `n`.

### Step 3: Shortcut one-shot migration

On `AnnotateShortcutManager` load (or first access):

1. If `annotate.shortcut.notinhasNote` is missing or equals `i` (legacy default), set Notinha to `n` (unless `n` is taken by another **remaining** configurable tool — then STOP).
2. Remove/ignore `annotate.shortcut.counter` and Counter from `disabledAnnotateToolShortcuts` entries.
3. Do not leave users with a dead `i` binding for Note.

**Verify**: unit test with UserDefaults suite: legacy `i` → becomes `n`; Counter key cleaned; fresh install Note defaults to `n`.

### Step 4: Quick-bar Color for Note

1. Set `supportsQuickStrokeColor` true for `.notinhasNote`.
2. Ensure quick Color binding updates selected note color / tool default the same way Size already does for pins (mirror Counter’s former Color+Size pair).
3. Empty-text notes remain placeable; Color applies to the badge.

**Verify**: activating Note shows Color + Size in quick bar; changing Color updates selected/default pin fill.

### Step 5: Migration helper

Pure-ish API, e.g. `NotinhasCounterMigration`:

Input: `annotations: [AnnotationItem]`, `notes: [NotinhasVisualNote]`  
Output: `(annotationsWithoutCounters, notesAppendingMigrated)`

Mapping per counter:

| From | To |
|------|----|
| `bounds` mid | `target: .point(center)` |
| `properties.strokeWidth` | `pinControlValue` |
| `properties.strokeColor` | `color: RGBAColor(color:)` |
| baked `counter(Int)` | **ignored** for display number |
| text | `""` |
| `creationOrder` | start at `nextCreationOrder(in: existingNotes)`, increment per migrated counter in annotation-array order |

Strip all `.counter` items from `annotations`. Idempotent: second run no-ops.

Call from **both** `AnnotateWindowController` session-restore branches after annotations + `notinhasRestoreNotes`. Prefer also running inside `PersistedAnnotationSession.sessionData` **or** immediately before UI if other consumers load sessions — pick one durable path and document it; if only WindowController, ensure Quick Access reopen still hits it.

**Verify**: XCTest with mixed counters + notes → counters gone from annotations; N empty notes appended; orders monotonic; second migration unchanged.

### Step 6: Docs

Update `docs/ANNOTATE.md` (remove Counter as active tool; Note covers numbered markers) and `docs/SHORTCUTS.md` (`N` → Note, remove Counter/`I` if documented).

**Verify**: `rg -n "Counter|\`N\`|\`I\`" docs/ANNOTATE.md docs/SHORTCUTS.md` → aligns with Note/`N`.

### Step 7: Format + full focused verification

Run swiftformat; run Notinhas + Annotate focused tests including new migration/shortcut tests; `./scripts/run-tests.sh --skip-visual`.

Manual: place Note without typing → badge shows; export with only empty notes → no panel / markers only as today’s empty-text rules; open a session fixture with counters → become Notinhas; inline annotate shows Note not Counter.

## Test plan

New/updated tests (model after existing Notinhas/Annotate tests):

1. `testCounterMigrationAppendsEmptyNotesAndStripsCounters`
2. `testCounterMigrationIsIdempotent`
3. `testNotinhasNoteDefaultShortcutIsNAndUniqueAmongConfigurableTools`
4. `testShortcutMigrationRetiresIAndCounterKey`
5. `testNotinhasNoteSupportsQuickStrokeColor`
6. Update any factory tests that assumed Counter is in `drawableTools` / inline groups
7. Keep renderer tests for `AnnotationType.counter` **or** migrate them to post-migration notes if they only existed for UI

## Done criteria

- [ ] Counter not creatable from full editor or inline toolbelts
- [ ] Single Note affordance; shortcut `n`; `i` not the Note default
- [ ] Quick bar Color + Size for Note
- [ ] Session open migrates counters → empty Notinhas (append); annotations no longer contain counters after migrate
- [ ] Numbering remains Notinha semantics
- [ ] ADR + ANNOTATE/SHORTCUTS updated
- [ ] New tests pass; `--skip-visual` suite green
- [ ] No pin-handle / Selection multi-edit work slipped in
- [ ] README 066 updated

## STOP conditions

- Enabling Color for Note requires restructuring quick selection multi-edit in a way that breaks shape Color — STOP and report.
- `n` cannot be assigned because another shipping tool claims it after Counter removal — STOP.
- Migration would drop counters without creating notes — never ship; fix or STOP.
- Request to preserve baked Counter integers on canvas — conflicts with confirmed decision A; STOP.
- Removing `AnnotationType.counter` decode breaks old sidecars before migration runs — keep decode path; STOP if someone deletes it early.

## Maintenance notes

- Follow-up: delete `AnnotationType.counter` + drawer-only path after metrics/confidence; add pin handles if product prioritizes.
- Reviewers: inspect migration order vs existing notes; shortcut importer/exporter; inline Capture Markup tool strip.
- Historical plans 004/009 said “do not unify into Counter” — this plan **supersedes** that product stance; ADR is the new source of truth.

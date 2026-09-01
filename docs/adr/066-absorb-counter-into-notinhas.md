# ADR 066: Absorb Counter into Notinha

## Status

Accepted (2026-07-24)

## Context

Annotate shipped two numbered-marker tools: **Counter** (legacy Snapzy annotation) and
**Notinha** (Notinhas numbered pins/rects with optional notes). Product intent is a
single handoff marker: Notinha only, with optional text and `creationOrder` numbering.

Legacy sessions may still contain `AnnotationType.counter` items in the sidecar.

## Decision

1. Remove Counter from the toolbar and `drawableTools`; expose **Notinha** (`notinhasNote`)
   in its place (full editor and inline overlay).
2. Keep `AnnotationType.counter` for decode/render until migrated; do not delete the enum case.
3. On editor session open, run a one-shot, idempotent migration:
   - Each counter → empty `CueVisualNote` at bounds center; append after existing notes.
   - Map `strokeWidth` → `pinControlValue`, `strokeColor` → `RGBAColor`; ignore baked counter ints.
   - Strip counter annotations from the annotation list; persist on next save.
4. Shortcut: Notinha default **`n`**; retire **`i`** with a one-shot prefs migration; remove
   orphan Counter shortcut keys.
5. Quick properties: Notinha supports **Size** and **Color** like Counter did.
6. Defer pin resize handles and Selection multi-edit of pins.

## Consequences

- Users see one Note tool; legacy counters become empty numbered pins on first open.
- Numbering follows Notinha `creationOrder`, not historical counter values.
- `AnnotateShortcutManager.configurableTools` no longer includes `.counter`.
- Follow-up work: pin handles, multi-edit (out of scope for 066).
